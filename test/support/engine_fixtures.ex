defmodule MyLiege.EngineFixtures do
  @moduledoc "Explicit engine configuration for tests, independent of the designer's CSV."

  alias MyLiege.Engine.{Config, Manameter}

  def config(overrides \\ []) do
    struct!(
      %Config{
        birth_interval_weeks: 2,
        birth_min_food_left: 1,
        starting_manameter: %Manameter{green: 800, blue: 50, red: 100, yellow: 50, violet: 0},
        starting_farmers: 1,
        starting_soldiers: 1,
        base_production: %{farm: 9, monastery: 3, watchtower: 3, market: 3, tavern: 3},
        capacity: %{farm: 4, monastery: 4, watchtower: 4, market: 4, tavern: 4},
        colour_factors: %{
          untrained: %{same: 1000, neighbour: 800, opposite: 500},
          trained: %{same: 1250, neighbour: 600, opposite: 300}
        },
        construction_weeks: 2,
        mana_per_worker: %{
          untrained: %{building_colour: 2, own_colour: 1},
          trained: %{building_colour: 1, own_colour: 2}
        },
        manameter_points_per_week: 3
      },
      overrides
    )
  end
end
