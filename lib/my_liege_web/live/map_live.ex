defmodule MyLiegeWeb.MapLive do
  use MyLiegeWeb, :live_view

  def render(assigns) do
    ~H"""
    <div id="game" class="grid h-screen game-shell">
      <div id="timer" class="col-span-full min-h-0 overflow-hidden border">
        <svg class="block size-full" viewBox="0 0 2172 724" preserveAspectRatio="xMidYMid slice">
          <image href={~p"/images/seasons.png"} width="2172" height="724" />
          <image href={~p"/images/sun.png"} x="1000" y="305" width="60" height="60" />
        </svg>
      </div>
      <div id="left" class="border">left</div>
      <div id="map" class="min-h-0 min-w-0 overflow-hidden border">
        <svg class="block size-full" viewBox="0 0 1600 900" preserveAspectRatio="xMidYMid slice">
          <image href={~p"/images/landscape.png"} width="1600" height="900" />
        </svg>
      </div>
      <div id="right" class="border">right</div>
      <div id="footer" class="col-span-full border">footer</div>
    </div>
    """
  end
end
