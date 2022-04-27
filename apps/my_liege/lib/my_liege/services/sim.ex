defmodule MyLiege.Service.Sim do
  use Sim.Commands.DataHelpers, app_module: MyLiege.Game
  @behaviour Sim.CommandHandler

  alias Sim.Realm.Data
  alias MyLiege.Game.Workplace

  def execute(:tick, []) do
    [
      {:command, {:sim, :workplace_productions}},
      {:command, {:sim, :pawn_nutrition}}
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

  def execute(:add_inventory, input) do
    change_data(fn data ->
      %{data | inventory: aggregate_map(data.inventory, input)}
    end)

    [{:inventory_updated, input: input}]
  end

  # --- workplace_productions ---
  def workplace_events(workplaces) do
    workplaces
    |> Enum.map(&Workplace.produce(&1))
    |> Enum.reduce(%{}, &aggregate_map(&2, &1))
    |> inventory_commands()
    |> event
  end

  defp aggregate_map(map, nil), do: map

  defp aggregate_map(map, input) when is_map(input) do
    Enum.reduce(input, map, fn {key, value}, acc ->
      case Map.has_key?(acc, key) do
        true -> Map.put(acc, key, Map.get(acc, key) + value)
        false -> Map.put(acc, key, value)
      end
    end)
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
end
