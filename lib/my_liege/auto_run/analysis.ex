defmodule MyLiege.AutoRun.Analysis do
  @moduledoc """
  Reading bot runs: the summary CSV over patterns and seeds, the leading colour, the pivot
  weeks and the spread between runs.
  """

  alias MyLiege.AutoRun
  alias MyLiege.Engine.{Config, Fixed, Game, Pentagon}

  @weeks_per_year Game.weeks_per_year()

  # the plan's pivot measure: "how many weeks red needs to gain 20 points"
  @points 200

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
  Runs every pattern with every seed and returns a CSV: one row per pattern and seed, then
  a row per pattern with `seed` = `total` that sums the columns over its seeds. Takes the
  same options as `AutoRun.run/4`.

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
        runs =
          for seed <- seeds,
              do: summary(pattern, seed, AutoRun.play(pattern, config, seed, opts))

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
end
