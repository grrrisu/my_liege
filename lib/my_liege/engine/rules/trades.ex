defmodule MyLiege.Engine.Rules.Trades do
  @moduledoc """
  R16, trades: a way (R13) that is a `Place.Trade`; for now the grain trade, yellow's way to
  food.

  - Once unlocked (`Rules.Ways`), the player starts one with a trader of any colour who has
    arrived (travel 0), unplaced or taken out of his place (a trainee loses his training).
    No building. Several trades may run at once, one trader each.
  - Its gold is paid at the start: `way_grain_trade_gold` × 1000 ÷ the trader's colour
    factor against the trade's colour (yellow), untrained or trained (R2), rounded down. Not
    possible with less gold.
  - The trader is away `way_grain_trade_travel_weeks` + `way_grain_trade_trade_weeks` +
    `way_grain_trade_travel_weeks` weeks, from the week after the start: started at week N,
    he returns at the end of week N + that. Away he eats, counts for taxes, produces nothing
    and makes mana as at a yellow place for food (R3), every week; he can't be moved or
    unplaced (`Placement.check_leave/1`).
  - On return, `way_grain_trade_food` food goes into the stock, the trade disappears and the
    trader is released, unplaced and travelling (R2).

  Amounts are in thousandths (see `Fixed`).
  """

  alias MyLiege.Engine.{Config, Fixed, Place, Worker}
  alias MyLiege.Engine.Place.{Blueprint, Trade}
  alias MyLiege.Engine.Rules.{Placement, Production, Travel, Ways}

  @types Blueprint.trade_types()

  @doc "The types of trade, in catalogue order."
  def types, do: @types

  @doc "How many weeks a trade of `type` is away: out, trading, back."
  def weeks(:grain_trade, %Config{} = config),
    do: 2 * config.way_grain_trade_travel_weeks + config.way_grain_trade_trade_weeks

  @doc """
  The gold (thousandths) `worker` pays to trade `type`: the trade's gold × 1000 ÷ his colour
  factor against the trade's colour, rounded down.
  """
  def cost(:grain_trade = type, %Worker{} = worker, %Config{} = config) do
    factor = Production.efficiency(worker, Blueprint.fetch!(type).colour, config)
    div(Fixed.from(config.way_grain_trade_gold) * 1000, factor)
  end

  @doc "The food (thousandths) a trade of `type` brings back."
  def food(:grain_trade, %Config{} = config), do: Fixed.from(config.way_grain_trade_food)

  @doc """
  Whether `worker` may start trading `type`: `:ok` or `{:error, reason}` with reason
  `:unknown_trade`, `:locked`, `:away` (already on a trade), `:travelling` or
  `:not_enough_gold`, checked in this order. `place` is the worker's place (`nil` if
  unplaced), `gold` the gold stock and `books` the books held.
  """
  def check_start(type, %Worker{} = worker, place, gold, books, %Config{} = config) do
    cond do
      type not in @types -> {:error, :unknown_trade}
      Ways.check(Blueprint.fetch!(type), books) != :ok -> {:error, :locked}
      Placement.check_leave(place) != :ok -> {:error, :away}
      Travel.travelling?(worker) -> {:error, :travelling}
      gold < cost(type, worker, config) -> {:error, :not_enough_gold}
      true -> :ok
    end
  end

  @doc """
  Appends a trade of `type` started while the game stands at `week` to `places`, with the next
  free id; it returns at the end of `week` + `weeks/2`.
  """
  def new_trade(places, type, week, %Config{} = config) do
    trade = %Trade{
      id: Place.next_id(places),
      blueprint: Blueprint.fetch!(type),
      return_week: week + weeks(type, config)
    }

    places ++ [trade]
  end

  @doc """
  Every trade returning at the end of `week`: its food, the trade removed, its trader
  released. Returns `{places, workers, food, returned_types}`.
  """
  def return(places, workers, week, %Config{} = config) do
    returning = for %Trade{} = trade <- places, Trade.returns?(trade, week), do: trade
    ids = MapSet.new(returning, & &1.id)

    places = Enum.reject(places, &MapSet.member?(ids, &1.id))
    workers = Enum.reduce(returning, workers, &Placement.release(&2, &1.id, config))
    types = Enum.map(returning, &Place.type/1)
    food = types |> Enum.map(&food(&1, config)) |> Enum.sum()

    {places, workers, food, types}
  end
end
