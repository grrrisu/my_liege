defmodule MyLiege.Reporting do
  @moduledoc """
  Turns weekly reports (from `Game.report/1` and `Game.run_week/2`) into CSV, one row per week.
  Pass the week 0 report first to include the starting state.

  Values are in engine units: production and food in thousandths, Manameter shares in per mille.
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
      ["food_left", "newborn"]
  end

  defp row(report) do
    [report.week] ++
      Enum.map(Building.products(), &Map.fetch!(report.production, &1)) ++
      Enum.map(Manameter.colours(), &Map.fetch!(report.mana, &1)) ++
      Enum.map(Manameter.colours(), &Map.fetch!(report.manameter, &1)) ++
      [report.food_left, newborn(report.newborn)]
  end

  defp newborn(nil), do: ""
  defp newborn(worker), do: worker.colour
end
