defmodule MyLiege.Bot.BotActions.PlaceOwn do
  @moduledoc """
  Unplaced workers go to their own colour's home building type. A placing action
  (`MyLiege.Bot.Placing`); as the last one in a strategy it takes the rest.
  """

  @behaviour MyLiege.Bot.BotAction
  @behaviour MyLiege.Bot.Placing

  alias MyLiege.Bot.Placing
  alias MyLiege.Engine.Game
  alias MyLiege.Engine.Place.Blueprint

  @impl MyLiege.Bot.BotAction
  def run(%Game{} = game, opts),
    do: Placing.run(game, Keyword.put(opts, :rules, [{__MODULE__, opts}]))

  @impl MyLiege.Bot.Placing
  def target(worker, _game, _opts), do: Blueprint.home_type(worker.colour)
end
