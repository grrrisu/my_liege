defmodule MyLiege.Engine.Births do
  @moduledoc """
  R1: a newborn's colour is drawn with chances equal to the Manameter shares.
  A birth needs at least `birth_min_food_left` food left after eating.

  Random state is passed in and returned (`:rand` `*_s` functions), so a run replays exactly from its seed.
  """

  alias MyLiege.Engine.{Config, Fixed, Manameter, Worker}

  @doc "Whether a birth is attempted in this week."
  def birth_week?(week, %Config{} = config), do: rem(week, config.birth_interval_weeks) == 0

  @doc """
  Attempts a birth after the week's eating. `food_left` is in thousandths (see `Fixed`).
  Returns `{newborn | nil, rand}`. A birth that fails for lack of food is lost.
  """
  def attempt(week, food_left, %Manameter{} = manameter, %Config{} = config, rand) do
    if birth_week?(week, config) and food_left >= Fixed.from(config.birth_min_food_left) do
      {colour, rand} = draw_colour(manameter, rand)
      {%Worker{colour: colour}, rand}
    else
      {nil, rand}
    end
  end

  @doc "Draws a colour with chances equal to the Manameter shares. Returns `{colour, rand}`."
  def draw_colour(%Manameter{} = manameter, rand) do
    colours = Manameter.colours()
    {u, rand} = :rand.uniform_s(rand)
    target = u * Manameter.total(manameter)

    colour =
      Enum.reduce_while(colours, 0, fn colour, cumulative ->
        cumulative = cumulative + Map.fetch!(manameter, colour)
        if target < cumulative, do: {:halt, colour}, else: {:cont, cumulative}
      end)

    {colour, rand}
  end
end
