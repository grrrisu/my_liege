defmodule MyLiege.Engine.Rules.Hunting do
  @moduledoc """
  R17, the hunting camp: red's way to food, a `Place.Expedition`.

  - Once unlocked (`Rules.Ways`: a red and a green book), the camp is a place in the village
    (`Rules.Ways.open/4`, in the Books step): one camp, nothing to build or pay, open to the
    end of the game.
  - Workers of any colour, trained or not, are placed on it and leave it as in a building, up
    to `way_hunting_max_party`, but travel `way_hunting_travel_weeks` instead of
    `travel_weeks`, both ways (`Rules.Travel.weeks/3`). A hunter stays until moved.
  - A hunter eats, counts for taxes, produces nothing (so he doesn't defend) and, once
    arrived, makes mana as at a red place for food (R3).
  - Every week (`hunt/4`), each arrived hunter adds `way_hunting_food_per_week` × his colour
    factor against red (R2) to the camp's bag; a week with an arrived hunter counts. Every
    `way_hunting_haul_weeks` counted weeks there is a haul: one luck draw by the number of
    arrived hunters that week; bag × the luck factor ÷ 1000, rounded down, goes into the
    stock, and the bag and the count start again.
  - When the last worker leaves the camp (`abandon_empty/2`), the bag and the count are lost.

  Amounts are in thousandths (see `Fixed`). Random state is passed in and returned.
  """

  alias MyLiege.Engine.{Config, Fixed, Place, Worker}
  alias MyLiege.Engine.Place.{Blueprint, Expedition}
  alias MyLiege.Engine.Rules.Production

  @type luck :: :low | :mid | :high
  @lucks [:low, :mid, :high]

  @doc "How many hunters the camp takes."
  def capacity(%Config{} = config), do: config.way_hunting_max_party

  @doc "The weeks a worker travels on the way to or from the camp."
  def travel_weeks(%Config{} = config), do: config.way_hunting_travel_weeks

  @doc "The camp among `places`, or `nil` while it isn't open."
  def camp(places), do: Enum.find(places, &match?(%Expedition{}, &1))

  @doc "What one arrived hunter adds to the bag in a week (thousandths)."
  def hunter_week(%Worker{} = worker, %Config{} = config) do
    factor = Production.efficiency(worker, Blueprint.fetch!(:hunting).colour, config)
    div(Fixed.from(config.way_hunting_food_per_week) * factor, 1000)
  end

  @doc "A haul: `bag` × the luck factor ÷ 1000, rounded down."
  def haul(bag, luck, %Config{} = config) when luck in @lucks,
    do: div(bag * Map.fetch!(config.way_hunting_luck, luck), 1000)

  @doc """
  Draws the luck of a haul by `size` arrived hunters: one draw out of 10 from `rand`, low for
  the first `low` counts, then mid, then high. Returns `{luck, rand}`.
  """
  def draw_luck(size, %Config{} = config, rand) do
    {draw, rand} = :rand.uniform_s(10, rand)
    {luck_for(draw, Map.fetch!(config.way_hunting_party, size)), rand}
  end

  @doc "The luck of a `draw` from 1 to 10 with `counts` (low, mid, high summing to 10)."
  def luck_for(draw, %{low: low, mid: mid}) when draw in 1..10 do
    cond do
      draw <= low -> :low
      draw <= low + mid -> :mid
      true -> :high
    end
  end

  @doc """
  The camp's week. `workers` carry their travel as at the start of the week. Each arrived
  hunter (travel 0) fills the bag; a week with one counts and marks the idle block as hunted.
  At `way_hunting_haul_weeks` counted weeks: one luck draw, the haul, the bag and the count
  start again. Returns `{camp, haul, rand}` with `haul` `%{hunters, luck, food}` or `nil`;
  `rand` is used only for a haul.
  """
  def hunt(%Expedition{} = camp, workers, %Config{} = config, rand) do
    arrived = workers |> Place.workers_at(camp.id) |> Enum.filter(&(&1.travel == 0))

    if arrived == [] do
      {camp, nil, rand}
    else
      bag = camp.bag + (arrived |> Enum.map(&hunter_week(&1, config)) |> Enum.sum())
      camp = %{camp | bag: bag, weeks: camp.weeks + 1, hunted_in_block: true}

      if camp.weeks >= config.way_hunting_haul_weeks do
        {luck, rand} = draw_luck(length(arrived), config, rand)
        haul = %{hunters: length(arrived), luck: luck, food: haul(bag, luck, config)}
        {%{camp | bag: 0, weeks: 0}, haul, rand}
      else
        {camp, nil, rand}
      end
    end
  end

  @doc """
  Empties the bag and the count of a camp that no worker is placed on any more, arrived or
  not. Called when workers leave a place.
  """
  def abandon_empty(places, workers) do
    Enum.map(places, fn
      %Expedition{} = camp ->
        if Place.workers_at(workers, camp.id) == [],
          do: %{camp | bag: 0, weeks: 0},
          else: camp

      place ->
        place
    end)
  end
end
