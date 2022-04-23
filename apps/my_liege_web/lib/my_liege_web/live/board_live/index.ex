defmodule MyLiegeWeb.BoardLive.Index do
  use MyLiegeWeb, :live_view

  require Logger

  def mount(_params, _session, socket) do
    if connected?(socket), do: subscribe()
    {:ok, assign(socket, started: MyLiege.started?())}
  end

  def render(assigns) do
    ~H"""
    <h1>My Liege - Board</h1>
    <.start_button started={@started}></.start_button>
    """
  end

  def start_button(assigns) do
    label = if assigns.started, do: "stop", else: "start"

    ~H"""
    <button phx-click="run-sim" phx-value-running={"#{@started}"}><%= label %></button>
    """
  end

  def handle_event("run-sim", %{"running" => "true"}, socket) do
    Logger.info("event stop sim")
    MyLiege.stop_sim()
    {:noreply, socket}
  end

  def handle_event("run-sim", %{"running" => "false"}, socket) do
    Logger.info("event start sim")
    MyLiege.start_sim()
    {:noreply, socket}
  end

  def handle_info({:sim_started, started: started}, socket) do
    Logger.info("sim started #{started}")

    {:noreply,
     socket
     |> assign(started: started)
     |> clear_flash(:info)
     |> put_flash(:info, if(started, do: "sim started", else: "sim stopped"))}
  end

  def handle_info({:workplaces_produced, :time_unit}, socket) do
    Logger.info("workplaces_produced")
    {:noreply, socket}
  end

  def handle_info({:inventory_updated, input: _input}, socket) do
    Logger.info("inventory_updated")
    {:noreply, socket}
  end

  def handle_info({:error, message}, socket) do
    {:noreply,
     socket
     |> clear_flash(:info)
     |> put_flash(:error, message)}
  end

  defp subscribe() do
    Phoenix.PubSub.subscribe(MyLiege.PubSub, "Game")
  end
end
