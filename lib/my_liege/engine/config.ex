defmodule MyLiege.Engine.Config do
  @moduledoc """
  The single source of every game value. Engine functions take this map as an argument,
  so the settings panel can pass an edited copy.
  """

  @doc "Default values from the Prototype Plan and the designer's decisions."
  def default do
    %{
      # Pentagon order: Growth – Wisdom – Strength – Wealth – Culture, back to Growth.
      colours: [:green, :blue, :red, :yellow, :violet],
      starting_manameter: %{green: 80, blue: 5, red: 10, yellow: 5, violet: 0},
      last_week: 143,
      starting_food: 24,
      food_per_worker_per_week: 3,
      birth_interval_weeks: 2,
      birth_min_food_left: 0
    }
  end
end
