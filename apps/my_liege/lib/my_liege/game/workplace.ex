defmodule MyLiege.Game.Workplace do
  defstruct id: nil, type: nil, pawn: nil, position: nil, inventory: %{}, input: %{}, output: %{}

  alias MyLiege.Game.Workplace

  def produce(%Workplace{pawn: nil}), do: {nil, nil}

  def produce(%Workplace{} = workplace) do
    with true <- has_material?(workplace) do
      next_step(workplace)
    else
      _ -> {nil, nil}
    end
  end

  defp next_step(
         %Workplace{
           type: :construction_site,
           inventory: %{manpower: x},
           input: %{manpower: x}
         } = construction_site
       ) do
    {construct_site(construction_site), nil}
  end

  defp next_step(
         %Workplace{type: _factory, inventory: %{manpower: x}, input: %{manpower: x}} = factory
       ) do
    produce_output(factory)
  end

  defp next_step(%Workplace{type: _factory, inventory: %{manpower: x} = inventory} = factory) do
    factory = %Workplace{factory | inventory: %{inventory | manpower: x + 1}}
    {factory, nil}
  end

  defp next_step(%Workplace{type: _factory, inventory: inventory} = factory) do
    factory = %Workplace{factory | inventory: Map.put(inventory, :manpower, 1)}
    {factory, nil}
  end

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

  defp construct_site(construction_site) do
    inventory = consume_matrial(construction_site)

    %Workplace{
      construction_site.output
      | id: construction_site.id,
        pawn: construction_site.pawn,
        inventory: %{inventory | manpower: 0}
    }
  end

  defp produce_output(factory) do
    inventory = consume_matrial(factory)
    factory = %Workplace{factory | inventory: %{inventory | manpower: 0}}
    {factory, factory.output}
  end
end
