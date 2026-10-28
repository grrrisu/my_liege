defmodule MyLiege.Engine.Fixed do
  @moduledoc """
  Stocks are integers in thousandths, so a per mille factor applied to a whole amount stays exact.
  The configuration keeps whole units; the engine converts with `from/1`.
  """

  @scale 1000

  def scale, do: @scale

  def from(units) when is_integer(units), do: units * @scale
end
