defmodule MyLiege.Service.Sim do
  use Sim.Commands.DataHelpers, app_module: MyLiege.Game
  @behaviour Sim.CommandHandler

  alias Sim.Realm.Data
  alias MyLiege.Game.Workplace

  def execute(:tick, []) do
    get_data()
    |> Map.fetch(:workplaces)
    |> workplace_events()
  end

  def execute(:add_inventory, input) do
    change_data(fn data ->
      %{data | inventory: aggregate_map(data.inventory, input)}
    end)

    [{:inventory_updated, input: input}]
  end

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
end
