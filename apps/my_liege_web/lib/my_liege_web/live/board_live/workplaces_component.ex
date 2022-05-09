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
    <section class="flex my-2 ">
      <%= for {id, workplace} <- @workplaces do %>
        <div id={"workplace-#{id}"} class="flex flex-col mr-4 p-2 border rounded">
          <div class="flex items-center">
            <i class="las la-home mr-1"></i>
            <%= workplace.type %>
          </div>
          <.workplace_progress workplace={workplace} />
          <div class="flex">
            <div class="mr-1"><%= workplace.pawn || 0 %></div>
            <%= if Workplace.has_capacity?(workplace) do %>
              <button phx-click="add-pawn" phx-value-workplace={id} phx-target={@myself} class="btn btn-sm">+</button>
            <% else %>
              <button phx-click="remove-pawn" phx-value-workplace={id} phx-target={@myself} class="btn btn-sm">-</button>
            <% end %>
          </div>
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
    <div class="flex flex-col mb-2">
      <%= for {key, value} <- @workplace.input do %>
        <div class=""><%= key %>:</div>
        <.progress_bar part={inventory_value(@workplace.inventory, key)} full={value} />
      <% end %>
    </div>
    """
  end

  defp inventory_value(inventory, key) do
    Map.get(inventory, key) || 0
  end

  def progress_bar(assigns) do
    width = round(assigns.part / assigns.full * 100)

    ~H"""
    <div class='bg-gray-300 w-full mb-4' style="height: 4px">
      <div class='bg-green-500 w-4/6 h-full' style={"width: #{width}%"}></div>
    </div>
    """
  end
end
