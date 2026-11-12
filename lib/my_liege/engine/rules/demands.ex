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
  culture are projects: a `Place.Project` among the places (`open_project/2`), with the
  amount as target and the colour of the good's home place. Only the workers placed on it
  fill it, producing as in that building; the stock is never used for it. It is delivered
  once it reaches the amount at or before the deadline, otherwise missed at the deadline, with
  no partial delivery. The player may refuse a project while it is open; a project leaves
  nothing to take. Refusals and misses count with missed taxes in `Misses`.

  The demand (`game.demand`) is the king's obligation, `%{product, amount, due_week,
  project_id}`; `project_id` points to its project, `nil` for a demand from the stock.
  """

  alias MyLiege.Engine.{Config, Fixed, Manameter, Pentagon, Place}
  alias MyLiege.Engine.Place.{Blueprint, Project}
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

    Pentagon.colours()
    |> Enum.sort_by(&(-Map.fetch!(manameter, &1)))
    |> Enum.at(rank)
  end

  @doc """
  The demand made at the end of `week` for a village of `population` workers, or `nil` if
  its amount is 0. Returns `%{product, amount, due_week, project_id: nil}`; amounts in
  thousandths. A knowledge or culture demand gets its project from `open_project/2`.
  """
  def make(week, weeks_per_year, %Manameter{} = manameter, population, %Config{} = config) do
    year = div(week - 1, weeks_per_year) + 1
    type = manameter |> colour(year) |> Blueprint.home_type()
    base = Map.fetch!(config.place_output_per_worker, type)
    units = Fixed.from(population * base * config.king_demand_production_weeks)
    amount = div(units * config.king_demand_population_share, 1000)

    if amount > 0,
      do: %{
        product: product_of(type),
        amount: amount,
        due_week: week + config.king_demand_deadline_weeks,
        project_id: nil
      }
  end

  @doc """
  Opens the project of a knowledge or culture `demand`: appends a `Place.Project` with the
  next free id, the amount as target and the good's home colour to `places`. Returns
  `{places, demand}` with the demand's `project_id` set. Other demands, and `nil`, are
  returned unchanged (also `nil`, no demand).
  """
  def open_project(places, %{product: product} = demand) when product in @project_products do
    project = %Project{
      id: Place.next_id(places),
      blueprint: Project.demand_blueprint(product),
      target: demand.amount,
      gives: {:demand, demand.due_week}
    }

    {places ++ [project], %{demand | project_id: project.id}}
  end

  def open_project(places, demand), do: {places, demand}

  @doc "Whether the demand is a project (knowledge or culture) rather than taken from the stock."
  def project?(nil), do: false
  def project?(demand), do: not is_nil(demand.project_id)

  @doc "The demand's project among `places`, or `nil` (no project, or no longer there)."
  def project(nil, _places), do: nil
  def project(%{project_id: nil}, _places), do: nil
  def project(%{project_id: id}, places), do: Enum.find(places, &(&1.id == id))

  @doc """
  Settles a demand. Returns `{outcome, stocks, taken}`: `:refused` is the player's choice. A
  project demand is `:delivered` if its project is done, otherwise `:missed`, and leaves the
  stocks alone; `project` is its project (`nil` once removed). Any other demand is
  `:delivered` by taking the amount from the stock, or `:missed` if the stock was not enough.
  On `:refused` and `:missed` of a food or gold demand the king takes the stock there is, up
  to the amount. `taken` is `%{food, gold}`, what the king took that way.
  """
  def settle(demand, project, stocks, deliver?)

  def settle(%{project_id: id}, project, stocks, deliver?) when id != nil do
    cond do
      not deliver? -> {:refused, stocks, nothing_taken()}
      project != nil and Project.done?(project) -> {:delivered, stocks, nothing_taken()}
      true -> {:missed, stocks, nothing_taken()}
    end
  end

  def settle(%{product: product, amount: amount}, _project, stocks, deliver?) do
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

  defp product_of(type), do: Blueprint.fetch!(type).good
end
