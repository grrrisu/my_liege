defmodule MyLiege.Engine.Rules.Hunting do
  @moduledoc """
  R17, hunting: red's way to food, an expedition (`Place.Expedition`).

  - Once unlocked (`Rules.Ways`: a red and a green book), the player starts a hunt at no cost
    with a party of 1 to `way_hunting_max_party` workers of any colour who have arrived
    (travel 0), unplaced or taken out of their place (a trainee loses his training). No
    building. Several hunts may run at once.
  - The party is away `way_hunting_travel_weeks` + `way_hunting_hunt_weeks` +
    `way_hunting_travel_weeks` weeks from the week after it sets out. Away, the hunters eat,
    count for taxes, produce nothing (so they don't defend) and make mana as at a red place
    for food (R3); they can't be moved or unplaced (`Placement.check_leave/1`).
  - On return: the haul is every hunter's `way_hunting_food_per_week` × `way_hunting_hunt_weeks`
    × his colour factor against red (R2), summed, × the luck factor, rounded down once. It
    goes into the food stock; the expedition disappears and the party is released.
  - Luck: one draw per hunt out of 10 when it returns, with the counts
    `way_hunting_party[size]` (low, mid, high); the factor is `way_hunting_luck[level]`.

  Amounts are in thousandths (see `Fixed`). Random state is passed in and returned.
  """

  alias MyLiege.Engine.{Config, Fixed, Place, Worker}
  alias MyLiege.Engine.Place.{Blueprint, Expedition}
  alias MyLiege.Engine.Rules.{Placement, Production, Travel, Ways}

  @type luck :: :low | :mid | :high
  @lucks [:low, :mid, :high]

  @doc "How many weeks a hunt is away: out, hunting, back."
  def weeks(%Config{} = config),
    do: 2 * config.way_hunting_travel_weeks + config.way_hunting_hunt_weeks

  @doc """
  Whether `hunters` (each `{worker, place}`, `place` `nil` if unplaced) may set out: `:ok` or
  `{:error, reason}` with reason `:locked`, `:party_size` (none, or more than
  `way_hunting_max_party`), `:duplicate`, `:away` or `:travelling`, in this order.
  """
  def check_start(hunters, books, %Config{} = config) do
    workers = Enum.map(hunters, &elem(&1, 0))

    cond do
      Ways.check(Blueprint.fetch!(:hunting), books) != :ok ->
        {:error, :locked}

      hunters == [] or length(hunters) > config.way_hunting_max_party ->
        {:error, :party_size}

      workers |> Enum.uniq_by(& &1.id) |> length() < length(workers) ->
        {:error, :duplicate}

      Enum.any?(hunters, fn {_w, place} -> Placement.check_leave(place) != :ok end) ->
        {:error, :away}

      Enum.any?(workers, &Travel.travelling?/1) ->
        {:error, :travelling}

      true ->
        :ok
    end
  end

  @doc """
  Appends a hunt that sets out while the game stands at `week` to `places`, with the next
  free id; it returns at the end of `week` + `weeks/1`.
  """
  def new_expedition(places, week, %Config{} = config) do
    hunt = %Expedition{
      id: Place.next_id(places),
      blueprint: Blueprint.fetch!(:hunting),
      return_week: week + weeks(config)
    }

    places ++ [hunt]
  end

  @doc "What one hunter brings at a luck factor of 1000 (thousandths)."
  def hunter_haul(%Worker{} = worker, %Config{} = config) do
    factor = Production.efficiency(worker, Blueprint.fetch!(:hunting).colour, config)
    base = Fixed.from(config.way_hunting_food_per_week * config.way_hunting_hunt_weeks)
    div(base * factor, 1000)
  end

  @doc "The haul of `hunters` at `luck`: their hunter hauls summed, × the luck factor, rounded down."
  def haul(hunters, luck, %Config{} = config) when luck in @lucks do
    total = hunters |> Enum.map(&hunter_haul(&1, config)) |> Enum.sum()
    div(total * Map.fetch!(config.way_hunting_luck, luck), 1000)
  end

  @doc """
  Draws the luck of a party of `size`: one draw out of 10 from `rand`, low for the first
  `low` counts, then mid, then high. Returns `{luck, rand}`.
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
  Every hunt returning at the end of `week`, in the order of `places`: draws its luck, adds
  its haul, removes it and releases its party. Returns `{places, workers, food, results,
  rand}` with `results` a list of `%{hunters, luck, food}`.
  """
  def return(places, workers, week, %Config{} = config, rand) do
    returning = for %Expedition{} = hunt <- places, Expedition.returns?(hunt, week), do: hunt

    {results, rand} =
      Enum.map_reduce(returning, rand, fn hunt, rand ->
        hunters = Place.workers_at(workers, hunt.id)
        {luck, rand} = draw_luck(length(hunters), config, rand)
        {%{hunters: length(hunters), luck: luck, food: haul(hunters, luck, config)}, rand}
      end)

    ids = MapSet.new(returning, & &1.id)
    places = Enum.reject(places, &MapSet.member?(ids, &1.id))
    workers = Enum.reduce(returning, workers, &Placement.release(&2, &1.id, config))
    food = results |> Enum.map(& &1.food) |> Enum.sum()

    {places, workers, food, results, rand}
  end
end
