defmodule MyLiege.Engine.Actions.StartHunt do
  @moduledoc """
  Sends a hunting party out (R17) with the workers `worker_ids`: appends the hunt to the
  places, at no cost, and puts every hunter on it, away from the next week (no travel of their
  own; a trainee loses his training). The king's suspicion rises (R18). Returns `{:ok, game}`,
  or `{:error, reason}` with reason `:unknown_worker`, `:locked` (R13), `:party_size`,
  `:duplicate`, `:away` or `:travelling` (see `Rules.Hunting.check_start/3`).
  """

  alias MyLiege.Engine.{Game, Place}
  alias MyLiege.Engine.Rules.{Hunting, Suspicion}

  def run(%Game{} = game, worker_ids) when is_list(worker_ids) do
    with {:ok, workers} <- fetch_workers(game, worker_ids),
         hunters = Enum.map(workers, &{&1, Enum.find(game.places, fn p -> p.id == &1.place end)}),
         :ok <- Hunting.check_start(hunters, game.books, game.config) do
      hunt_id = Place.next_id(game.places)
      places = Hunting.new_expedition(game.places, game.week, game.config)

      game = %{
        game
        | places: places,
          suspicion: Suspicion.add_expedition(game.suspicion, game.config)
      }

      {:ok,
       Enum.reduce(workers, game, fn worker, game ->
         Game.put_worker(game, %{worker | place: hunt_id, travel: 0, training_started: nil})
       end)}
    end
  end

  defp fetch_workers(game, worker_ids) do
    Enum.reduce_while(worker_ids, {:ok, []}, fn id, {:ok, workers} ->
      case Game.fetch_worker(game, id) do
        {:ok, worker} -> {:cont, {:ok, workers ++ [worker]}}
        error -> {:halt, error}
      end
    end)
  end
end
