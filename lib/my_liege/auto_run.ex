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
    can't feed one more worker (< `good_food_eaten_per_worker`), or when the food stock is below 0.
    Otherwise, while
    gold is below the next tax, it goes to a market.
  - `:feed_pivot` – a newborn goes to a farm when food is low as in `:feed`; workers born
    before `pivot_week` go to a market while gold is low as in `:feed`; otherwise it is
    placed as in `:pivot`.
  - `:feed_save_tax` – "Feed, save for tax": places as `:feed`, but orders a building only
    when `tax_safe_to_build?/1` allows it; otherwise the worker waits.
  - `:feed_defend` – "Feed, defend": as `:feed`, but while bandits are on their way, before
    anything else, workers move to watchtowers (`defend/1`). Moved workers stay there after
    the raid; from then on it plays as `:feed` again.
  - `:feed_invest_defend` – "Feed, invest and defend": as `:feed_defend`, but orders a
    building only when `invest_allowed?/3` allows it; otherwise the worker waits.

  The next tax is `Forecast.tax_amount/1`: the amount fixed at the count, or before the count
  `king_tax_per_worker` for every current worker.

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

  Summary of Feed and "Feed, save for tax" over 20 seeds, 48 weeks each (see `summary_csv/4`):

      csv = AutoRun.summary_csv([:feed, :feed_save_tax], config, 1..20, weeks: 48)
      File.write!("summary.csv", csv)
  """

  alias MyLiege.Engine.{Config, Fixed, Forecast, Game, Pentagon, Place}
  alias MyLiege.Engine.Place.{Blueprint, Building, Project}
  alias MyLiege.Engine.Rules.{Bandits, Production, Travel}

  @weeks_per_year Game.weeks_per_year()

  # the plan's pivot measure: "how many weeks red needs to gain 20 points"
  @points 200

  @patterns [:stay, :pivot, :feed, :feed_pivot, :feed_save_tax, :feed_defend, :feed_invest_defend]
  @defending [:feed_defend, :feed_invest_defend]

  @summary_header [
    "pattern",
    "seed",
    "first_tax_week",
    "first_tax_paid",
    "first_tax_missed",
    "first_tax_gold_difference",
    "buildings_ordered",
    "weeks_food_below_0",
    "gold_robbed"
  ]

  @doc """
  Runs one game. Returns `{reports, game}`; reports start with week 0. The pattern always
  tries to pay taxes and deliver the king's demands; the run ends early at game over.
  Options: `:pivot_week` defaults to #{@weeks_per_year}; `:weeks` stops the run after that
  many weeks (default: the whole game).
  """
  def run(pattern, %Config{} = config, seed, opts \\ []) when pattern in @patterns do
    {reports, game, _orders} = play(pattern, config, seed, opts)
    {reports, game}
  end

  # also returns the buildings ordered per week: `%{week => count}`, by the state they were
  # ordered at
  defp play(pattern, config, seed, opts) do
    target = target(pattern, Keyword.get(opts, :pivot_week, @weeks_per_year))
    may_build? = may_build?(pattern)
    start = Game.new(config, seed)

    last_week = min(Keyword.get(opts, :weeks, Game.last_week(start)), Game.last_week(start))

    # a week's report is kept after the pattern has acted on it, so it includes the gold spent
    # on buildings ordered then
    {reports, orders, game} =
      Enum.reduce_while(1..last_week//1, {[], %{}, start}, fn _, {reports, orders, g} ->
        if g.game_over do
          {:halt, {reports, orders, g}}
        else
          acted =
            g
            |> defend_if(pattern in @defending)
            |> staff_sites()
            |> place_unplaced(target, may_build?)
            |> always_pay()

          orders = Map.put(orders, g.week, length(acted.places) - length(g.places))
          {:ok, _report, next} = Game.run_week(acted)
          {:cont, {[Game.report(acted) | reports], orders, next}}
        end
      end)

    {Enum.reverse([Game.report(game) | reports]), game, orders}
  end

  @doc """
  "Feed, save for tax": whether a building may be ordered now. Not after a week in which gold
  left the stock other than by spoilage (tax, the king's takings, a delivered demand,
  robbery), because that week's change would distort the forecast. Otherwise only if the
  forecast gold for the next tax week (`Forecast.next_tax/1`; in week 0, which has no
  forecast, the gold now) minus the building's price still covers the tax. With no tax left
  in the game, always.
  """
  def tax_safe_to_build?(%Game{} = game) do
    not gold_left_last_week?(game) and covers_next_tax?(game)
  end

  defp gold_left_last_week?(%Game{report: %{stock_change: nil}}), do: false

  defp gold_left_last_week?(%Game{report: report}),
    do: report.production.gold - report.spoiled.gold - report.stock_change.gold > 0

  defp covers_next_tax?(game) do
    case Forecast.next_tax(game) do
      nil ->
        true

      %{amount: amount, expected_gold: expected} ->
        (expected || game.stocks.gold) - Game.build_cost(game) >= amount
    end
  end

  # each takes the game, the type to order and the workers waiting for it
  defp may_build?(:feed_save_tax), do: fn game, _type, _waiting -> tax_safe_to_build?(game) end
  defp may_build?(:feed_invest_defend), do: &invest_allowed?/3
  defp may_build?(_pattern), do: fn _game, _type, _waiting -> true end

  @doc """
  "Feed, invest and defend": whether a building of `type` may be ordered now for the
  `waiting` workers. A farm always while food is low (as in `:feed`). Otherwise only if the
  forecast gold for the next tax week (`Forecast.next_tax/1`; in week 0 the gold now) minus
  the price plus what the building is expected to earn until that week still covers the tax.
  Only a market earns gold: from its first producing week, ordered now + 1 + 2 ×
  `travel_weeks` (builders, then workers) + `build_weeks`, to the tax week, with the
  waiting workers up to its capacity. With no tax left in the game, always.
  """
  def invest_allowed?(%Game{} = game, type, waiting) do
    if type == :farm and food_low?(game) do
      true
    else
      case Forecast.next_tax(game) do
        nil ->
          true

        %{amount: amount, expected_gold: expected, due_week: due_week} ->
          gold = (expected || game.stocks.gold) - Game.build_cost(game)
          gold + earnings(game, type, waiting, due_week) >= amount
      end
    end
  end

  defp earnings(game, :market, waiting, due_week) do
    config = game.config
    first_week = game.week + 1 + 2 * config.travel_weeks + config.build_weeks
    market = %Building{id: 0, blueprint: Blueprint.fetch!(:market)}

    per_week =
      waiting
      |> Enum.take(Map.fetch!(config.place_capacity, :market))
      |> Enum.sum_by(&Production.worker_output(&1, market, config))

    per_week * max(due_week - first_week + 1, 0)
  end

  defp earnings(_game, _type, _waiting, _due_week), do: 0

  @doc """
  "Feed, defend": while bandits are on their way, moves workers to finished watchtowers with
  room until the protected gold in the raid week (the watchtowers' expected defence
  production × `bandit_cover_weeks`) covers the gold forecast for the raid week (the gold now
  plus last week's change for every week left), or no more workers can move. Only workers
  who arrive before the raid week count, so nobody moves once it is too late.

  First the unplaced workers who have arrived, red ones first. Then workers taken from
  finished path buildings (not watchtowers, sites or the guildhouse): from the product with
  the largest stock change last week, as long as that change stays at 0 or more without the
  worker's output.
  """
  def defend(%Game{} = game) do
    if Bandits.on_their_way?(game.bandits) and arrives_in_time?(game) do
      gold = raid_gold(game)
      defence = raid_defence(game)
      move_defenders(game, defence, gold, surplus(game))
    else
      game
    end
  end

  defp defend_if(game, true), do: defend(game)
  defp defend_if(game, false), do: game

  # a worker moved now travels `travel_weeks` and works from the week after
  defp arrives_in_time?(game),
    do: game.week + 1 + game.config.travel_weeks <= game.bandits.raid_week

  defp raid_gold(game) do
    change = with %{change: change} <- Forecast.gold(game), do: change
    game.stocks.gold + (change || 0) * (game.bandits.raid_week - game.week)
  end

  # defence produced in the raid week by workers already in watchtowers
  defp raid_defence(game) do
    raid_week = game.bandits.raid_week
    towers = Map.new(watchtowers(game), &{&1.id, &1})

    game.workers
    |> Enum.filter(&(Map.has_key?(towers, &1.place) and game.week + 1 + &1.travel <= raid_week))
    |> Enum.sum_by(&Production.worker_output(&1, Map.fetch!(towers, &1.place), game.config))
  end

  defp watchtowers(game),
    do: for(%Building{} = place <- game.places, Place.type(place) == :watchtower, do: place)

  defp move_defenders(game, defence, gold, surplus) do
    with true <- Bandits.protected(defence, game.config) < gold,
         {worker, surplus} <- next_defender(game, surplus),
         {:ok, game, tower} <- place_in_tower(game, worker) do
      output = Production.worker_output(worker, tower, game.config)
      move_defenders(game, defence + output, gold, surplus)
    else
      _ -> game
    end
  end

  defp next_defender(game, surplus) do
    case Enum.sort_by(available(game), &(&1.colour != :red)) do
      [worker | _] -> {worker, surplus}
      [] -> spare_worker(game, surplus)
    end
  end

  # a producing worker whose product keeps a change of 0 or more without it
  defp spare_worker(game, surplus) do
    places = Map.new(game.places, &{&1.id, &1})

    candidates =
      for worker <- game.workers,
          place = places[worker.place],
          place != nil,
          spare_building?(place),
          not Travel.travelling?(worker),
          product = Place.good(place),
          output = Production.worker_output(worker, place, game.config),
          Map.fetch!(surplus, product) - output >= 0,
          do: {worker, product, output}

    case Enum.max_by(candidates, fn {_, product, _} -> Map.fetch!(surplus, product) end, fn ->
           nil
         end) do
      nil -> nil
      {worker, product, output} -> {worker, Map.update!(surplus, product, &(&1 - output))}
    end
  end

  defp spare_building?(%Building{} = place),
    do: Place.type(place) not in [:watchtower, :guildhouse]

  defp spare_building?(%Project{}), do: false

  defp surplus(%Game{report: %{stock_change: nil}}), do: Map.new(Blueprint.goods(), &{&1, 0})
  defp surplus(%Game{report: report}), do: report.stock_change

  defp place_in_tower(game, worker) do
    game
    |> watchtowers()
    |> Enum.find_value(fn tower ->
      case Game.place_worker(game, worker.id, tower.id) do
        {:ok, game} -> {:ok, game, tower}
        {:error, _} -> nil
      end
    end)
  end

  @doc """
  Runs every pattern with every seed and returns a CSV: one row per pattern and seed, then
  a row per pattern with `seed` = `total` that sums the columns over its seeds. Takes the
  same options as `run/4`.

  - `first_tax_week`: the week of the first tax payment (empty if the run ended before it;
    empty in the totals).
  - `first_tax_paid`, `first_tax_missed`: 1 or 0.
  - `first_tax_gold_difference`: gold at the end of the week before the first tax week minus
    the tax amount.
  - `buildings_ordered`: buildings ordered while the game stood at weeks 1 to
    #{@weeks_per_year}.
  - `weeks_food_below_0`: weeks of the run that ended with food below 0.
  - `gold_robbed`: gold the bandits took in the run.

  Gold is in whole gold, not thousandths.
  """
  def summary_csv(patterns, %Config{} = config, seeds, opts \\ []) do
    rows =
      Enum.flat_map(patterns, fn pattern ->
        runs = for seed <- seeds, do: summary(pattern, seed, play(pattern, config, seed, opts))
        runs ++ [totals(pattern, runs)]
      end)

    Enum.map_join(
      [@summary_header | Enum.map(rows, &summary_row/1)],
      &(Enum.join(&1, ",") <> "\n")
    )
  end

  defp summary(pattern, seed, {reports, _game, orders}) do
    first_tax = Enum.find(reports, &(&1.tax != nil))

    %{
      pattern: pattern,
      seed: seed,
      first_tax_week: first_tax && first_tax.week,
      first_tax_paid: first_tax && if(first_tax.tax == :paid, do: 1, else: 0),
      first_tax_missed: first_tax && if(first_tax.tax == :missed, do: 1, else: 0),
      first_tax_gold_difference: first_tax && gold_difference(reports, first_tax.week),
      buildings_ordered:
        orders |> Enum.filter(fn {week, _} -> week in 1..@weeks_per_year end) |> sum_values(),
      weeks_food_below_0: Enum.count(reports, &(&1.food_left < 0)),
      gold_robbed: Enum.sum_by(reports, & &1.gold_robbed)
    }
  end

  # the amount is fixed in the count week, the last report before the payment with `tax_due`
  defp gold_difference(reports, due_week) do
    before = Enum.find(reports, &(&1.week == due_week - 1))
    counted = reports |> Enum.filter(&(&1.week < due_week and &1.tax_due)) |> List.last()
    before.gold - counted.tax_due
  end

  defp totals(pattern, runs) do
    sum = fn key ->
      runs |> Enum.map(&Map.fetch!(&1, key)) |> Enum.reject(&is_nil/1) |> sum_or_nil()
    end

    %{
      pattern: pattern,
      seed: "total",
      first_tax_week: nil,
      first_tax_paid: sum.(:first_tax_paid),
      first_tax_missed: sum.(:first_tax_missed),
      first_tax_gold_difference: sum.(:first_tax_gold_difference),
      buildings_ordered: sum.(:buildings_ordered),
      weeks_food_below_0: sum.(:weeks_food_below_0),
      gold_robbed: sum.(:gold_robbed)
    }
  end

  defp sum_values(pairs), do: Enum.sum_by(pairs, &elem(&1, 1))

  defp sum_or_nil([]), do: nil
  defp sum_or_nil(values), do: Enum.sum(values)

  defp summary_row(summary) do
    [
      summary.pattern,
      summary.seed,
      summary.first_tax_week,
      summary.first_tax_paid,
      summary.first_tax_missed,
      whole_gold(summary.first_tax_gold_difference),
      summary.buildings_ordered,
      summary.weeks_food_below_0,
      whole_gold(summary.gold_robbed)
    ]
  end

  defp whole_gold(nil), do: nil

  defp whole_gold(amount) do
    if rem(amount, Fixed.scale()) == 0,
      do: div(amount, Fixed.scale()),
      else: :erlang.float_to_binary(amount / Fixed.scale(), [:compact, decimals: 3])
  end

  @doc """
  The leading colour and its share at the end of each year the run reached:
  `[{week, colour, share}]`.
  """
  def leading(reports, %Config{} = config) do
    for year <- 1..config.game_years,
        week = year * @weeks_per_year,
        report = Enum.find(reports, &(&1.week == week)) do
      colour = Enum.max_by(Pentagon.colours(), &Map.fetch!(report.manameter, &1))
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
      Map.new(Pentagon.colours(), fn colour ->
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

  defp target(pattern, pivot_week) when pattern in [:feed_save_tax | @defending],
    do: target(:feed, pivot_week)

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

  defp own_type(worker), do: Blueprint.home_type(worker.colour)

  defp pivot_type(worker, pivot_week) do
    if pivoted?(worker, pivot_week), do: :watchtower, else: own_type(worker)
  end

  defp pivoted?(worker, pivot_week),
    do: worker.born_week != nil and worker.born_week >= pivot_week

  defp gold_low?(game), do: game.stocks.gold < Forecast.tax_amount(game)

  defp food_low?(game) do
    one_more = Fixed.from(game.config.good_food_eaten_per_worker)

    case Forecast.food(game) do
      nil -> game.stocks.food < 0
      forecast -> game.stocks.food < 0 or forecast.change < one_more
    end
  end

  defp staff_sites(game) do
    game.places
    |> Enum.filter(&match?(%Project{}, &1))
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
    do: Enum.filter(game.workers, &(is_nil(&1.place) and not Travel.travelling?(&1)))

  defp place_unplaced(game, target, may_build?) do
    {game, _waiting} =
      game
      |> available()
      |> Enum.reduce({game, %{}}, fn worker, {game, waiting} ->
        type = target.(worker, game)

        case place_in_any(game, worker, type) do
          {:ok, game} ->
            {game, waiting}

          :none ->
            waiting = Map.update(waiting, type, [worker], &(&1 ++ [worker]))
            {order_if_needed(game, type, Map.fetch!(waiting, type), may_build?), waiting}
        end
      end)

    game
  end

  defp place_in_any(game, worker, type) do
    game.places
    |> Enum.filter(&(builds(&1) == type))
    |> Enum.find_value(:none, fn place ->
      case Game.place_worker(game, worker.id, place.id) do
        {:ok, game} -> {:ok, game}
        {:error, _} -> nil
      end
    end)
  end

  defp order_if_needed(game, type, waiting, may_build?) do
    sites = Enum.count(game.places, &match?(%Project{gives: {:building, ^type}}, &1))
    room_under_construction = sites * Map.fetch!(game.config.place_capacity, type)

    with true <- length(waiting) > room_under_construction,
         true <- may_build?.(game, type, waiting),
         {:ok, game} <- Game.construct(game, type) do
      game
    else
      _ -> game
    end
  end

  # the type of a building, or of the building a site gives; a waiting worker may also be
  # placed on a site of its type, as a builder
  defp builds(%Building{} = building), do: Place.type(building)
  defp builds(%Project{gives: {:building, type}}), do: type
end
