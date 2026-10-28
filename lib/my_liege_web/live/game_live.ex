defmodule MyLiegeWeb.GameLive do
  @moduledoc "Bare play screen: game state, placing workers, building, and running the next week."
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

    {:ok,
     socket
     |> assign(:config, config)
     |> assign(:selected, nil)
     |> assign_game(Game.new(config))}
  end

  @impl true
  def handle_event("next_week", _params, socket) do
    {_report, game} = Game.run_week(socket.assigns.game, socket.assigns.config)
    {:noreply, socket |> assign(:selected, nil) |> assign_game(game)}
  end

  def handle_event("select_worker", %{"id" => id}, socket) do
    id = parse_id(id)
    {:noreply, assign(socket, :selected, if(socket.assigns.selected == id, do: nil, else: id))}
  end

  def handle_event("place", %{"building" => building_id}, socket) do
    %{game: game, selected: worker_id, config: config} = socket.assigns
    result = Game.place_worker(game, worker_id, parse_id(building_id), config)
    {:noreply, apply_result(socket, result)}
  end

  def handle_event("unplace", _params, socket) do
    result = Game.unplace_worker(socket.assigns.game, socket.assigns.selected)
    {:noreply, apply_result(socket, result)}
  end

  def handle_event("build", %{"type" => type}, socket) do
    type = Enum.find(Building.types(), &(Atom.to_string(&1) == type))
    result = Game.construct(socket.assigns.game, type, socket.assigns.config)
    {:noreply, apply_result(socket, result)}
  end

  defp apply_result(socket, {:ok, game}) do
    socket |> clear_flash() |> assign(:selected, nil) |> assign_game(game)
  end

  defp apply_result(socket, {:error, reason}) do
    put_flash(socket, :error, error_message(reason))
  end

  defp error_message(:full), do: "That building is full."
  defp error_message(:not_ready), do: "That building is not finished yet."
  defp error_message(:unknown_worker), do: "Select a worker first."
  defp error_message(:unknown_building), do: "Unknown building."
  defp error_message(:unknown_type), do: "Unknown building type."

  defp parse_id(id) do
    case Integer.parse(id) do
      {id, ""} -> id
      _ -> nil
    end
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
          <p class="mb-2 text-sm opacity-60">
            Click a worker to select it, then place it in a building.
          </p>
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
              <.worker
                :for={worker <- workers_in(@game.workers, building.id)}
                worker={worker}
                selected={@selected == worker.id}
              />
              <span
                :if={!Building.ready?(building, @game.week + 1)}
                class="text-sm opacity-60"
              >
                ready in week {building.ready_week}
              </span>
              <button
                :if={@selected}
                id={"place-#{building.id}"}
                phx-click="place"
                phx-value-building={building.id}
                class="rounded border px-2 py-0.5 text-sm hover:bg-zinc-100"
              >
                Place here
              </button>
            </div>
            <div id="unplaced" class="flex items-center gap-3">
              <div class="h-4 w-4"></div>
              <span class="w-28 text-sm">unplaced</span>
              <span class="w-12 text-sm tabular-nums">{length(workers_in(@game.workers, nil))}</span>
              <.worker
                :for={worker <- workers_in(@game.workers, nil)}
                worker={worker}
                selected={@selected == worker.id}
              />
              <button
                :if={@selected}
                id="unplace"
                phx-click="unplace"
                class="rounded border px-2 py-0.5 text-sm hover:bg-zinc-100"
              >
                Take out
              </button>
            </div>
          </div>
        </section>

        <section id="build">
          <h2 class="mb-2 font-semibold">Build</h2>
          <div class="flex gap-2">
            <button
              :for={type <- Building.types()}
              id={"build-#{type}"}
              phx-click="build"
              phx-value-type={type}
              class="inline-flex items-center gap-2 rounded border px-2 py-1 text-sm hover:bg-zinc-100"
            >
              <span class={["inline-block h-3 w-3 rounded-sm", colour_class(type_colour(type))]}></span>
              {type}
            </button>
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
                <span
                  :if={@report.newborn}
                  class={["inline-block h-5 w-5 rounded-sm", colour_class(@report.newborn.colour)]}
                  title={@report.newborn.colour}
                ></span>
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
  attr :selected, :boolean, default: false

  defp worker(assigns) do
    ~H"""
    <button
      id={"worker-#{@worker.id}"}
      phx-click="select_worker"
      phx-value-id={@worker.id}
      class={[
        "inline-block h-5 w-5 rounded-sm transition hover:scale-110",
        colour_class(@worker.colour),
        @worker.trained && "ring-2 ring-zinc-900",
        @selected && "outline-3 outline-offset-2 outline-zinc-900"
      ]}
      title={"#{@worker.colour}#{if @worker.trained, do: ", trained"}"}
    ></button>
    """
  end

  defp type_colour(type), do: Building.colour(%Building{id: 0, type: type})

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
