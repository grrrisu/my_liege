defmodule MyLiege.AutoRun do
  @moduledoc """
  Test A: plays a fixed placement pattern for a whole game, with random births from a seed.

  Before each week every unplaced worker is sent to its pattern's building type. If no
  building of that type is ready with room, the worker waits unplaced; a new building is
  ordered only when the ones already under construction can't take all waiting workers.

  Patterns:
  - `:stay` – every worker goes to a building of their own colour.
  - `:pivot` – as `:stay`, but workers born from `pivot_week` on go to a watchtower.
    Workers already placed stay where they are.
  - `:feed` – as `:stay`, but a newborn goes to a farm, whatever their colour, when last
    week's food balance (food left now minus food left a week earlier) can't feed one more
    worker (< `food_eaten_per_worker`), or when the food stock is below 0. Otherwise, while
    gold is below the next tax, it goes to a market.
  - `:feed_pivot` – a newborn goes to a farm when food is low as in `:feed`; workers born
    before `pivot_week` go to a market while gold is low as in `:feed`; otherwise it is
    placed as in `:pivot`.

  The next tax is the amount fixed at the count, or before the count `tax_per_worker` for
  every current worker.

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

  alias MyLiege.Engine.{Building, Config, Fixed, Game, Manameter, Taxes}

  # fixed by the designer, not read from the CSV
  @weeks_per_year 48

  # the plan's pivot measure: "how many weeks red needs to gain 20 points"
  @points 200

  @doc """
  Runs one game. Returns `{reports, game}`; reports start with week 0. The pattern always
  tries to pay taxes; the run ends early at game over.
  Option `:pivot_week` defaults to #{@weeks_per_year}.
  """
  def run(pattern, %Config{} = config, seed, opts \\ [])
      when pattern in [:stay, :pivot, :feed, :feed_pivot] do
    target = target(pattern, Keyword.get(opts, :pivot_week, @weeks_per_year), config)
    start = Game.new(config, seed)

    weeks = 1..(@weeks_per_year * config.years_per_game)

    {reports, game, _food_before} =
      Enum.reduce_while(weeks, {[], start, nil}, fn _, {reports, g, food_before} ->
        g = g |> place_unplaced(target, food_before, config) |> always_pay(config)

        case Game.run_week(g, config) do
          {:ok, report, next} -> {:cont, {[report | reports], next, g.stocks.food}}
          {:error, :game_over} -> {:halt, {reports, g, food_before}}
        end
      end)

    {[Game.report(start) | Enum.reverse(reports)], game}
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

  defp always_pay(game, config) do
    if Game.tax_decision_due?(game, config) do
      {:ok, game} = Game.decide_tax(game, true, config)
      game
    else
      game
    end
  end

  defp target(:stay, _pivot_week, _config),
    do: fn worker, _game, _food_before -> own_type(worker) end

  defp target(:pivot, pivot_week, _config) do
    fn worker, _game, _food_before -> pivot_type(worker, pivot_week) end
  end

  defp target(:feed, _pivot_week, config) do
    fn worker, game, food_before ->
      cond do
        food_low?(game, food_before, config) -> :farm
        gold_low?(game, config) -> :market
        true -> own_type(worker)
      end
    end
  end

  defp target(:feed_pivot, pivot_week, config) do
    fn worker, game, food_before ->
      cond do
        food_low?(game, food_before, config) -> :farm
        not pivoted?(worker, pivot_week) and gold_low?(game, config) -> :market
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

  defp gold_low?(game, config) do
    next_tax = game.tax_due || Taxes.assess(game.workers, config)
    game.stocks.gold < next_tax
  end

  defp food_low?(game, food_before, config) do
    food = game.stocks.food
    one_more = Fixed.from(config.food_eaten_per_worker)
    food < 0 or (food_before != nil and food - food_before < one_more)
  end

  # food_before: the food stock a week earlier, nil before week 1
  defp place_unplaced(game, target, food_before, config) do
    {game, _waiting} =
      game.workers
      |> Enum.filter(&is_nil(&1.building))
      |> Enum.reduce({game, %{}}, fn worker, {game, waiting} ->
        type = target.(worker, game, food_before)

        case place_in_any(game, worker, type, config) do
          {:ok, game} ->
            {game, waiting}

          :none ->
            waiting = Map.update(waiting, type, 1, &(&1 + 1))
            {order_if_needed(game, type, Map.fetch!(waiting, type), config), waiting}
        end
      end)

    game
  end

  defp place_in_any(game, worker, type, config) do
    game.buildings
    |> Enum.filter(&(&1.type == type))
    |> Enum.find_value(:none, fn building ->
      case Game.place_worker(game, worker.id, building.id, config) do
        {:ok, game} -> {:ok, game}
        {:error, _} -> nil
      end
    end)
  end

  defp order_if_needed(game, type, waiting_count, config) do
    room_under_construction =
      game.buildings
      |> Enum.filter(&(&1.type == type and not Building.ready?(&1, game.week + 1)))
      |> Enum.map(&Map.fetch!(config.capacity, &1.type))
      |> Enum.sum()

    if waiting_count > room_under_construction do
      {:ok, game} = Game.construct(game, type, config)
      game
    else
      game
    end
  end
end
