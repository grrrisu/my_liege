defmodule MyLiege.Service.Sim do
  @behaviour Sim.CommandHandler

  alias Sim.Realm.Data
  alias MyLiege.Game.Workplace

  def execute(:tick, []) do
    Data.get_data(Game.Data)
    |> Map.fetch(:workplaces)
    |> workplace_events()
  end

  def workplace_events(workplaces) do
    workplaces
    |> Enum.map(&Workplace.produce(&1))
    |> Enum.reduce(%{}, &merge_output(&1, &2))
    |> inventory_command()
    |> event
  end

  defp merge_output(nil, acc), do: acc

  defp merge_output(output, acc) when is_map(output) do
    Enum.reduce(output, acc, fn {key, value}, acc ->
      case Map.has_key?(acc, key) do
        true -> Map.put(acc, key, Map.get(acc, key) + value)
        false -> Map.put(acc, key, value)
      end
    end)
  end

  defp inventory_command(output) when map_size(output) == 0, do: []

  defp inventory_command(output) when map_size(output) > 0 do
    [{:command, {:sim, :add_inventory, output}}]
  end

  defp event(commands), do: [{:workplaces_produced, :time_unit} | commands]
end
