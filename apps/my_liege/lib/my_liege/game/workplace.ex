defmodule MyLiege.Game.Workplace do
  defstruct id: nil, type: nil, pawn: nil, position: nil, inventory: %{}, input: %{}, output: %{}

  alias MyLiege.Game.Workplace

  def has_capacity?(%Workplace{pawn: nil}), do: true
  def has_capacity?(%Workplace{pawn: _}), do: false

  def get_pawns(%Workplace{pawn: nil}), do: 0
  def get_pawns(%Workplace{pawn: _}), do: 1

  def has_material?(%Workplace{inventory: inventory, input: input}) do
    input
    |> without_manpower()
    |> Enum.all?(fn {key, value} ->
      Map.get(inventory, key, 0) >= value
    end)
  end

  defp consume_matrial(%Workplace{inventory: inventory, input: input}) do
    input
    |> without_manpower()
    |> Enum.reduce(inventory, fn {key, value}, inventory ->
      Map.update!(inventory, key, fn stored -> stored - value end)
    end)
  end

  defp without_manpower(map) do
    Enum.reject(map, fn {key, _} -> key == :manpower end)
  end

  def inc_manpower(%Workplace{type: _factory, inventory: %{manpower: x} = inventory} = factory) do
    %Workplace{factory | inventory: %{inventory | manpower: x + 1}}
  end

  def inc_manpower(%Workplace{type: _factory, inventory: inventory} = factory) do
    %Workplace{factory | inventory: Map.put(inventory, :manpower, 1)}
  end

  def construct_site(construction_site) do
    inventory = consume_matrial(construction_site)

    %Workplace{
      construction_site.output
      | id: construction_site.id,
        pawn: construction_site.pawn,
        inventory: %{inventory | manpower: 0}
    }
  end

  def produce_output(factory) do
    inventory = consume_matrial(factory)
    factory = %Workplace{factory | inventory: %{inventory | manpower: 0}}
    {factory, factory.output}
  end
end
