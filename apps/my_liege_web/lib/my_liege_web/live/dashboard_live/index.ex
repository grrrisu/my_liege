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
    socket
  end

  def handle_action(:create, %{"name" => name}, _session, socket) do
    :ok = MyLiege.create(name)
    put_flash(socket, :info, "creating level #{name} ...")
  end

  def render(assigns) do
    ~H"""
    <h1>My Liege</h1>
    <section>
      <ul>
        <li id="link-create-one"><%= live_patch("Create One", to: Routes.dashboard_index_path(@socket, :create, name: "one")) %></li>
      </ul>
    </section>
    """
  end

  def handle_info({:game_created, name: name}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "level #{name} created")
     |> push_redirect(to: Routes.board_index_path(socket, :index))}
  end

  defp subscribe() do
    Phoenix.PubSub.subscribe(MyLiege.PubSub, "Game")
  end
end
