defmodule MyLiege.Engine.Config do
  @moduledoc """
  The single source of every game value. Engine functions take this struct as an argument,
  so the settings panel can pass an edited copy. Defaults come from the Prototype Plan
  and the designer's decisions.
  """

  alias MyLiege.Engine.Manameter

  defstruct starting_manameter: %Manameter{green: 80, blue: 5, red: 10, yellow: 5, violet: 0},
            last_week: 143,
            starting_food: 24,
            food_per_worker_per_week: 3,
            birth_interval_weeks: 2,
            birth_min_food_left: 0
end
