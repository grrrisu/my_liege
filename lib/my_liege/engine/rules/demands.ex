defmodule MyLiege.Engine.Rules.Demands do
  @moduledoc """
  R7, the king's demands, in addition to taxes. Twice a year, in a random week of each
  half year, the king demands an amount of one product, due `king_demand_deadline_weeks` later.
  The week is drawn from the half year's weeks after the grace period (`Grace`), so the
  deadline stays in the same half year; a half year with no such week has no demand and no
  draw.

  The product belongs to a colour picked by Manameter rank when the demand is made: the
  biggest share in year 1, the middle one (3rd of 5) in year 2, the smallest from year 3 on;
  ties in pentagon order. The amount is
  `population × king_demand_population_share (per mille) × base production of that colour's
  building × king_demand_production_weeks`, with the population passed in by the caller; a
  demand of 0 is not made.

  Demands for food, gold and defence are delivered from the stock: the player delivers or
  refuses, and delivering without enough stock is a miss. On a refusal or a miss of a food
  or gold demand, the king takes the stock there is, up to the amount; a defence demand
  leaves nothing to take. Demands for knowledge and
  culture are projects: they start at `progress` 0 and receive the village's whole
  production of that product until `progress` reaches the amount (the rest goes to the
  stock). A project doesn't spoil and never uses the stock; at the deadline it is delivered if
  it reached the amount, otherwise missed, with no partial delivery. The player may refuse a
  project while it is open; a project leaves nothing to take. Refusals and misses count with
  missed taxes in `Misses`.
  """

  alias MyLiege.Engine.{Building, Config, Fixed, Manameter}
  alias MyLiege.Engine.Rules.Grace

  @half_years_per_year 2
  @project_products [:knowledge, :culture]
  # what the king takes on a refusal or a miss; other products leave nothing to take
  @takeable_products [:food, :gold]
  # rank in the Manameter (0 = biggest share) for years 1, 2 and 3 on
  @ranks [0, 2, 4]

  @doc """
  Draws one demand week per half year for the whole game, from the half year's weeks after the
  grace period whose deadline stays in the half year. Half years without such a week are left
  out and use no draw. Returns `{weeks, rand}`.
  """
  def schedule(weeks_per_year, %Config{} = config, rand) do
    half = div(weeks_per_year, @half_years_per_year)
    halves = 0..(config.game_years * @half_years_per_year - 1)

    Enum.flat_map_reduce(halves, rand, fn h, rand ->
      first = max(h * half, Grace.last_week(config)) + 1
      last = (h + 1) * half - config.king_demand_deadline_weeks
      draw(first, last, rand)
    end)
  end

  defp draw(first, last, rand) when last < first, do: {[], rand}

  defp draw(first, last, rand) do
    {offset, rand} = :rand.uniform_s(last - first + 1, rand)
    {[first + offset - 1], rand}
  end

  @doc "The colour whose product the king demands in `year`, by its Manameter rank."
  def colour(%Manameter{} = manameter, year) do
    rank = Enum.at(@ranks, min(year, length(@ranks)) - 1)

    Manameter.colours()
    |> Enum.sort_by(&(-Map.fetch!(manameter, &1)))
    |> Enum.at(rank)
  end

  @doc """
  The demand made at the end of `week` for a village of `population` workers, or `nil` if
  its amount is 0. Returns `%{product, amount, due_week, progress}`; amounts in thousandths.
  `progress` is 0 for a project and `nil` for a demand delivered from the stock.
  """
  def make(week, weeks_per_year, %Manameter{} = manameter, population, %Config{} = config) do
    year = div(week - 1, weeks_per_year) + 1
    type = manameter |> colour(year) |> Building.type_of_colour()
    base = Map.fetch!(config.place_output_per_worker, type)
    units = Fixed.from(population * base * config.king_demand_production_weeks)
    amount = div(units * config.king_demand_population_share, 1000)

    product = product_of(type)

    if amount > 0,
      do: %{
        product: product,
        amount: amount,
        due_week: week + config.king_demand_deadline_weeks,
        progress: if(product in @project_products, do: 0)
      }
  end

  @doc "Whether the demand is a project (knowledge or culture) rather than taken from the stock."
  def project?(%{progress: progress}), do: is_integer(progress)
  def project?(nil), do: false

  @doc """
  Feeds a week's production to a project. Returns `{project, production}`, where the project
  received what it still lacked of its product and `production` keeps the rest, for the stock.
  """
  def feed(%{product: product, amount: amount, progress: progress} = project, production) do
    made = Map.fetch!(production, product)
    taken = min(made, max(amount - progress, 0))
    {%{project | progress: progress + taken}, %{production | product => made - taken}}
  end

  @doc """
  Settles a demand. Returns `{outcome, stocks, taken}`: `:refused` is the player's choice. A
  project is `:delivered` if its progress reached the amount, otherwise `:missed`, and leaves
  the stocks alone. Any other demand is `:delivered` by taking the amount from the stock, or
  `:missed` if the stock was not enough. On `:refused` and `:missed` of a food or gold demand
  the king takes the stock there is, up to the amount. `taken` is `%{food, gold}`, what the
  king took that way.
  """
  def settle(%{amount: amount, progress: progress}, stocks, deliver?) when is_integer(progress) do
    cond do
      not deliver? -> {:refused, stocks, nothing_taken()}
      progress >= amount -> {:delivered, stocks, nothing_taken()}
      true -> {:missed, stocks, nothing_taken()}
    end
  end

  def settle(%{product: product, amount: amount}, stocks, deliver?) do
    stock = Map.fetch!(stocks, product)

    cond do
      deliver? and stock >= amount ->
        {:delivered, %{stocks | product => stock - amount}, nothing_taken()}

      deliver? ->
        take(:missed, product, amount, stocks)

      true ->
        take(:refused, product, amount, stocks)
    end
  end

  defp take(outcome, product, amount, stocks) when product in @takeable_products do
    stock = Map.fetch!(stocks, product)
    taken = stock |> max(0) |> min(amount)
    {outcome, %{stocks | product => stock - taken}, %{nothing_taken() | product => taken}}
  end

  defp take(outcome, _product, _amount, stocks), do: {outcome, stocks, nothing_taken()}

  defp nothing_taken, do: Map.new(@takeable_products, &{&1, 0})

  defp product_of(type), do: Building.product(%Building{id: 0, type: type})
end
