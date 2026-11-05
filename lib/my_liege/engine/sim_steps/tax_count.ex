defmodule MyLiege.Engine.SimSteps.TaxCount do
  @moduledoc "Step 0 of the week, R7 tax count: in a count week, counts all workers as at the start of the week."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.Taxes

  @impl true
  def run(game, report) do
    if Taxes.count_week?(game.week, game.config) do
      due = Taxes.assess(report.start.workers, game.config)
      {%{game | tax_due: due}, %{report | tax_due: due}}
    else
      {game, report}
    end
  end
end
