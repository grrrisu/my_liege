defmodule MyLiege.BoardLive.WorkplacesComponent do
  use MyLiegeWeb, :live_component
  require Logger

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(workplaces: get_workplaces())}
  end

  defp get_workplaces() do
    MyLiege.get_data() |> Map.get(:workplaces) |> IO.inspect()
  end

  def render(assigns) do
    ~H"""
    <section>
      <%= for {id, workplace} <- @workplaces do %>
        <div id={"workplace-#{id}"}>
          <%= workplace.type %>
          <%= workplace.pawn %>
          <button phx-click="add-pawn" phx-value-workplace={id} phx-target={@myself} class="btn">+</button>
          <button phx-click="remove-pawn" phx-value-workplace={id} phx-target={@myself} class="btn">-</button>
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
end
