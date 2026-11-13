defmodule MyLiege.Engine.SimSteps.Production do
  @moduledoc """
  Step 1 of the week, R2 production: the workers as placed at the start of the week. Output
  from buildings goes to the stocks. R11: the week's culture production from buildings
  against every worker at the start of the week sets the happiness step, which changes the
  food and defence production. R7: output from workers on a king's demand project, changed by
  the same happiness step, goes into that project, up to its target; the rest is lost. R12:
  what a worker on a book writes (with the Manameter at the start of the week) goes into the
  book, up to its target; the rest is lost.
  """
  @behaviour MyLiege.Engine.SimStep

  alias MyLiege.Engine.Place
  alias MyLiege.Engine.Place.{Blueprint, Project}
  alias MyLiege.Engine.Rules.{Demands, Happiness, Production}

  @impl true
  def run(game, report) do
    workers = report.start.workers
    production = Production.output(workers, game.places, game.week, game.config)
    happiness = Happiness.assess(production.culture, length(workers), game.week, game.config)
    production = Happiness.apply_step(production, happiness.step, game.config)
    stocks = Map.merge(game.stocks, production, fn _product, stock, made -> stock + made end)

    project_output =
      Production.project_output(
        workers,
        game.places,
        game.week,
        report.start.manameter,
        game.config
      )

    places = Enum.map(game.places, &fill(&1, project_output, happiness.step, game.config))
    game = %{game | stocks: stocks, places: places}

    report = %{
      report
      | production: production,
        happiness: happiness,
        demand_progress: demand_progress(game)
    }

    {game, report}
  end

  defp fill(%Project{gives: {:demand, _}} = project, project_output, step, config) do
    good = Place.good(project)
    output = %{nothing() | good => Map.get(project_output, project.id, 0)}
    made = output |> Happiness.apply_step(step, config) |> Map.fetch!(good)
    %{project | progress: min(project.progress + made, project.target)}
  end

  defp fill(%Project{gives: {:book, _}} = book, project_output, _step, _config) do
    made = Map.get(project_output, book.id, 0)
    %{book | progress: min(book.progress + made, book.target)}
  end

  defp fill(place, _project_output, _step, _config), do: place

  defp nothing, do: Map.new(Blueprint.goods(), &{&1, 0})

  defp demand_progress(game) do
    case Demands.project(game.demand, game.places) do
      %Project{progress: progress} -> progress
      nil -> nil
    end
  end
end
