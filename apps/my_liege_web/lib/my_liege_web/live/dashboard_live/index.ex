defmodule MyLiegeWeb.DashboardLive.Index do
  use MyLiegeWeb, :live_view

  require Logger

  def mount(_params, _session, socket) do
    if connected?(socket), do: subscribe()
    {:ok, socket}
  end

  def handle_params(params, session, socket) do
    {:noreply, handle_action(socket.assigns.live_action, params, session, socket)}
  end

  def handle_action(:index, _params, _session, socket) do
    assign(socket, board_exists: MyLiege.board_exists?())
  end

  def handle_action(:create, %{"name" => name}, _session, socket) do
    :ok = MyLiege.create(name)

    socket
    |> put_flash(:info, "creating level #{name} ...")
    |> assign(board_exists: false)
  end

  def render(assigns) do
    ~H"""
    <h1>My Liege</h1>
    <section>
      <ul>
        <%= if @board_exists do %>
          <li id="link-current-board" class="mb-4"><%= live_redirect("Current Board", to: Routes.board_index_path(@socket, :index)) %></li>
        <% end %>
        <li id="link-create-one" class="mb-4"><%= live_patch("Create One", to: Routes.dashboard_index_path(@socket, :create, name: "one"), class: "btn btn-lg") %></li>
        <li id="link-create-one" class="mb-4"><%= live_patch("Create Test", to: Routes.dashboard_index_path(@socket, :create, name: "test"), class: "btn btn-lg") %></li>
        <li id="link-create-one" class="mb-4"><%= live_patch("Create Foobar", to: Routes.dashboard_index_path(@socket, :create, name: "foobar"), class: "btn btn-lg") %></li>
      </ul>
    </section>
    """
  end

  def handle_info({:game_created, name: name}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "level #{name} created")
     |> push_redirect(to: Routes.board_index_path(socket, :index), replace: true)}
  end

  def handle_info({:sim_started, started: started}, socket) do
    Logger.info("sim started #{started}")

    {:noreply,
     socket
     |> clear_flash(:info)
     |> put_flash(:info, if(started, do: "sim started", else: "sim stopped"))}
  end

  def handle_info({:error, message}, socket) do
    {:noreply,
     socket
     |> clear_flash(:error)
     |> put_flash(:error, message)}
  end

  def handle_info(unknown, socket) do
    Logger.debug("dashboard: unhandled message #{inspect(unknown)}")
    {:noreply, socket}
  end

  defp subscribe() do
    Phoenix.PubSub.subscribe(MyLiege.PubSub, "Game")
  end
end
