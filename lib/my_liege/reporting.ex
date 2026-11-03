defmodule MyLiege.Reporting do
  @moduledoc """
  Turns weekly reports (from `Game.report/1` and `Game.run_week/2`) into CSV, one row per week.
  Pass the week 0 report first to include the starting state.

  Values are in engine units: production, food and gold in thousandths, Manameter shares in
  per mille. `tax_due` is filled in the count week, `tax` (paid, skipped, missed) in the due week.
  `trained` lists the colours of the workers who finished training that week, space-separated.
  `demand_product` and `demand_amount` are filled in the week the king makes a demand,
  `demand_outcome` (delivered, refused, missed) in its deadline week. `spoiled_*` is what each
  stock lost at the end of the week; `food_left` and `gold` are after spoilage.
  `gold_spent_buildings` is the gold paid for buildings ordered while the game stood at that
  week (after it ran, before the next one), so it is not yet taken from that row's `gold`.
  """

  alias MyLiege.Engine.{Building, Manameter}

  @doc "Returns the reports as CSV text with a header row."
  def to_csv(reports) do
    Enum.map_join([header() | Enum.map(reports, &row/1)], &(Enum.join(&1, ",") <> "\n"))
  end

  defp header do
    ["week"] ++
      Enum.map(Building.products(), &"production_#{&1}") ++
      Enum.map(Manameter.colours(), &"mana_#{&1}") ++
      Enum.map(Manameter.colours(), &"manameter_#{&1}") ++
      ["food_left", "newborn", "trained", "gold", "tax_due", "tax"] ++
      ["demand_product", "demand_amount", "demand_outcome"] ++
      Enum.map(Building.products(), &"spoiled_#{&1}") ++
      ["gold_spent_buildings", "game_over"]
  end

  defp row(report) do
    [report.week] ++
      Enum.map(Building.products(), &Map.fetch!(report.production, &1)) ++
      Enum.map(Manameter.colours(), &Map.fetch!(report.mana, &1)) ++
      Enum.map(Manameter.colours(), &Map.fetch!(report.manameter, &1)) ++
      [
        report.food_left,
        newborn(report.newborn),
        Enum.map_join(report.trained, " ", & &1.colour),
        report.gold,
        report.tax_due,
        report.tax,
        report.demand && report.demand.product,
        report.demand && report.demand.amount,
        report.demand_outcome
      ] ++
      Enum.map(Building.products(), &Map.fetch!(report.spoiled, &1)) ++
      [report.gold_spent_buildings, report.game_over]
  end

  defp newborn(nil), do: ""
  defp newborn(worker), do: worker.colour
end
