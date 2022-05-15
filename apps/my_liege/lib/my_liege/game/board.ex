defmodule MyLiege.Game.Board do
  alias MyLiege.Game.{Board, Workplace}

  defstruct workplaces: %{}, pawn_pool: %{}, poverty: %{}, inventory: %{}

  def create("one") do
    farm = %Workplace{id: 1, type: :farm, input: %{manpower: 4}, output: %{food: 15}}

    %Board{
      workplaces: %{
        1 => %Workplace{farm | id: 1},
        2 => %Workplace{id: 2, type: :construction_site, input: %{manpower: 5}, output: farm},
        3 => %Workplace{id: 3, type: :construction_site, input: %{manpower: 5}, output: farm}
      },
      pawn_pool: %{normal: 3},
      inventory: %{food: 15}
    }
  end

  def create("test") do
    %Board{}
  end

  def update_in(data, path, func) do
    struct(Board, Map.from_struct(data) |> Kernel.update_in(path, func))
  end

  def get_in(data, path) do
    Map.from_struct(data) |> Kernel.get_in(path)
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
