defmodule MyLiege.Game.Workplace do
  defstruct id: nil, type: nil, pawn: nil, position: nil, inventory: %{}, input: %{}, output: %{}

  alias MyLiege.Game.Workplace

  def produce(%Workplace{pawn: nil}), do: {nil, nil}

  def produce(
        %Workplace{
          type: :construction_site,
          inventory: %{manpower: x},
          input: %{manpower: x}
        } = construction_site
      ) do
    {%Workplace{construction_site.output | id: construction_site.id}, nil}
  end

  def produce(
        %Workplace{type: _factory, inventory: %{manpower: x} = inventory, input: %{manpower: x}} =
          farm
      ) do
    farm = %Workplace{farm | inventory: %{inventory | manpower: 0}}
    {farm, farm.output}
  end

  def produce(%Workplace{type: _factory, inventory: %{manpower: x} = inventory} = farm) do
    farm = %Workplace{farm | inventory: %{inventory | manpower: x + 1}}
    {farm, nil}
  end

  def produce(%Workplace{type: _factory, inventory: inventory} = farm) do
    farm = %Workplace{farm | inventory: Map.put(inventory, :manpower, 1)}
    {farm, nil}
  end

  def has_capacity?(%Workplace{pawn: nil}), do: true
  def has_capacity?(%Workplace{pawn: _}), do: false

  def get_pawns(%Workplace{pawn: nil}), do: 0
  def get_pawns(%Workplace{pawn: _}), do: 1
end

defmodule MyLiege.Game.Blueprint do
  defstruct type: nil, needed_resources: %{}, manpower: 0
end
