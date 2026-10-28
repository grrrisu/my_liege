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
            birth_min_food_left: 0,
            base_production: %{farm: 15, monastery: 3, watchtower: 3, market: 3, tavern: 3},
            colour_factors: %{
              untrained: %{same: 1.0, neighbour: 0.8, opposite: 0.5},
              trained: %{same: 1.25, neighbour: 0.6, opposite: 0.3}
            },
            starting_buildings: [:farm, :monastery, :watchtower, :market, :tavern],
            building_capacity: 3,
            construction_weeks: 1,
            mana_per_worker: %{
              untrained: %{building_colour: 2, own_colour: 1},
              trained: %{building_colour: 1, own_colour: 2}
            }
end
