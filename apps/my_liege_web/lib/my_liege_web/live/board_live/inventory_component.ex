defmodule MyLiege.BoardLive.InventoryComponent do
  use MyLiegeWeb, :live_component
  require Logger

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(inventory: get_inventory())}
  end

  defp get_inventory() do
    MyLiege.get_data() |> Map.get(:inventory) |> IO.inspect()
  end

  def render(assigns) do
    ~H"""
    <section class="my-2">
      <%= for {key, value} <- @inventory do %>
        <div id={"inventory-#{key}"}>
          <%= key %>
          <%= value %>
        </div>
      <% end %>
    </section>
    """
  end
end
