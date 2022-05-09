defmodule MyLiege.Service.User do
  use Sim.Commands.DataHelpers, app_module: MyLiege.Game
  @behaviour Sim.CommandHandler

  alias MyLiege.Game.Board

  def execute(:add_pawn_to_workplace, workplace_id: id) do
    change_data(&add_pawn_to_workplace(&1, id))
    [{:pawn_added_to_workplace, workplace_id: id}, {:pawn_removed_from_pool, pawn: :normal}]
  end

  def execute(:remove_pawn_from_workplace, workplace_id: id) do
    change_data(&remove_pawn_from_workplace(&1, id))
    [{:pawn_removed_from_workplace, workplace_id: id}, {:pawn_added_to_pool, pawn: :normal}]
  end

  def add_pawn_to_workplace(%Board{pawn_pool: %{normal: 0}} = data, _id), do: data

  def add_pawn_to_workplace(data, id) do
    data
    |> Board.update_in([:workplaces, id], &Map.put(&1, :pawn, 1))
    |> Board.update_in([:pawn_pool, :normal], &(&1 - 1))
  end

  def remove_pawn_from_workplace(data, id) do
    if Board.get_in(data, [:workplaces, id]) |> Map.get(:pawn) == 0 do
      data
    else
      data
      |> Board.update_in([:workplaces, id], &Map.put(&1, :pawn, nil))
      |> Board.update_in([:pawn_pool, :normal], &(&1 + 1))
    end
  end
end
