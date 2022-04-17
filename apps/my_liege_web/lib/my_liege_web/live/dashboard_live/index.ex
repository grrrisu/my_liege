defmodule MyLiegeWeb.DashboardLive.Index do
  use MyLiegeWeb, :live_view

  require Logger

  def mount(_params, _session, socket) do
    if connected?(socket), do: subscribe()
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <h1>My Liege</h1>
    """
  end

  defp subscribe() do
    Phoenix.PubSub.subscribe(MyLiege.PubSub, "Game")
  end
end
