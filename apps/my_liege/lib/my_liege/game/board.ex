defmodule MyLiege.Game.Board do
  alias MyLiege.Game.{Board, Workplace}

  defstruct workplaces: %{}, pawn_pool: %{}, poverty: %{}, inventory: %{}

  def create("one") do
    farm = %Workplace{id: 1, type: :farm, input: %{manpower: 4}, output: %{food: 15}}

    farm_construction = %Workplace{
      id: 2,
      type: :construction_site,
      input: %{manpower: 5, wood: 3},
      output: farm
    }

    %Board{
      workplaces: %{
        1 => %Workplace{farm | id: 1},
        2 => %Workplace{farm_construction | id: 2},
        3 => %Workplace{farm_construction | id: 3}
      },
      pawn_pool: %{normal: 3},
      inventory: %{food: 15, wood: 5}
    }
  end

  def create("test") do
    %Board{}
  end

  def update_in(data, [board_key | path], func) do
    Kernel.update_in(data, [Access.key(board_key) | path], func)
  end

  def get_in(data, [board_key | path]) do
    Kernel.get_in(data, [Access.key(board_key) | path])
  end

  def has_poverty?(%Board{poverty: poverty}) do
    has_attribute?(poverty, :normal)
  end

  def has_food?(%Board{inventory: inventory}) do
    has_attribute?(inventory, :food)
  end

  def has_free_pawns?(%Board{pawn_pool: pawn_pool}) do
    has_attribute?(pawn_pool, :normal)
  end

  def employed_pawns(%Board{} = data) do
    Enum.reduce(data.workplaces, 0, fn {_id, workplace}, sum ->
      sum + Workplace.get_pawns(workplace)
    end)
  end

  defp has_attribute?(map, attr) do
    case Map.get(map, attr) do
      nil -> false
      n when n <= 0 -> false
      _ -> true
    end
  end
end
