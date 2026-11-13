defmodule MyLiege.Bot.BotActions.DemandProject do
  @moduledoc """
  The designer's rule (2026-11-13), while a king's demand project is open (`game.demand`
  with a `project_id` whose project is in `game.places`). Only workers of the project's
  colour go to it (violet for a culture project, blue for a knowledge one); every other
  worker is left to the next action. It starts nothing and refuses nothing. With no open
  demand project it does nothing.

  1. Unplaced, arrived workers of the project's colour all go to it (`target/3`, in the
     placing pass).
  2. Then (`after_pass/2`), only as many as needed: while the project's expected output by
     the due week doesn't cover what it still lacks (`target - progress`), workers of its
     colour move to it from finished buildings, in worker order. Not from watchtowers, the
     guildhouse or sites, and not workers still travelling. Only if they are in time: a
     worker moved now works from week `week + 1 + travel_weeks`, and the due week's
     production still counts, so nobody moves if that is after the due week.

  Expected output: every worker on the project produces `Rules.Production.worker_output/3`
  (without the happiness step, which is not known ahead) in every week from its arrival to
  the due week.

  Workers released when the project ends are unplaced and travelling; once they have
  arrived, later actions place them as usual. A placing action (`MyLiege.Bot.Placing`),
  with a `{:place, project_id}` target.
  """

  @behaviour MyLiege.Bot.BotAction
  @behaviour MyLiege.Bot.Placing

  alias MyLiege.Bot.Placing
  alias MyLiege.Engine.{Game, Place}
  alias MyLiege.Engine.Place.Building
  alias MyLiege.Engine.Rules.{Demands, Production}

  # buildings the action takes no workers from
  @kept [:watchtower, :guildhouse]

  @impl MyLiege.Bot.BotAction
  def run(%Game{} = game, opts),
    do: Placing.run(game, Keyword.put(opts, :rules, [{__MODULE__, opts}]))

  @impl MyLiege.Bot.Placing
  def target(worker, game, _opts) do
    case open_project(game) do
      nil -> nil
      project -> if worker.colour == Place.colour(project), do: {:place, project.id}
    end
  end

  @impl MyLiege.Bot.Placing
  def after_pass(%Game{} = game, _opts) do
    with project when project != nil <- open_project(game),
         true <- in_time?(game) do
      game |> candidates(project) |> move_while_short(game, project)
    else
      _ -> game
    end
  end

  defp open_project(game), do: Demands.project(game.demand, game.places)

  defp in_time?(game), do: game.week + 1 + game.config.travel_weeks <= game.demand.due_week

  # workers of the project's colour who have arrived in a finished building it may take from
  defp candidates(game, project) do
    buildings =
      for %Building{} = b <- game.places, Place.type(b) not in @kept, into: %{}, do: {b.id, b}

    colour = Place.colour(project)

    Enum.filter(
      game.workers,
      &(&1.colour == colour and &1.travel == 0 and Map.has_key?(buildings, &1.place))
    )
  end

  defp move_while_short([], game, _project), do: game

  defp move_while_short([worker | rest], game, project) do
    if expected(game, project) >= project.target - project.progress do
      game
    else
      case Game.place_worker(game, worker.id, project.id) do
        {:ok, game} -> move_while_short(rest, game, project)
        {:error, _reason} -> move_while_short(rest, game, project)
      end
    end
  end

  # what the workers on the project make by the due week: a worker with `travel` left works
  # from week `game.week + 1 + travel` to the due week
  defp expected(game, project) do
    due_week = game.demand.due_week

    game.workers
    |> Enum.filter(&(&1.place == project.id))
    |> Enum.sum_by(fn worker ->
      weeks = max(due_week - game.week - worker.travel, 0)
      Production.worker_output(worker, project, game.config) * weeks
    end)
  end
end
