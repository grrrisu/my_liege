defmodule MyLiege.Service.User do
  use Sim.Commands.DataHelpers, app_module: MyLiege.Game
  @behaviour Sim.CommandHandler

  alias MyLiege.Game.{Board, Workplace}

  def execute(:add_pawn_to_workplace, workplace_id: id) do
    change_data(&add_pawn_to_workplace(&1, id))
    [{:pawn_added_to_workplace, workplace_id: id}, {:pawn_removed_from_pool, pawn: :normal}]
  end

  def execute(:remove_pawn_from_workplace, workplace_id: id) do
    change_data(&remove_pawn_from_workplace(&1, id))
    [{:pawn_removed_from_workplace, workplace_id: id}, {:pawn_added_to_pool, pawn: :normal}]
  end

  def execute(:transport_to_workplace, workplace_id: id, goods: goods) do
    change_data(&transport_to_workplace(&1, goods, id))
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

  def transport_to_workplace(data, goods, workplace_id) do
    data
    |> available_goods(goods)
    |> remove_goods_from_inventory()
    |> add_goods_to_workplace(workplace_id)
  end

  def available_goods(data, goods) do
    material =
      goods
      |> Enum.take_while(fn {material, _} -> Map.get(data.inventory, material) && material end)
      |> Enum.take(1)
      |> Keyword.keys()
      |> List.first()

    {data, %{material => 1}}
  end

  def remove_goods_from_inventory({data, goods}) do
    inventory =
      Enum.reduce(goods, data.inventory, fn {material, amount}, inventory ->
        Map.update!(inventory, material, &(&1 - amount))
      end)

    {%Board{data | inventory: inventory}, [{:inventory_updated, removed: goods}], goods}
  end

  def add_goods_to_workplace({data, events, goods}, workplace_id) do
    workplaces =
      Map.update!(data.workplaces, workplace_id, fn workplace ->
        Workplace.inc_inventory(workplace, goods)
      end)

    {%Board{data | workplaces: workplaces}, [{:workplace_updated, id: workplace_id} | events]}
  end
end
