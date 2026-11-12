defmodule MyLiege.Reporting do
  @moduledoc """
  Turns weekly reports (from `Game.report/1` and `Game.run_week/1`) into CSV, one row per week.
  Pass the week 0 report first to include the starting state.

  Values are in engine units: production, food and gold in thousandths, Manameter shares in
  per mille. `tax_due` is filled in the count week, `tax` (paid, skipped, missed) in the due week.
  `trained` lists the colours of the workers who finished training that week, space-separated.
  `builders` counts the builders on sites who have arrived, `travelling` the workers still
  travelling, both at the end of the week.
  `demand_product` and `demand_amount` are filled in the week the king makes a demand,
  `demand_outcome` (delivered, refused, missed) in its deadline week, or for a refused
  project in the week after the refusal. `demand_progress` is a project's (knowledge or
  culture) total at the end of every week it is open, empty otherwise. `spoiled_*` is what each
  stock lost at the end of the week; `food_left` and `gold` are after spoilage.
  `gold_spent_buildings` is the gold paid for buildings ordered while the game stood at that
  week (after it ran, before the next one), so it is not yet taken from that row's `gold`.
  `king_took_gold` and `king_took_food` are what the king took that week on a skipped or
  missed tax and on a refused or missed demand, before spoilage.
  R10: `bandit_pressure` is gold ÷ protected gold in per mille, `inf` without defence
  production, empty in week 0; `bandit_threat` (thousandths) and `bandits_weeks_to_raid` are at
  the end of the week, the latter empty when no bandits are on their way (also in the raid
  week); `gold_robbed` is what the bandits took that week, before spoilage.
  R11: `happiness_ratio` is the week's culture production ÷ what the population needs,
  in per mille; `happiness_step` (−3 to 3, a plain number) is the step applied to food and
  defence, 0 in the grace period. Both empty in week 0.
  """

  alias MyLiege.Engine.{Building, Pentagon}

  @doc "Returns the reports as CSV text with a header row."
  def to_csv(reports) do
    Enum.map_join([header() | Enum.map(reports, &row/1)], &(Enum.join(&1, ",") <> "\n"))
  end

  defp header do
    ["week"] ++
      Enum.map(Building.products(), &"production_#{&1}") ++
      Enum.map(Pentagon.colours(), &"mana_#{&1}") ++
      Enum.map(Pentagon.colours(), &"manameter_#{&1}") ++
      ["food_left", "newborn", "trained", "builders", "travelling", "gold", "tax_due", "tax"] ++
      ["demand_product", "demand_amount", "demand_outcome", "demand_progress"] ++
      ["king_took_gold", "king_took_food"] ++
      Enum.map(Building.products(), &"spoiled_#{&1}") ++
      ["gold_spent_buildings"] ++
      ["bandit_pressure", "bandit_threat", "bandits_weeks_to_raid", "gold_robbed"] ++
      ["happiness_ratio", "happiness_step"] ++
      ["game_over"]
  end

  defp row(report) do
    [report.week] ++
      Enum.map(Building.products(), &Map.fetch!(report.production, &1)) ++
      Enum.map(Pentagon.colours(), &Map.fetch!(report.mana, &1)) ++
      Enum.map(Pentagon.colours(), &Map.fetch!(report.manameter, &1)) ++
      [
        report.food_left,
        newborn(report.newborn),
        Enum.map_join(report.trained, " ", & &1.colour),
        report.builders,
        report.travelling,
        report.gold,
        report.tax_due,
        report.tax,
        report.demand && report.demand.product,
        report.demand && report.demand.amount,
        report.demand_outcome,
        report.demand_progress,
        report.king_took.gold,
        report.king_took.food
      ] ++
      Enum.map(Building.products(), &Map.fetch!(report.spoiled, &1)) ++
      [
        report.gold_spent_buildings,
        pressure(report.bandit_pressure),
        report.bandit_threat,
        report.bandits_weeks_to_raid,
        report.gold_robbed,
        report.happiness && report.happiness.ratio,
        report.happiness && report.happiness.step,
        report.game_over
      ]
  end

  defp pressure(:unbounded), do: "inf"
  defp pressure(pressure), do: pressure

  defp newborn(nil), do: ""
  defp newborn(worker), do: worker.colour
end
