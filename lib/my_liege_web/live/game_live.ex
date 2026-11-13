defmodule MyLiegeWeb.GameLive do
  @moduledoc "Bare play screen: game state, placing workers, building, and running the next week."
  use MyLiegeWeb, :live_view

  alias MyLiege.Engine.{Config, Fixed, Forecast, Game, Pentagon, Place}
  alias MyLiege.Engine.Place.{Blueprint, Project}
  alias MyLiege.Engine.Rules.{Bandits, Construction, Demands, Grace, Placement, Taxes, Training}
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

  def handle_event("place", %{"building" => place_id}, socket) do
    %{game: game, selected: worker_id} = socket.assigns
    result = Game.place_worker(game, worker_id, parse_id(place_id))
    {:noreply, apply_result(socket, result)}
  end

  def handle_event("unplace", _params, socket) do
    %{game: game, selected: worker_id} = socket.assigns
    result = Game.unplace_worker(game, worker_id)
    {:noreply, apply_result(socket, result)}
  end

  def handle_event("build", %{"type" => type}, socket) do
    type = Enum.find(Blueprint.types(), &(Atom.to_string(&1) == type))
    result = Game.construct(socket.assigns.game, type)
    {:noreply, apply_result(socket, result)}
  end

  def handle_event("start_book", %{"colour" => colour}, socket) do
    colour = Enum.find(Pentagon.colours(), &(Atom.to_string(&1) == colour))
    {:noreply, apply_result(socket, Game.start_book(socket.assigns.game, colour))}
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
        bandits_message(before, report),
        report.demand &&
          "The king demands #{units(report.demand.amount)} #{report.demand.product} " <>
            "by week #{report.demand.due_week}."
      ]
      |> Enum.filter(& &1)

    if messages == [], do: socket, else: put_flash(socket, :info, Enum.join(messages, " "))
  end

  defp bandits_message(_before, %{bandit_raid: :robbed} = report),
    do: "Bandits raided the village and took #{units(report.gold_robbed)} gold."

  defp bandits_message(_before, %{bandit_raid: :repelled}),
    do: "Bandits raided the village but were repelled: nothing was lost."

  defp bandits_message(before, report) do
    report.bandits_weeks_to_raid && not Bandits.on_their_way?(before.bandits) &&
      "Bandits have set out: they raid in week #{report.week + report.bandits_weeks_to_raid}."
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
  defp error_message(:unknown_worker), do: "Select a worker first."
  defp error_message(:unknown_place), do: "Unknown place."
  defp error_message(:unknown_type), do: "Unknown building type."
  defp error_message(:unknown_colour), do: "Unknown colour."
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
    |> assign(:forecast, %{
      food: Forecast.food(game),
      gold: Forecast.gold(game),
      tax: Forecast.next_tax(game),
      demand: Forecast.demand(game),
      bandits: Forecast.bandits(game)
    })
    |> assign(:tax_decision_due?, decision_due?)
    |> assign(:demand_decision_due?, demand_due?)
    |> assign(:project_refusable?, Game.project_refusable?(game))
    |> assign(:project, Demands.project(game.demand, game.places))
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
          Congratulations, my liege! Your village has lasted {@game.config.game_years} years.
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
                <div :for={colour <- Pentagon.colours()} id={"share-#{colour}"} class="text-center">
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
                <tr :for={product <- Blueprint.goods()} id={"stock-#{product}"}>
                  <td class="pr-4">{product}</td>
                  <td class="text-right">{units(Map.fetch!(@game.stocks, product))}</td>
                  <td :if={product == :gold} id="protected-gold" class="pl-4 opacity-70">
                    protected {units(@report.bandit_protected)}
                  </td>
                  <td
                    :if={product in [:food, :gold] and Map.fetch!(@forecast, product)}
                    id={"forecast-#{product}"}
                    class="pl-4"
                    title="change in the last week; forecast if nothing changes"
                  >
                    <.stock_forecast forecast={Map.fetch!(@forecast, product)} week={@game.week} />
                  </td>
                </tr>
              </table>
              <p id="books-held" class="mt-2 flex flex-wrap items-center gap-3 text-sm tabular-nums">
                <span>books</span>
                <span
                  :for={colour <- Pentagon.colours()}
                  id={"books-#{colour}"}
                  class="inline-flex items-center gap-1"
                >
                  <span class={["inline-block h-3 w-3 rounded-sm", colour_class(colour)]}></span>
                  {Map.fetch!(@game.books, colour)}
                </span>
              </p>
              <.happiness happiness={@report.happiness} />
            </section>

            <.bandits game={@game} report={@report} forecast={@forecast.bandits} />

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
                  @game.config.king_tax_count_lead_weeks}
              </p>
              <p :if={@forecast.tax} id="forecast-tax" class="mt-1 text-sm tabular-nums">
                <span class="opacity-70">
                  Next tax: {if(@forecast.tax.counted?, do: "", else: "at least ")}{units(
                    @forecast.tax.amount
                  )} gold in week {@forecast.tax.due_week}.
                </span>
                <span :if={@forecast.tax.expected_gold} class="opacity-70">
                  Expected gold by then: {units(@forecast.tax.expected_gold)}.
                </span>
                <span
                  :if={@forecast.tax.expected_gold}
                  id="forecast-tax-outcome"
                  class={[
                    "font-semibold",
                    if(@forecast.tax.shortfall > 0, do: "text-red-600", else: "text-green-700")
                  ]}
                >
                  {if(@forecast.tax.shortfall > 0,
                    do: "Short by #{units(@forecast.tax.shortfall)}",
                    else: "Covered"
                  )}
                </span>
              </p>
              <p id="tax-misses" class="text-sm tabular-nums">
                Missed payments and demands: {@game.misses} (forgiven: {@game.config.king_misses_forgiven})
              </p>
            </section>

            <section id="demands">
              <h2 class="mb-2 font-semibold">The king's demands</h2>
              <div
                :if={Demands.project?(@game.demand)}
                id="project"
                class="flex flex-wrap items-center gap-3 text-sm"
              >
                <span :if={@project} class="tabular-nums">
                  Project: {units(@project.progress)}/{units(@game.demand.amount)} {@game.demand.product} by week {@game.demand.due_week}, {length(
                    Place.workers_at(@game.workers, @project.id)
                  )} worker(s) on it
                </span>
                <span :if={!@project} class="tabular-nums">
                  Project: {units(@game.demand.amount)} {@game.demand.product} by week {@game.demand.due_week}
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
              <p
                :if={@forecast.demand && @forecast.demand.expected}
                id="forecast-demand"
                class="mt-1 text-sm tabular-nums"
                title="change in the last week, repeated until the deadline"
              >
                <span class="opacity-70">
                  Expected by week {@forecast.demand.due_week}: {units(@forecast.demand.expected)}/{units(
                    @forecast.demand.amount
                  )}.
                </span>
                <span
                  id="forecast-demand-outcome"
                  class={[
                    "font-semibold",
                    if(@forecast.demand.met?, do: "text-green-700", else: "text-red-600")
                  ]}
                >
                  {if(@forecast.demand.met?, do: "Will be met", else: "Will fall short")}
                </span>
              </p>
              <p :if={!@game.demand} class="text-sm opacity-60">No open demand.</p>
            </section>

            <section id="last-week">
              <h2 class="mb-2 font-semibold">Week {@report.week}</h2>
              <table class="text-sm tabular-nums">
                <tr>
                  <td class="pr-4">production</td>
                  <td>
                    <span :for={product <- Blueprint.goods()} class="mr-3">
                      {product} {units(Map.fetch!(@report.production, product))}
                    </span>
                  </td>
                </tr>
                <tr>
                  <td class="pr-4">mana</td>
                  <td>
                    <span
                      :for={colour <- Pentagon.colours()}
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
          :for={place <- @game.places}
          id={"building-#{place.id}"}
          class="flex flex-wrap items-center gap-3"
        >
          <div class={["h-4 w-4 rounded-sm", colour_class(card_colour(place))]}></div>
          <span class="min-w-24 text-sm">
            {place_name(place)}<span :if={site?(place)} class="opacity-60"> site</span>
          </span>
          <span class="w-10 text-sm tabular-nums">
            {workers_label(@game, place)}
          </span>
          <.worker
            :for={worker <- Place.workers_at(@game.workers, place.id)}
            worker={worker}
            selected={@selected == worker.id}
          />
          <span
            :if={book?(place)}
            id={"book-#{place.id}"}
            class="text-sm tabular-nums opacity-60"
          >
            progress {units(place.progress)}/{units(place.target)} knowledge
          </span>
          <span
            :if={demand_project?(place)}
            id={"demand-project-#{place.id}"}
            class="text-sm tabular-nums opacity-60"
          >
            progress {units(place.progress)}/{units(place.target)}, by week {elem(place.gives, 1)}
          </span>
          <span
            :if={site?(place)}
            id={"site-#{place.id}"}
            class="text-sm tabular-nums opacity-60"
          >
            builders arrived {length(Construction.arrived(@game.workers, place.id))}/{@game.config.build_capacity},
            progress {place.progress}/{@game.config.build_work}
          </span>
          <span
            :for={worker <- Place.workers_at(@game.workers, place.id)}
            :if={worker.training_started}
            id={"training-#{worker.id}"}
            class="text-sm opacity-60"
          >
            trained after week {Training.last_week(worker.training_started, @game.config)}
          </span>
          <button
            :if={@selected}
            id={"place-#{place.id}"}
            phx-click="place"
            phx-value-building={place.id}
            class="rounded border px-2 py-0.5 text-sm hover:bg-zinc-100"
          >
            Place here
          </button>
        </div>
        <div id="unplaced" class="flex flex-wrap items-center gap-3">
          <div class="h-4 w-4"></div>
          <span class="w-24 text-sm">unplaced</span>
          <span class="w-10 text-sm tabular-nums">{length(Place.workers_at(@game.workers, nil))}</span>
          <.worker
            :for={worker <- Place.workers_at(@game.workers, nil)}
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
          :for={type <- Blueprint.types()}
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
      <h2 class="mt-4 mb-2 font-semibold">Write a book</h2>
      <p class="mb-2 text-sm opacity-60">Free; one writer per book.</p>
      <div class="flex flex-wrap gap-2">
        <button
          :for={colour <- Pentagon.colours()}
          id={"start-book-#{colour}"}
          phx-click="start_book"
          phx-value-colour={colour}
          class="inline-flex items-center gap-2 rounded border px-2 py-1 text-sm hover:bg-zinc-100"
        >
          <span class={["inline-block h-3 w-3 rounded-sm", colour_class(colour)]}></span>
          write a {colour} book
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

  defp site?(place), do: match?(%Project{gives: {:building, _}}, place)
  defp demand_project?(place), do: match?(%Project{gives: {:demand, _}}, place)
  defp book?(place), do: match?(%Project{gives: {:book, _}}, place)

  # a book shows its own colour, not its blue method
  defp card_colour(%Project{gives: {:book, colour}}), do: colour
  defp card_colour(place), do: Place.colour(place)

  # a site is named after the building it gives, a demand project after its good
  defp place_name(%Project{gives: {:building, type}}), do: type

  defp place_name(%Project{gives: {:demand, _}} = project),
    do: "king's demand: #{Place.good(project)}"

  defp place_name(%Project{gives: {:book, colour}}), do: "#{colour} book"

  defp place_name(place), do: Place.type(place)

  # workers / capacity; a demand project takes any number
  defp workers_label(game, place) do
    count = length(Place.workers_at(game.workers, place.id))

    case Placement.capacity(place, game.config) do
      :unlimited -> "#{count}"
      capacity -> "#{count}/#{capacity}"
    end
  end

  defp type_colour(type), do: Blueprint.fetch!(type).colour

  defp colour_class(nil), do: "bg-zinc-400"
  defp colour_class(colour), do: Map.fetch!(@colour_classes, colour)

  defp per_mille(share), do: "#{div(share, 10)}.#{rem(share, 10)}%"

  attr :forecast, :map, required: true
  attr :week, :integer, required: true

  defp stock_forecast(assigns) do
    ~H"""
    <span class={["font-semibold", forecast_class(@forecast.direction)]}>
      {direction(@forecast.change)} {signed(@forecast.change)}/week
    </span>
    <span :if={Map.get(@forecast, :weeks_left)} class="font-semibold text-red-600">
      · runs out {if(@forecast.weeks_left == 0,
        do: "now",
        else: "in week #{@week + @forecast.weeks_left} (#{weeks(@forecast.weeks_left)})"
      )}
    </span>
    """
  end

  defp forecast_class(:rising), do: "text-green-700"
  defp forecast_class(:falling), do: "text-red-600"
  defp forecast_class(:steady), do: "opacity-60"

  defp signed(amount) when amount > 0, do: "+" <> units(amount)
  defp signed(amount), do: units(amount)

  defp weeks(1), do: "1 week"
  defp weeks(n), do: "#{n} weeks"

  attr :happiness, :map, default: nil

  defp happiness(assigns) do
    ~H"""
    <p id="happiness" class="mt-2 text-sm tabular-nums">
      <span class="pr-4">happiness</span>
      <%= if @happiness do %>
        <span
          id="happiness-now"
          class={["font-semibold", step_class(@happiness.step)]}
          title="last week's culture production against what every worker needs; changes food and defence production"
        >
          step {signed_step(@happiness.step)}
        </span>
        <span class="opacity-70">
          ratio {per_mille(@happiness.ratio)}<.without_grace happiness={@happiness} />
        </span>
      <% else %>
        <span class="opacity-60">from week 1</span>
      <% end %>
    </p>
    """
  end

  attr :happiness, :map, required: true

  defp without_grace(assigns) do
    ~H"""
    <span :if={@happiness.step != @happiness.step_without_grace}>
      , grace period: would be {signed_step(@happiness.step_without_grace)}
    </span>
    """
  end

  defp signed_step(step) when step > 0, do: "+#{step}"
  defp signed_step(step), do: Integer.to_string(step)

  defp step_class(step) when step > 0, do: "text-green-700"
  defp step_class(step) when step < 0, do: "text-red-600"
  defp step_class(_step), do: "opacity-60"

  attr :game, Game, required: true
  attr :report, :map, required: true
  attr :forecast, :map, default: nil

  defp bandits(assigns) do
    assigns =
      assigns
      |> assign(:threshold, Bandits.threshold(assigns.game.config))
      |> assign(:weeks_to_raid, Bandits.weeks_to_raid(assigns.game.bandits, assigns.game.week))

    ~H"""
    <section id="bandits">
      <h2 class="mb-2 font-semibold">Bandits</h2>
      <p id="bandit-threat" class="text-sm tabular-nums">
        Threat {units(@game.bandits.threat)} / {units(@threshold)}
        <span
          :if={is_nil(@weeks_to_raid)}
          id="bandit-threat-direction"
          class={["ml-2 font-semibold", direction_class(@report.bandit_threat_change)]}
          title="change in the last week, from its gold and protected gold"
        >
          {direction(@report.bandit_threat_change)}
        </span>
        <span
          :if={@forecast}
          id="forecast-bandits"
          class={[
            "ml-2",
            if(@forecast.weeks_to_threshold == :never, do: "opacity-60", else: "text-red-600")
          ]}
          title="at the last week's pressure, if nothing changes"
        >
          {if(@forecast.weeks_to_threshold == :never,
            do: "· threshold: never",
            else:
              "· threshold in week #{@game.week + @forecast.weeks_to_threshold} (#{weeks(@forecast.weeks_to_threshold)})"
          )}
        </span>
      </p>
      <p
        :if={@weeks_to_raid}
        id="bandits-approaching"
        class="mt-1 text-sm font-semibold text-red-600 tabular-nums"
      >
        Bandits are on their way: they raid in week {@game.bandits.raid_week} ({@weeks_to_raid} {if(
          @weeks_to_raid == 1,
          do: "week",
          else: "weeks"
        )} left).
      </p>
    </section>
    """
  end

  defp direction(change) when change > 0, do: "▲ rising"
  defp direction(change) when change < 0, do: "▼ falling"
  defp direction(_change), do: "● steady"

  defp direction_class(change) when change > 0, do: "text-red-600"
  defp direction_class(change) when change < 0, do: "text-green-700"
  defp direction_class(_change), do: "opacity-60"

  defp units(amount) do
    if rem(amount, Fixed.scale()) == 0 do
      Integer.to_string(div(amount, Fixed.scale()))
    else
      :erlang.float_to_binary(amount / Fixed.scale(), [:compact, decimals: 3])
    end
  end
end
