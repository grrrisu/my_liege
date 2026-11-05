defmodule MyLiege.Engine.SimSteps.Production do
  @moduledoc "Production (R2): the workers as placed at the start of the week; added to the stocks."
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Production

  @impl true
  def run(game, report) do
    production = Production.week(report.start.workers, game.buildings, game.week, game.config)
    stocks = Map.merge(game.stocks, production, fn _product, stock, made -> stock + made end)
    {%{game | stocks: stocks}, %{report | production: production}}
  end
end
