defmodule MyLiegeWeb.GameLive do
  @moduledoc "Bare play screen: game state, placing workers, building, and running the next week."
  use MyLiegeWeb, :live_view

  alias MyLiege.Engine.{Building, Config, Fixed, Game, Manameter}
  alias MyLiege.Engine.Rules.{Construction, Demands, Grace, Taxes, Training}
  alias MyLiege.Reporting

  @colour_classes %{
    green: "bg-green-600",
    blue: "bg-blue-600",
    red: "bg-red-600",
    yellow: "bg-yellow-400",
    violet: "bg-violet-600"
  }

  @impl true
  def mount(_params, _session, socket) do
    game = Game.new(Config.from_csv())

    {:ok,
     socket
     |> assign(:selected, nil)
     |> assign(:reports, [Game.report(game)])
     |> assign_game(game)}
  end

  @impl true
  def handle_event("next_week", _params, socket) do
    case Game.run_week(socket.assigns.game) do
      {:ok, report, game} ->
        {:noreply,
         socket
         |> clear_flash()
         |> put_week_info(socket.assigns.game, report)
         |> assign(:selected, nil)
         |> update(:reports, &[report | &1])
         |> assign_game(game)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_message(reason))}
    end
  end

  def handle_event("download_csv", _params, socket) do
    %{game: game, reports: reports} = socket.assigns

    {:noreply,
     push_event(socket, "download_csv", %{
       filename: "my_liege_seed_#{game.seed}_week_#{game.week}.csv",
       content: reports |> Enum.reverse() |> Reporting.to_csv()
     })}
  end

  def handle_event("select_worker", %{"id" => id}, socket) do
    id = parse_id(id)
    {:noreply, assign(socket, :selected, if(socket.assigns.selected == id, do: nil, else: id))}
  end

  def handle_event("place", %{"building" => building_id}, socket) do
    %{game: game, selected: worker_id} = socket.assigns
    result = Game.place_worker(game, worker_id, parse_id(building_id))
    {:noreply, apply_result(socket, result)}
  end

  def handle_event("unplace", _params, socket) do
    %{game: game, selected: worker_id} = socket.assigns
    result = Game.unplace_worker(game, worker_id)
    {:noreply, apply_result(socket, result)}
  end

  def handle_event("build", %{"type" => type}, socket) do
    type = Enum.find(Building.types(), &(Atom.to_string(&1) == type))
    result = Game.construct(socket.assigns.game, type)
    {:noreply, apply_result(socket, result)}
  end

  def handle_event("decide_tax", %{"pay" => pay}, socket) do
    result = Game.decide_tax(socket.assigns.game, pay == "true")
    {:noreply, apply_result(socket, result)}
  end

  def handle_event("decide_demand", %{"deliver" => deliver}, socket) do
    result = Game.decide_demand(socket.assigns.game, deliver == "true")
    {:noreply, apply_result(socket, result)}
  end

  def handle_event("refuse_project", _params, socket) do
    {:noreply, apply_result(socket, Game.refuse_project(socket.assigns.game))}
  end

  # ordering a building changes the current week's report (gold spent on buildings)
  defp apply_result(socket, {:ok, game}) do
    socket
    |> clear_flash()
    |> assign(:selected, nil)
    |> update(:reports, fn [_current | earlier] -> [Game.report(game) | earlier] end)
    |> assign_game(game)
  end

  defp apply_result(socket, {:error, reason}) do
    put_flash(socket, :error, error_message(reason))
  end

  # `before` is the game before the week ran: it still holds the amounts that were due
  defp put_week_info(socket, before, report) do
    messages =
      [
        report.tax == :missed &&
          "The tax of #{units(before.tax_due)} gold couldn't be paid: not enough gold.",
        report.demand_outcome == :missed &&
          "The king's demand for #{units(before.demand.amount)} #{before.demand.product} " <>
            "couldn't be delivered: #{missed_reason(before.demand)}.",
        report.tax_due &&
          "The village was counted: #{units(report.tax_due)} gold tax due in week " <>
            "#{Taxes.next_due_week(report.week, before.config)}.",
        king_took(report.king_took),
        report.demand &&
          "The king demands #{units(report.demand.amount)} #{report.demand.product} " <>
            "by week #{report.demand.due_week}."
      ]
      |> Enum.filter(& &1)

    if messages == [], do: socket, else: put_flash(socket, :info, Enum.join(messages, " "))
  end

  defp king_took(%{gold: 0, food: 0}), do: false

  defp king_took(%{gold: gold, food: food}) do
    taken =
      [gold > 0 && "#{units(gold)} gold", food > 0 && "#{units(food)} food"]
      |> Enum.filter(& &1)
      |> Enum.join(" and ")

    "The king took #{taken}."
  end

  defp missed_reason(demand) do
    if Demands.project?(demand),
      do: "the project didn't reach its target",
      else: "not enough #{demand.product}"
  end

  defp error_message(:no_project), do: "There is no open project to refuse."
  defp error_message(:full), do: "That building is full."
  defp error_message(:not_ready), do: "That building is not finished yet."
  defp error_message(:unknown_worker), do: "Select a worker first."
  defp error_message(:unknown_building), do: "Unknown building."
  defp error_message(:unknown_type), do: "Unknown building type."
  defp error_message(:not_enough_gold), do: "Not enough gold to build."
  defp error_message(:tax_undecided), do: "Decide whether to pay the tax first."
  defp error_message(:game_over), do: "The game is over."
  defp error_message(:finished), do: "The game has ended."
  defp error_message(:no_tax_due), do: "No tax payment is due next week."
  defp error_message(:demand_undecided), do: "Decide whether to deliver the king's demand first."
  defp error_message(:no_demand_due), do: "No demand is due next week."
  defp error_message(:already_trained), do: "That worker is already trained."
  defp error_message(:travelling), do: "That worker is still travelling."

  defp error_message(:below_threshold),
    do: "That worker's colour has too small a share of the Manameter to train."

  defp parse_id(id) do
    case Integer.parse(id) do
      {id, ""} -> id
      _ -> nil
    end
  end

  defp assign_game(socket, game) do
    decision_due? = Game.tax_decision_due?(game)
    demand_due? = Game.demand_decision_due?(game)

    socket
    |> assign(:game, game)
    |> assign(:report, Game.report(game))
    |> assign(:tax_decision_due?, decision_due?)
    |> assign(:demand_decision_due?, demand_due?)
    |> assign(:project_refusable?, Game.project_refusable?(game))
    |> assign(:won?, Game.won?(game))
    |> assign(
      :blocked?,
      game.game_over or game.week >= Game.last_week(game) or
        (decision_due? and is_nil(game.pay_tax)) or
        (demand_due? and is_nil(game.deliver_demand))
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-8">
        <div>
          <h1 id="week" class="text-2xl font-semibold">Week {@game.week}</h1>
          <p id="seed" class="text-sm opacity-60">Seed {@game.seed}</p>
        </div>

        <p
          :if={@won?}
          id="congratulations"
          class="rounded bg-green-100 px-4 py-3 font-semibold text-green-900"
        >
          Congratulations, my liege! Your village has lasted {@game.config.years_per_game} years.
        </p>

        <div class="grid gap-10 lg:grid-cols-2">
          <div id="column-village" class="space-y-8">
            <.village game={@game} selected={@selected} blocked?={@blocked?} />
            <.build_buttons game={@game} />
          </div>

          <div id="column-state" class="space-y-8">
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

            <section id="taxes">
              <h2 class="mb-2 font-semibold">Taxes</h2>
              <p
                :if={Grace.in_grace?(@game.week + 1, @game.config)}
                id="grace-period"
                class="mb-2 text-sm font-semibold text-green-700"
              >
                Grace period: no taxes and no demands until the end of week {Grace.last_week(
                  @game.config
                )}.
              </p>
              <p :if={@game.game_over} id="game-over" class="mb-2 font-semibold text-red-600">
                Game over: too many missed payments and demands.
              </p>
              <div :if={@game.tax_due} id="tax-due" class="flex items-center gap-3 text-sm">
                <span class="tabular-nums">
                  {units(@game.tax_due)} gold due in week {Taxes.next_due_week(
                    @game.week,
                    @game.config
                  )}
                </span>
                <span :if={@tax_decision_due?} id="tax-decision" class="flex items-center gap-2">
                  <button
                    id="pay-tax"
                    phx-click="decide_tax"
                    phx-value-pay="true"
                    class={[
                      "rounded border px-2 py-0.5 text-sm hover:bg-zinc-100",
                      @game.pay_tax == true && "bg-zinc-900 text-white hover:bg-zinc-700"
                    ]}
                  >
                    Pay
                  </button>
                  <button
                    id="skip-tax"
                    phx-click="decide_tax"
                    phx-value-pay="false"
                    class={[
                      "rounded border px-2 py-0.5 text-sm hover:bg-zinc-100",
                      @game.pay_tax == false && "bg-zinc-900 text-white hover:bg-zinc-700"
                    ]}
                  >
                    Skip
                  </button>
                  <span :if={is_nil(@game.pay_tax)} class="font-semibold text-red-600">
                    decide before the next week
                  </span>
                </span>
              </div>
              <p :if={!@game.tax_due} class="text-sm opacity-60">
                Next count in week {Taxes.next_due_week(@game.week, @game.config) -
                  @game.config.tax_count_lead_weeks}
              </p>
              <p id="tax-misses" class="text-sm tabular-nums">
                Missed payments and demands: {@game.misses} (forgiven: {@game.config.tax_misses_forgiven})
              </p>
            </section>

            <section id="demands">
              <h2 class="mb-2 font-semibold">The king's demands</h2>
              <div
                :if={Demands.project?(@game.demand)}
                id="project"
                class="flex flex-wrap items-center gap-3 text-sm"
              >
                <span class="tabular-nums">
                  Project: {units(@game.demand.progress)}/{units(@game.demand.amount)} {@game.demand.product} by week {@game.demand.due_week}
                </span>
                <span
                  :if={@game.demand.progress >= @game.demand.amount}
                  id="project-reached"
                  class="font-semibold text-green-700"
                >
                  target reached
                </span>
                <button
                  :if={@project_refusable?}
                  id="refuse-project"
                  phx-click="refuse_project"
                  class="rounded border px-2 py-0.5 text-sm hover:bg-zinc-100"
                >
                  Refuse
                </button>
                <span
                  :if={@game.deliver_demand == false}
                  id="project-refused"
                  class="font-semibold text-red-600"
                >
                  refused: counts as a miss next week
                </span>
              </div>
              <div
                :if={@game.demand && !Demands.project?(@game.demand)}
                id="demand"
                class="flex items-center gap-3 text-sm"
              >
                <span class="tabular-nums">
                  {units(@game.demand.amount)} {@game.demand.product} due in week {@game.demand.due_week}
                </span>
                <span :if={@demand_decision_due?} id="demand-decision" class="flex items-center gap-2">
                  <button
                    id="deliver-demand"
                    phx-click="decide_demand"
                    phx-value-deliver="true"
                    class={[
                      "rounded border px-2 py-0.5 text-sm hover:bg-zinc-100",
                      @game.deliver_demand == true && "bg-zinc-900 text-white hover:bg-zinc-700"
                    ]}
                  >
                    Deliver
                  </button>
                  <button
                    id="refuse-demand"
                    phx-click="decide_demand"
                    phx-value-deliver="false"
                    class={[
                      "rounded border px-2 py-0.5 text-sm hover:bg-zinc-100",
                      @game.deliver_demand == false && "bg-zinc-900 text-white hover:bg-zinc-700"
                    ]}
                  >
                    Refuse
                  </button>
                  <span :if={is_nil(@game.deliver_demand)} class="font-semibold text-red-600">
                    decide before the next week
                  </span>
                </span>
              </div>
              <p :if={!@game.demand} class="text-sm opacity-60">No open demand.</p>
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
                    <span
                      :for={colour <- Manameter.colours()}
                      class="mr-3 inline-flex items-center gap-1"
                    >
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
                <tr :if={@report.tax_due} id="tax-counted">
                  <td class="pr-4">tax counted</td>
                  <td>{units(@report.tax_due)} gold</td>
                </tr>
                <tr :if={@report.tax} id="tax-outcome">
                  <td class="pr-4">tax</td>
                  <td class={[@report.tax != :paid && "font-semibold text-red-600"]}>
                    {@report.tax}
                  </td>
                </tr>
                <tr :if={@report.demand} id="demand-made">
                  <td class="pr-4">king demands</td>
                  <td>{units(@report.demand.amount)} {@report.demand.product}</td>
                </tr>
                <tr :if={@report.demand_outcome} id="demand-outcome">
                  <td class="pr-4">demand</td>
                  <td class={[@report.demand_outcome != :delivered && "font-semibold text-red-600"]}>
                    {@report.demand_outcome}
                  </td>
                </tr>
              </table>
            </section>

            <button
              id="download-csv"
              phx-click="download_csv"
              phx-hook=".DownloadCsv"
              class="rounded border px-4 py-2 text-sm hover:bg-zinc-100"
            >
              Download CSV report
            </button>
          </div>
        </div>
        <script :type={Phoenix.LiveView.ColocatedHook} name=".DownloadCsv">
          export default {
            mounted() {
              this.handleEvent("download_csv", ({filename, content}) => {
                const url = URL.createObjectURL(new Blob([content], {type: "text/csv"}))
                const link = document.createElement("a")
                link.href = url
                link.download = filename
                link.click()
                URL.revokeObjectURL(url)
              })
            }
          }
        </script>
      </div>
    </Layouts.app>
    """
  end

  attr :game, Game, required: true
  attr :selected, :integer, default: nil
  attr :blocked?, :boolean, required: true

  defp village(assigns) do
    ~H"""
    <section id="buildings">
      <h2 class="mb-2 font-semibold">Buildings and workers</h2>
      <p class="mb-2 text-sm opacity-60">
        Click a worker to select it, then place it in a building.
      </p>
      <div class="space-y-2">
        <div
          :for={building <- @game.buildings}
          id={"building-#{building.id}"}
          class="flex flex-wrap items-center gap-3"
        >
          <div class={["h-4 w-4 rounded-sm", colour_class(Building.colour(building))]}></div>
          <span class="w-24 text-sm">
            {building.type}<span :if={Building.site?(building)} class="opacity-60"> site</span>
          </span>
          <span class="w-10 text-sm tabular-nums">
            {length(workers_in(@game.workers, building.id))}/{Building.capacity(
              building,
              @game.config
            )}
          </span>
          <.worker
            :for={worker <- workers_in(@game.workers, building.id)}
            worker={worker}
            selected={@selected == worker.id}
          />
          <span
            :if={feeds_project?(@game, building)}
            id={"feeds-project-#{building.id}"}
            class="rounded bg-amber-100 px-1.5 text-xs text-amber-900"
            title="this building's production goes into the king's project"
          >
            → project
          </span>
          <span
            :if={Building.site?(building)}
            id={"site-#{building.id}"}
            class="text-sm tabular-nums opacity-60"
          >
            builders arrived {length(Construction.arrived(@game.workers, building.id))}/{@game.config.builders_per_building},
            progress {building.progress}/{@game.config.construction_weeks} weeks
          </span>
          <span
            :for={worker <- workers_in(@game.workers, building.id)}
            :if={worker.training_started}
            id={"training-#{worker.id}"}
            class="text-sm opacity-60"
          >
            trained after week {Training.last_week(worker.training_started, @game.config)}
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
        <div id="unplaced" class="flex flex-wrap items-center gap-3">
          <div class="h-4 w-4"></div>
          <span class="w-24 text-sm">unplaced</span>
          <span class="w-10 text-sm tabular-nums">{length(workers_in(@game.workers, nil))}</span>
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
      <button
        id="next-week"
        phx-click="next_week"
        disabled={@blocked?}
        class="mt-4 rounded bg-zinc-900 px-4 py-2 text-white hover:bg-zinc-700 disabled:opacity-40"
      >
        Next week
      </button>
    </section>
    """
  end

  attr :game, Game, required: true

  defp build_buttons(assigns) do
    assigns = assign(assigns, :affordable?, Game.can_afford_building?(assigns.game))

    ~H"""
    <section id="build">
      <h2 class="mb-2 font-semibold">Build</h2>
      <p id="build-cost" class="mb-2 text-sm opacity-60">
        Every building costs {units(Game.build_cost(@game))} gold.
      </p>
      <div class="flex flex-wrap gap-2">
        <button
          :for={type <- Building.types()}
          id={"build-#{type}"}
          phx-click="build"
          phx-value-type={type}
          disabled={!@affordable?}
          class="inline-flex items-center gap-2 rounded border px-2 py-1 text-sm hover:bg-zinc-100 disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-transparent"
        >
          <span class={["inline-block h-3 w-3 rounded-sm", colour_class(type_colour(type))]}></span>
          {type}
        </button>
      </div>
    </section>
    """
  end

  attr :worker, :map, required: true
  attr :selected, :boolean, default: false

  defp worker(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-0.5">
      <button
        id={"worker-#{@worker.id}"}
        phx-click="select_worker"
        phx-value-id={@worker.id}
        class={[
          "inline-block h-5 w-5 rounded-sm transition hover:scale-110",
          colour_class(@worker.colour),
          @worker.trained && "ring-2 ring-zinc-900",
          @worker.travel > 0 && "opacity-40",
          @selected && "outline-3 outline-offset-2 outline-zinc-900"
        ]}
        title={worker_title(@worker)}
      ></button>
      <span
        :if={@worker.travel > 0}
        id={"travel-#{@worker.id}"}
        class="text-xs tabular-nums opacity-60"
        title="weeks of travel left"
      >
        ↦{@worker.travel}
      </span>
    </span>
    """
  end

  defp worker_title(worker) do
    [
      to_string(worker.colour),
      worker.trained && "trained",
      worker.travel > 0 && "travelling #{worker.travel} more week(s)"
    ]
    |> Enum.filter(& &1)
    |> Enum.join(", ")
  end

  # the next week's production of this building goes into the open project
  defp feeds_project?(game, building) do
    project = game.demand

    Demands.project?(project) and game.deliver_demand != false and
      project.progress < project.amount and not Building.neutral?(building) and
      not Building.site?(building) and
      Building.product(building) == project.product
  end

  defp type_colour(type), do: Building.colour(%Building{id: 0, type: type})

  defp workers_in(workers, building_id), do: Enum.filter(workers, &(&1.building == building_id))

  defp colour_class(nil), do: "bg-zinc-400"
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
