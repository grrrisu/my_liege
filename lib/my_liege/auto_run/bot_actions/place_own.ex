defmodule MyLiege.AutoRun.BotActions.PlaceOwn do
  @moduledoc """
  Unplaced workers go to their own colour's home building type. A placing action
  (`MyLiege.AutoRun.Placing`); as the last one in a strategy it takes the rest.
  """

  @behaviour MyLiege.AutoRun.BotAction
  @behaviour MyLiege.AutoRun.Placing

  alias MyLiege.AutoRun.Placing
  alias MyLiege.Engine.Game
  alias MyLiege.Engine.Place.Blueprint

  @impl MyLiege.AutoRun.BotAction
  def run(%Game{} = game, opts),
    do: Placing.run(game, Keyword.put(opts, :rules, [{__MODULE__, opts}]))

  @impl MyLiege.AutoRun.Placing
  def target(worker, _game, _opts), do: Blueprint.home_type(worker.colour)
end
