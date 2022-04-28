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
  def pawn_poverty(%Board{inventory: %{food: food}} = data) do
    cond do
      # food < 0 && (is_nil(poverty.normal) || poverty.normal == 0) -> dec_workplaces(food)
      food < 0 ->
        aggregate_map(data, %{pawn_pool: %{normal: -food}, poverty: %{normal: food}})

      # food > 0 && (is_nil(poverty.normal) || poverty.normal == 0) -> nil

      food > 0 && data.poverty.normal > 0 ->
        aggregate_map(data, %{pawn_pool: %{normal: food}, poverty: %{normal: -food}})
    end
  end
end
