defmodule MyLiege.Engine.Rules.Trades do
  @moduledoc """
  R16, trade routes: a way (R13) that is a `Place.Trade`; for now the grain trade route,
  yellow's way to food.

  - Once unlocked (`Rules.Ways`), the route is a place in the village (`open/2`, in the
    Books step that finishes the last book it needs): one route, nothing to build or pay.
  - Workers of any colour, trained or not, are placed on it and leave it as in a building,
    up to `way_grain_trade_capacity`, but travel `way_grain_trade_travel_weeks` instead of
    `travel_weeks`, on the way there and on the way out (`Rules.Travel.weeks/3`). A trader
    stays until moved.
  - A trader eats, counts for taxes, produces nothing (so he doesn't defend) and, once
    arrived, makes mana as at a yellow place for food (R3).
  - Every week (`settle/4`), each arrived trader, in the order they were placed on the
    route, pays his price (`price/2`) from the gold stock and brings
    `way_grain_trade_food_per_week` food; if the gold stock is short of his price he pays
    and brings nothing this week, and stays.

  Amounts are in thousandths (see `Fixed`).
  """

  alias MyLiege.Engine.{Config, Fixed, Place, Worker}
  alias MyLiege.Engine.Place.{Blueprint, Trade}
  alias MyLiege.Engine.Rules.{Production, Ways}

  @types Blueprint.trade_types()

  @doc "The types of trade route, in catalogue order."
  def types, do: @types

  @doc "How many traders a route of `type` takes."
  def capacity(:grain_trade, %Config{} = config), do: config.way_grain_trade_capacity

  @doc "The weeks a worker travels on the way to or from a route of `type`."
  def travel_weeks(:grain_trade, %Config{} = config), do: config.way_grain_trade_travel_weeks

  @doc """
  The gold (thousandths) `worker` pays per week on a route of `type`: the route's weekly
  gold × 1000 ÷ his colour factor against the route's colour (untrained or trained, R2),
  rounded down.
  """
  def price(:grain_trade = type, %Worker{} = worker, %Config{} = config) do
    factor = Production.efficiency(worker, Blueprint.fetch!(type).colour, config)
    div(Fixed.from(config.way_grain_trade_gold_per_week) * 1000, factor)
  end

  @doc "The food (thousandths) one trader brings per week on a route of `type`."
  def food(:grain_trade, %Config{} = config), do: Fixed.from(config.way_grain_trade_food_per_week)

  @doc "The route of `type` among `places`, or `nil` while it isn't open."
  def route(places, type), do: Enum.find(places, &match?(%Trade{blueprint: %{type: ^type}}, &1))

  @doc """
  Appends every route that `books` unlock and that isn't open yet to `places`, with the next
  free id and no traders. Returns `{places, opened_types}`.
  """
  def open(places, books) do
    Enum.reduce(@types, {places, []}, fn type, {places, opened} ->
      blueprint = Blueprint.fetch!(type)

      if route(places, type) == nil and Ways.unlocked?(blueprint, books) do
        route = %Trade{id: Place.next_id(places), blueprint: blueprint}
        {places ++ [route], opened ++ [type]}
      else
        {places, opened}
      end
    end)
  end

  @doc """
  Puts `worker_id` last in the queue of the route with id `route_id`, wherever he stood in it
  before; for any other place id, `places` stay as they are.
  """
  def join(places, worker_id, route_id) do
    Enum.map(places, fn
      %Trade{id: ^route_id} = route ->
        %{route | traders: List.delete(route.traders, worker_id) ++ [worker_id]}

      place ->
        place
    end)
  end

  @doc "The workers placed on `route`, in the order they were placed on it."
  def traders(%Trade{} = route, workers) do
    by_id = Map.new(workers, &{&1.id, &1})

    for id <- route.traders,
        worker = Map.get(by_id, id),
        worker != nil and worker.place == route.id,
        do: worker
  end

  @doc """
  The week's trade on `route`: each arrived trader (travel 0), in queue order, pays his price
  if `gold` still covers it and brings the route's food. Returns `{route, result}`: the route
  with its queue cut to the workers still on it, and
  `%{gold_paid: gold, food: food, traders: count}`, where `traders` counts every worker on the
  route, arrived or not.
  """
  def settle(%Trade{} = route, workers, gold, %Config{} = config) do
    type = Place.type(route)
    traders = traders(route, workers)

    {paid, paying} =
      traders
      |> Enum.filter(&(&1.travel == 0))
      |> Enum.reduce({0, 0}, fn worker, {paid, paying} ->
        price = price(type, worker, config)
        if gold - paid >= price, do: {paid + price, paying + 1}, else: {paid, paying}
      end)

    {%{route | traders: Enum.map(traders, & &1.id)},
     %{gold_paid: paid, food: paying * food(type, config), traders: length(traders)}}
  end
end
