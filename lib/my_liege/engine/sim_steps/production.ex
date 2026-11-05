defmodule MyLiege.Engine.SimSteps.Production do
  @moduledoc "Step 1 of the week, R2 production: the workers as placed at the start of the week; added to the stocks."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.Production

  @impl true
  def run(game, report) do
    production = Production.output(report.start.workers, game.buildings, game.week, game.config)
    stocks = Map.merge(game.stocks, production, fn _product, stock, made -> stock + made end)
    {%{game | stocks: stocks}, %{report | production: production}}
  end
end
