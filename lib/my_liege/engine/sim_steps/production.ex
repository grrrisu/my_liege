defmodule MyLiege.Engine.SimSteps.Production do
  @moduledoc """
  Step 1 of the week, R2 production: the workers as placed at the start of the week; added to
  the stocks. R7: while a king's project is open and not refused, its product goes into the
  project first, up to its amount, and only the rest into the stock.
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Rules.{Demands, Production}

  @impl true
  def run(game, report) do
    production = Production.output(report.start.workers, game.buildings, game.week, game.config)
    {game, report, to_stock} = feed_project(game, %{report | production: production}, production)
    stocks = Map.merge(game.stocks, to_stock, fn _product, stock, made -> stock + made end)
    {%{game | stocks: stocks}, report}
  end

  defp feed_project(game, report, production) do
    if Demands.project?(game.demand) and game.deliver_demand != false do
      {project, to_stock} = Demands.feed(game.demand, production)
      {%{game | demand: project}, %{report | demand_progress: project.progress}, to_stock}
    else
      {game, report, production}
    end
  end
end
