defmodule MyLiege.AutoRun do
  @moduledoc """
  Test A: plays a fixed placement pattern for a whole game, with random births from a seed.

  Before each week, unplaced workers who have arrived (travel 0) first fill every site that
  is short of builders, whatever their colour, in worker order. The rest are sent to their
  pattern's building type. If no building of that type is ready with room, the worker waits
  unplaced; a new building is ordered only when the ones already under construction can't
  take all waiting workers, and only if the gold stock covers `build_cost_gold`; otherwise
  the worker waits and the pattern tries again before the next week. A site ordered then
  gets its builders before the next week after.

  Patterns:
  - `:stay` – every worker goes to a building of their own colour.
  - `:pivot` – as `:stay`, but workers born from `pivot_week` on go to a watchtower.
    Workers already placed stay where they are.
  - `:feed` – as `:stay`, but a newborn goes to a farm, whatever their colour, when last
    week's food balance (`Forecast.food/1`: the change in the food stock in the last week)
    can't feed one more worker (< `food_eaten_per_worker`), or when the food stock is below 0.
    Otherwise, while
    gold is below the next tax, it goes to a market.
  - `:feed_pivot` – a newborn goes to a farm when food is low as in `:feed`; workers born
    before `pivot_week` go to a market while gold is low as in `:feed`; otherwise it is
    placed as in `:pivot`.

  The next tax is `Forecast.tax_amount/1`: the amount fixed at the count, or before the count
  `tax_per_worker` for every current worker.

  ## Running the test cases

  Start a console with `iex -S mix`, then:

      alias MyLiege.AutoRun
      config = MyLiege.Engine.Config.from_csv()

  Stay, one run, and the leading colour at the end of each year:

      {reports, _game} = AutoRun.run(:stay, config, 1)
      AutoRun.leading(reports, config)

  Pivot, one run, and the weeks red needs to gain 20 points (`nil` if never); the
  pivot week can be changed with `pivot_week: 24`:

      {reports, _game} = AutoRun.run(:pivot, config, 1)
      AutoRun.pivot_weeks(reports)

  About 20 random runs of a pattern, and the spread between them at a week:

      runs = for seed <- 1..20, do: elem(AutoRun.run(:pivot, config, seed), 0)
      AutoRun.spread(runs, 144)

  Export one run as CSV:

      File.write!("pivot_1.csv", MyLiege.Reporting.to_csv(hd(runs)))
  """

  alias MyLiege.Engine.{Building, Config, Fixed, Forecast, Game, Manameter}
  alias MyLiege.Engine.Rules.Travel

  @weeks_per_year Game.weeks_per_year()

  # the plan's pivot measure: "how many weeks red needs to gain 20 points"
  @points 200

  @doc """
  Runs one game. Returns `{reports, game}`; reports start with week 0. The pattern always
  tries to pay taxes and deliver the king's demands; the run ends early at game over.
  Option `:pivot_week` defaults to #{@weeks_per_year}.
  """
  def run(pattern, %Config{} = config, seed, opts \\ [])
      when pattern in [:stay, :pivot, :feed, :feed_pivot] do
    target = target(pattern, Keyword.get(opts, :pivot_week, @weeks_per_year))
    start = Game.new(config, seed)

    weeks = 1..Game.last_week(start)

    # a week's report is kept after the pattern has acted on it, so it includes the gold spent
    # on buildings ordered then
    {reports, game} =
      Enum.reduce_while(weeks, {[], start}, fn _, {reports, g} ->
        if g.game_over do
          {:halt, {reports, g}}
        else
          g =
            g
            |> staff_sites()
            |> place_unplaced(target)
            |> always_pay()

          {:ok, _report, next} = Game.run_week(g)
          {:cont, {[Game.report(g) | reports], next}}
        end
      end)

    {Enum.reverse([Game.report(game) | reports]), game}
  end

  @doc """
  The leading colour and its share at the end of each year the run reached:
  `[{week, colour, share}]`.
  """
  def leading(reports, %Config{} = config) do
    for year <- 1..config.years_per_game,
        week = year * @weeks_per_year,
        report = Enum.find(reports, &(&1.week == week)) do
      colour = Enum.max_by(Manameter.colours(), &Map.fetch!(report.manameter, &1))
      {week, colour, Map.fetch!(report.manameter, colour)}
    end
  end

  @doc """
  Weeks red needs to gain 20 points (200 per mille) from its share before `pivot_week`,
  or `nil` if it never does (or the run ended before the pivot).
  """
  def pivot_weeks(reports, opts \\ []) do
    pivot_week = Keyword.get(opts, :pivot_week, @weeks_per_year)

    with %{manameter: %{red: base}} <- Enum.find(reports, &(&1.week == pivot_week - 1)) do
      Enum.find_value(reports, &weeks_to_gain(&1, base, pivot_week))
    end
  end

  defp weeks_to_gain(report, base, pivot_week) do
    if report.week >= pivot_week and report.manameter.red - base >= @points,
      do: report.week - (pivot_week - 1)
  end

  @doc """
  Lowest and highest share per colour at `week` across the runs that reached it:
  `%{colour => {min, max}}`, or `nil` if none did.
  """
  def spread(runs, week) do
    manameters =
      for reports <- runs, report = Enum.find(reports, &(&1.week == week)) do
        report.manameter
      end

    if manameters != [] do
      Map.new(Manameter.colours(), fn colour ->
        {colour, manameters |> Enum.map(&Map.fetch!(&1, colour)) |> Enum.min_max()}
      end)
    end
  end

  defp always_pay(game) do
    game =
      if Game.tax_decision_due?(game),
        do: elem(Game.decide_tax(game, true), 1),
        else: game

    if Game.demand_decision_due?(game),
      do: elem(Game.decide_demand(game, true), 1),
      else: game
  end

  defp target(:stay, _pivot_week),
    do: fn worker, _game -> own_type(worker) end

  defp target(:pivot, pivot_week) do
    fn worker, _game -> pivot_type(worker, pivot_week) end
  end

  defp target(:feed, _pivot_week) do
    fn worker, game ->
      cond do
        food_low?(game) -> :farm
        gold_low?(game) -> :market
        true -> own_type(worker)
      end
    end
  end

  defp target(:feed_pivot, pivot_week) do
    fn worker, game ->
      cond do
        food_low?(game) -> :farm
        not pivoted?(worker, pivot_week) and gold_low?(game) -> :market
        true -> pivot_type(worker, pivot_week)
      end
    end
  end

  defp own_type(worker), do: Building.type_of_colour(worker.colour)

  defp pivot_type(worker, pivot_week) do
    if pivoted?(worker, pivot_week), do: :watchtower, else: own_type(worker)
  end

  defp pivoted?(worker, pivot_week),
    do: worker.born_week != nil and worker.born_week >= pivot_week

  defp gold_low?(game), do: game.stocks.gold < Forecast.tax_amount(game)

  defp food_low?(game) do
    one_more = Fixed.from(game.config.food_eaten_per_worker)

    case Forecast.food(game) do
      nil -> game.stocks.food < 0
      forecast -> game.stocks.food < 0 or forecast.change < one_more
    end
  end

  defp staff_sites(game) do
    game.buildings
    |> Enum.filter(&Building.site?/1)
    |> Enum.reduce(game, &staff_site(&2, &1))
  end

  defp staff_site(game, site) do
    game
    |> available()
    |> Enum.reduce_while(game, fn worker, game ->
      case Game.place_worker(game, worker.id, site.id) do
        {:ok, game} -> {:cont, game}
        {:error, _reason} -> {:halt, game}
      end
    end)
  end

  # unplaced workers who have arrived and can be placed
  defp available(game),
    do: Enum.filter(game.workers, &(is_nil(&1.building) and not Travel.travelling?(&1)))

  defp place_unplaced(game, target) do
    {game, _waiting} =
      game
      |> available()
      |> Enum.reduce({game, %{}}, fn worker, {game, waiting} ->
        type = target.(worker, game)

        case place_in_any(game, worker, type) do
          {:ok, game} ->
            {game, waiting}

          :none ->
            waiting = Map.update(waiting, type, 1, &(&1 + 1))
            {order_if_needed(game, type, Map.fetch!(waiting, type)), waiting}
        end
      end)

    game
  end

  defp place_in_any(game, worker, type) do
    game.buildings
    |> Enum.filter(&(&1.type == type))
    |> Enum.find_value(:none, fn building ->
      case Game.place_worker(game, worker.id, building.id) do
        {:ok, game} -> {:ok, game}
        {:error, _} -> nil
      end
    end)
  end

  defp order_if_needed(game, type, waiting_count) do
    room_under_construction =
      game.buildings
      |> Enum.filter(&(&1.type == type and not Building.ready?(&1, game.week + 1)))
      |> Enum.map(&Map.fetch!(game.config.capacity, &1.type))
      |> Enum.sum()

    with true <- waiting_count > room_under_construction,
         {:ok, game} <- Game.construct(game, type) do
      game
    else
      _ -> game
    end
  end
end
