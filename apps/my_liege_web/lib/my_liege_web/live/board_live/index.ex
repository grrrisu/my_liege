defmodule MyLiegeWeb.BoardLive.Index do
  use MyLiegeWeb, :live_view

  require Logger

  alias MyLiege.BoardLive.WorkplacesComponent

  def mount(_params, _session, socket) do
    if connected?(socket), do: subscribe()
    {:ok, socket}
  end

  def handle_params(params, session, socket) do
    {:noreply, handle_action(socket.assigns.live_action, params, session, socket)}
  end

  def handle_action(:index, _params, _session, socket) do
    case MyLiege.board_exists?() do
      false ->
        socket
        |> put_flash(:error, "no board created or loaded")
        |> redirect(to: "/")

      _ ->
        assign(socket,
          started: MyLiege.started?(),
          pawn_pool: get_pawn_pool()
        )
    end
  end

  def render(assigns) do
    ~H"""
    <h1>My Liege - Board</h1>
    <.start_button started={@started}></.start_button>
    <.live_component module={WorkplacesComponent} id="workplaces"></.live_component>
    <div><%= @pawn_pool.normal %></div>
    <div>
      <%= live_redirect("Back to Dashboard", to: Routes.dashboard_index_path(@socket, :index)) %>
    </div>
    """
  end

  def start_button(assigns) do
    label = if assigns.started, do: "stop", else: "start"

    ~H"""
    <button phx-click="run-sim" phx-value-running={"#{@started}"} class="btn"><%= label %></button>
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

  def handle_info({action, _}, socket)
      when action in [:pawn_added_to_workplace, :pawn_removed_from_workplace] do
    Logger.info(action)
    send_update(WorkplacesComponent, id: "workplaces")
    {:noreply, socket}
  end

  def handle_info({action, _}, socket)
      when action in [:pawn_added_to_pool, :pawn_removed_from_pool] do
    Logger.info(action)
    {:noreply, assign(socket, pawn_pool: get_pawn_pool())}
  end

  def handle_info({:error, message}, socket) do
    {:noreply,
     socket
     |> clear_flash(:info)
     |> put_flash(:error, message)}
  end

  defp get_pawn_pool() do
    MyLiege.get_data() |> Map.get(:pawn_pool)
  end

  defp subscribe() do
    Phoenix.PubSub.subscribe(MyLiege.PubSub, "Game")
  end
end
