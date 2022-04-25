defmodule MyLiege.Game.Workplace do
  defstruct id: nil, type: nil, pawn: nil, position: nil

  alias MyLiege.Game.Workplace

  def produce(%Workplace{pawn: nil}), do: nil

  def produce(%Workplace{type: :farm}) do
    %{food: 5}
  end

  def has_capacity?(%Workplace{pawn: nil}), do: true
  def has_capacity?(%Workplace{pawn: _}), do: false
end
