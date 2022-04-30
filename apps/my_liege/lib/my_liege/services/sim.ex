defmodule MyLiege.Service.Sim do
  use Sim.Commands.DataHelpers, app_module: MyLiege.Game
  @behaviour Sim.CommandHandler

  import MyLiege.MapAggregator

  alias Sim.Realm.Data
  alias MyLiege.Game.{Board, Workplace}

  def execute(:tick, []) do
    [
      {:command, {:sim, :workplace_productions}},
      {:command, {:sim, :pawn_nutrition}},
      {:command, {:sim, :pawn_poverty}}
    ]
  end

  def execute(:workplace_productions, []) do
    get_data()
    |> Map.get(:workplaces)
    |> Map.values()
    |> workplace_events()
  end

  def execute(:pawn_nutrition, []) do
    food = get_data() |> needed_food()
    {:command, {:sim, :add_inventory, %{food: -food}}}
  end

  def execute(:pawn_poverty, []) do
    change_data(&pawn_poverty/1)
  end

  def execute(:add_inventory, input) do
    change_data(fn data ->
      {%Board{data | inventory: aggregate_map(data.inventory, input)},
       [{:inventory_updated, input: input}]}
    end)
  end

  # --- workplace_productions ---
  def workplace_events(workplaces) do
    workplaces
    |> Enum.map(&Workplace.produce(&1))
    |> Enum.reduce(%{}, &aggregate_map(&2, &1))
    |> inventory_commands()
    |> event
  end

  defp inventory_commands(output) when map_size(output) == 0, do: []

  defp inventory_commands(output) when map_size(output) > 0 do
    [{:command, {:sim, :add_inventory, output}}]
  end

  defp event(commands), do: [{:workplaces_produced, :time_unit} | commands]

  # --- pawn_nutrition ---
  def needed_food(%{workplaces: workplaces, pawn_pool: pawn_pool}) do
    needed_food_in_workplaces(workplaces) + pawn_pool.normal
  end

  defp needed_food_in_workplaces(workplaces) do
    Enum.reduce(workplaces, 0, fn {_id, workplace}, food_needed ->
      Workplace.get_pawns(workplace) + food_needed
    end)
  end

  # --- poverty ---
  def pawn_poverty(%Board{} = data) do
    cond do
      !Board.has_food?(data) && Board.has_poverty?(data) ->
        starving = ceil(Board.get_in(data, [:poverty, :normal]) / 5)

        {aggregate_map_min_zero(data, %{poverty: %{normal: -starving}}),
         [{:pawns_changed, poverty: -starving}]}

      !Board.has_food?(data) && Board.has_free_pawns?(data) ->
        starving = ceil(Board.get_in(data, [:pawn_pool, :normal]) / 5)

        {aggregate_map_min_zero(data, %{
           pawn_pool: %{normal: -starving},
           poverty: %{normal: starving}
         }), [{:pawns_changed, pool: -starving, poverty: starving}]}

      Board.has_food?(data) && Board.has_poverty?(data) ->
        delta = ceil(Board.get_in(data, [:inventory, :food] / 5))

        {aggregate_map_min_zero(data, %{pawn_pool: %{normal: delta}, poverty: %{normal: -delta}}),
         [{:pawns_changed, pool: delta, poverty: -delta}]}

      Board.has_food?(data) && !Board.has_poverty?(data) ->
        # growth ?
        {data, []}
    end
  end
end
