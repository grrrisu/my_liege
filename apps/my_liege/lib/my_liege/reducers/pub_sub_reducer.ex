defmodule MyLiege.PubSubReducer do
  require Logger

  def reduce(events) do
    Enum.map(events, fn event ->
      Logger.info("publish event: #{inspect(event)}")
      Phoenix.PubSub.broadcast(MyLiege.PubSub, "Game", event)
    end)
  end
end
