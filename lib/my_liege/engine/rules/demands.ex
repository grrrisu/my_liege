defmodule MyLiege.Engine.Rules.Demands do
  @moduledoc """
  R7, the king's demands, in addition to taxes. Twice a year, in a random week of each
  half year, the king demands an amount of one product, due `demand_deadline_weeks` later.
  The week is drawn so the deadline stays in the same half year.

  The product belongs to a colour picked by Manameter rank when the demand is made: the
  biggest share in year 1, the middle one (3rd of 5) in year 2, the smallest from year 3 on;
  ties in pentagon order. The amount is
  `population × demand_population_share (per mille) × base production of that colour's
  building × demand_production_weeks`, with the population passed in by the caller; a
  demand of 0 is not made.

  Demands for food, gold and defence are delivered from the stock: the player delivers or
  refuses, and delivering without enough stock is a miss. Demands for knowledge and
  entertainment are projects: they start at `progress` 0 and receive the village's whole
  production of that product until `progress` reaches the amount (the rest goes to the
  stock). A project doesn't spoil and never uses the stock; at the deadline it is delivered if
  it reached the amount, otherwise missed, with no partial delivery. The player may refuse a
  project while it is open. Refusals and misses count with missed taxes in `Misses`.
  """

  alias MyLiege.Engine.{Building, Config, Fixed, Manameter}

  @half_years_per_year 2
  @project_products [:knowledge, :entertainment]
  # rank in the Manameter (0 = biggest share) for years 1, 2 and 3 on
  @ranks [0, 2, 4]

  @doc "Draws one demand week per half year for the whole game. Returns `{weeks, rand}`."
  def schedule(weeks_per_year, %Config{} = config, rand) do
    half = div(weeks_per_year, @half_years_per_year)
    halves = 0..(config.years_per_game * @half_years_per_year - 1)

    Enum.map_reduce(halves, rand, fn h, rand ->
      choices = half - config.demand_deadline_weeks
      {offset, rand} = :rand.uniform_s(choices, rand)
      {h * half + offset, rand}
    end)
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
    base = Map.fetch!(config.base_production, type)
    units = Fixed.from(population * base * config.demand_production_weeks)
    amount = div(units * config.demand_population_share, 1000)

    product = product_of(type)

    if amount > 0,
      do: %{
        product: product,
        amount: amount,
        due_week: week + config.demand_deadline_weeks,
        progress: if(product in @project_products, do: 0)
      }
  end

  @doc "Whether the demand is a project (knowledge or entertainment) rather than taken from the stock."
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
  Settles a demand. Returns `{outcome, stocks}`: `:refused` is the player's choice. A project
  is `:delivered` if its progress reached the amount, otherwise `:missed`, and leaves the
  stocks alone. Any other demand is `:delivered` by taking the amount from the stock, or
  `:missed` if the stock was not enough.
  """
  def settle(%{amount: amount, progress: progress}, stocks, deliver?) when is_integer(progress) do
    cond do
      not deliver? -> {:refused, stocks}
      progress >= amount -> {:delivered, stocks}
      true -> {:missed, stocks}
    end
  end

  def settle(%{product: product, amount: amount}, stocks, deliver?) do
    stock = Map.fetch!(stocks, product)

    cond do
      not deliver? -> {:refused, stocks}
      stock >= amount -> {:delivered, %{stocks | product => stock - amount}}
      true -> {:missed, stocks}
    end
  end

  defp product_of(type), do: Building.product(%Building{id: 0, type: type})
end
