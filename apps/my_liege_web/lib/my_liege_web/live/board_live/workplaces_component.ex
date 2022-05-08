defmodule MyLiege.BoardLive.WorkplacesComponent do
  use MyLiegeWeb, :live_component
  require Logger

  alias MyLiege.Game.Workplace

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(workplaces: get_workplaces())}
  end

  defp get_workplaces() do
    MyLiege.get_data() |> Map.get(:workplaces)
  end

  def render(assigns) do
    ~H"""
    <section class="my-2">
      <%= for {id, workplace} <- @workplaces do %>
        <div id={"workplace-#{id}"}>
          <%= workplace.type %>
          <.workplace_progress workplace={workplace} />
          <%= workplace.pawn %>
          <%= if Workplace.has_capacity?(workplace) do %>
            <button phx-click="add-pawn" phx-value-workplace={id} phx-target={@myself} class="btn btn-sm">+</button>
          <% else %>
            <button phx-click="remove-pawn" phx-value-workplace={id} phx-target={@myself} class="btn btn-sm">-</button>
          <% end %>
        </div>
      <% end %>
    </section>
    """
  end

  def handle_event("add-pawn", %{"workplace" => id}, socket) do
    MyLiege.add_pawn_to_workplace(String.to_integer(id))
    {:noreply, socket}
  end

  def handle_event("remove-pawn", %{"workplace" => id}, socket) do
    MyLiege.remove_pawn_from_workplace(String.to_integer(id))
    {:noreply, socket}
  end

  def workplace_progress(assigns) do
    ~H"""
    <div class="flex mb-2">
      <%= for {key, value} <- @workplace.input do %>
        <div class=""><%= key %>: <%= Map.get(@workplace.inventory, key) || 0 %>/<%= value %></div>
      <% end %>
    </div>
    """
  end
end
