defmodule MyLiegeWeb.GameLive do
  @moduledoc "Bare play screen: the current game state and a button to run the next week."
  use MyLiegeWeb, :live_view

  alias MyLiege.Engine.{Building, Config, Fixed, Game, Manameter}

  @colour_classes %{
    green: "bg-green-600",
    blue: "bg-blue-600",
    red: "bg-red-600",
    yellow: "bg-yellow-400",
    violet: "bg-violet-600"
  }

  @impl true
  def mount(_params, _session, socket) do
    config = Config.from_csv()
    {:ok, socket |> assign(:config, config) |> assign_game(Game.new(config))}
  end

  @impl true
  def handle_event("next_week", _params, socket) do
    {_report, game} = Game.run_week(socket.assigns.game, socket.assigns.config)
    {:noreply, assign_game(socket, game)}
  end

  defp assign_game(socket, game) do
    socket
    |> assign(:game, game)
    |> assign(:report, Game.report(game))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 id="week" class="text-2xl font-semibold">Week {@game.week}</h1>
            <p id="seed" class="text-sm opacity-60">Seed {@game.seed}</p>
          </div>
          <button
            id="next-week"
            phx-click="next_week"
            class="rounded bg-zinc-900 px-4 py-2 text-white hover:bg-zinc-700"
          >
            Next week
          </button>
        </div>

        <section id="manameter">
          <h2 class="mb-2 font-semibold">Manameter</h2>
          <div class="flex gap-4">
            <div :for={colour <- Manameter.colours()} id={"share-#{colour}"} class="text-center">
              <div class={["mx-auto h-8 w-8 rounded", colour_class(colour)]}></div>
              <div class="mt-1 text-sm tabular-nums">
                {per_mille(Map.fetch!(@game.manameter, colour))}
              </div>
            </div>
          </div>
        </section>

        <section id="stocks">
          <h2 class="mb-2 font-semibold">Stocks</h2>
          <table class="text-sm tabular-nums">
            <tr :for={product <- Building.products()} id={"stock-#{product}"}>
              <td class="pr-4">{product}</td>
              <td class="text-right">{units(Map.fetch!(@game.stocks, product))}</td>
            </tr>
          </table>
        </section>

        <section id="buildings">
          <h2 class="mb-2 font-semibold">Buildings and workers</h2>
          <div class="space-y-2">
            <div
              :for={building <- @game.buildings}
              id={"building-#{building.id}"}
              class="flex items-center gap-3"
            >
              <div class={["h-4 w-4 rounded-sm", colour_class(Building.colour(building))]}></div>
              <span class="w-28 text-sm">{building.type}</span>
              <span class="w-12 text-sm tabular-nums">
                {length(workers_in(@game.workers, building.id))}/{Map.fetch!(
                  @config.capacity,
                  building.type
                )}
              </span>
              <.worker :for={worker <- workers_in(@game.workers, building.id)} worker={worker} />
            </div>
            <div id="unplaced" class="flex items-center gap-3">
              <div class="h-4 w-4"></div>
              <span class="w-28 text-sm">unplaced</span>
              <span class="w-12 text-sm tabular-nums">{length(workers_in(@game.workers, nil))}</span>
              <.worker :for={worker <- workers_in(@game.workers, nil)} worker={worker} />
            </div>
          </div>
        </section>

        <section id="last-week">
          <h2 class="mb-2 font-semibold">Week {@report.week}</h2>
          <table class="text-sm tabular-nums">
            <tr>
              <td class="pr-4">production</td>
              <td>
                <span :for={product <- Building.products()} class="mr-3">
                  {product} {units(Map.fetch!(@report.production, product))}
                </span>
              </td>
            </tr>
            <tr>
              <td class="pr-4">mana</td>
              <td>
                <span :for={colour <- Manameter.colours()} class="mr-3 inline-flex items-center gap-1">
                  <span class={["inline-block h-3 w-3 rounded-sm", colour_class(colour)]}></span>
                  {Map.fetch!(@report.mana, colour)}
                </span>
              </td>
            </tr>
            <tr id="food-left">
              <td class="pr-4">food left</td>
              <td>
                {units(@report.food_left)}
                <span :if={@report.food_left < 0} class="ml-2 font-semibold text-red-600">short</span>
              </td>
            </tr>
            <tr id="newborn">
              <td class="pr-4">newborn</td>
              <td>
                <.worker :if={@report.newborn} worker={@report.newborn} />
                <span :if={!@report.newborn}>none</span>
              </td>
            </tr>
          </table>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :worker, :map, required: true

  defp worker(assigns) do
    ~H"""
    <span
      class={[
        "inline-block h-5 w-5 rounded-sm",
        colour_class(@worker.colour),
        @worker.trained && "ring-2 ring-zinc-900"
      ]}
      title={"#{@worker.colour}#{if @worker.trained, do: ", trained"}"}
    ></span>
    """
  end

  defp workers_in(workers, building_id), do: Enum.filter(workers, &(&1.building == building_id))

  defp colour_class(colour), do: Map.fetch!(@colour_classes, colour)

  defp per_mille(share), do: "#{div(share, 10)}.#{rem(share, 10)}%"

  defp units(amount) do
    if rem(amount, Fixed.scale()) == 0 do
      Integer.to_string(div(amount, Fixed.scale()))
    else
      :erlang.float_to_binary(amount / Fixed.scale(), [:compact, decimals: 3])
    end
  end
end
