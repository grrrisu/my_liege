defmodule MyLiege.AutoRun.BotActions.StaffSites do
  @moduledoc """
  Arrived unplaced workers fill every site that is short of builders, whatever their
  colour, in worker order. A site ordered before a week gets its builders before the week
  after.
  """

  @behaviour MyLiege.AutoRun.BotAction

  alias MyLiege.AutoRun.Placing
  alias MyLiege.Engine.Game
  alias MyLiege.Engine.Place.Project

  @impl true
  def run(%Game{} = game, _opts) do
    game.places
    |> Enum.filter(&match?(%Project{gives: {:building, _}}, &1))
    |> Enum.reduce(game, &staff_site(&2, &1))
  end

  defp staff_site(game, site) do
    game
    |> Placing.available()
    |> Enum.reduce_while(game, fn worker, game ->
      case Game.place_worker(game, worker.id, site.id) do
        {:ok, game} -> {:cont, game}
        {:error, _reason} -> {:halt, game}
      end
    end)
  end
end
