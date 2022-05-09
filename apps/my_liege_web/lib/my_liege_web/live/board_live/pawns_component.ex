defmodule MyLiege.BoardLive.PawnsComponent do
  use MyLiegeWeb, :live_component
  require Logger

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(get_pawns())}
  end

  defp get_pawns() do
    data = MyLiege.get_data()
    %{pawn_pool: Map.get(data, :pawn_pool), poverty: Map.get(data, :poverty)}
  end

  def render(assigns) do
    ~H"""
    <section class="border rounded p-2 my-2">
        <div id={"pawn-pool"}>
          Pawns: <%= Map.get(@pawn_pool, :normal) %>
        </div>
        <div id={"poverty"}>
          Poverty: <%= Map.get(@poverty, :normal) %>
        </div>
    </section>
    """
  end
end
