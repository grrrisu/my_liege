defmodule MyLiege.EngineFixtures do
  @moduledoc "Explicit engine configuration for tests, independent of the designer's CSV."

  alias MyLiege.Engine.{Config, Game, Manameter, Place}
  alias MyLiege.Engine.Place.{Blueprint, Building, Project}
  alias MyLiege.Engine.Rules.Demands

  def config(overrides \\ []) do
    struct!(
      %Config{
        birth_interval_weeks: 2,
        birth_min_food_left: 1,
        manameter_start: %Manameter{green: 800, blue: 50, red: 100, yellow: 50, violet: 0},
        start_farmers: 1,
        start_soldiers: 1,
        place_output_per_worker: %{farm: 9, monastery: 3, watchtower: 3, market: 3, tavern: 3},
        place_capacity: %{
          farm: 4,
          monastery: 4,
          watchtower: 4,
          market: 4,
          tavern: 4,
          guildhouse: 1
        },
        efficiency: %{
          untrained: %{same: 1000, neighbour: 800, opposite: 500},
          trained: %{same: 1250, neighbour: 600, opposite: 300}
        },
        # a site needs builders (R2): tests that need a finished building add one
        # (`add_building/2`) instead of building it
        build_work: 4,
        build_cost_gold: 30,
        build_capacity: 2,
        book_work: 96,
        # no travel, so tests about other rules see placements take effect at once
        travel_weeks: 0,
        mana: %{
          untrained: %{place_colour: 2, worker_colour: 1},
          trained: %{place_colour: 1, worker_colour: 2}
        },
        manameter_points_per_week: 3,
        start_food: 24,
        start_gold: 100,
        game_years: 3,
        good_food_eaten_per_worker: 3,
        king_tax_per_worker: 10,
        king_tax_interval_weeks: 24,
        king_tax_count_lead_weeks: 4,
        king_misses_forgiven: 1,
        # no grace period, so tests about other rules see taxes and demands from week 1
        king_grace_weeks: 0,
        training_min_share: 300,
        training_weeks: 4,
        king_demand_deadline_weeks: 8,
        king_demand_population_share: 100,
        king_demand_production_weeks: 8,
        good_spoilage: %{food: 0, knowledge: 0, defence: 0, gold: 0, culture: 0},
        # bandits never set out and, if they do (no defence), never arrive, so tests about other
        # rules keep their gold; bandit tests set their own values
        bandit_threshold: 1_000_000,
        bandit_warning_weeks: 1_000_000,
        bandit_cover_weeks: 20,
        bandit_floor_step: 2,
        # the ratio is computed, but steps of 0 leave production alone, so tests about other
        # rules keep their food and defence; happiness tests set their own steps
        happiness_need_per_worker: 1000,
        happiness_penalty_below: %{level1: 750, level2: 500, level3: 250},
        happiness_bonus_from: %{level1: 1250, level2: 1750, level3: 2500},
        happiness_change: %{level1: 0, level2: 0, level3: 0}
      },
      overrides
    )
  end

  @doc "A building of `type` with id `id`."
  def new_building(id, type), do: %Building{id: id, blueprint: Blueprint.fetch!(type)}

  @doc "Adds a finished building of `type` to the game, with the next free id, as if built."
  def add_building(game, type),
    do: %{game | places: game.places ++ [game.places |> Place.next_id() |> new_building(type)]}

  @doc "A site with id `id` that gives a building of `type`, target 4 unless `fields` say otherwise."
  def new_site(id, type, fields \\ []) do
    site = %Project{
      id: id,
      blueprint: Project.site_blueprint(),
      target: 4,
      gives: {:building, type}
    }

    struct!(site, fields)
  end

  @doc "A king's demand project for `good` with id `id`, target 10, due week 8 unless `fields` say otherwise."
  def new_demand_project(id, good, fields \\ []) do
    project = %Project{
      id: id,
      blueprint: Project.demand_blueprint(good),
      target: 10_000,
      gives: {:demand, 8}
    }

    struct!(project, fields)
  end

  @doc "A book of `colour` with id `id`, target 96 unless `fields` say otherwise."
  def new_book(id, colour, fields \\ []) do
    book = %Project{
      id: id,
      blueprint: Project.book_blueprint(),
      target: 96_000,
      gives: {:book, colour}
    }

    struct!(book, fields)
  end

  @doc """
  Opens a king's demand of `amount` `product` due in `due_week`; for knowledge and culture
  with its project among the places (`Demands.open_project/2`).
  """
  def open_demand(game, product, amount, due_week) do
    demand = %{product: product, amount: amount, due_week: due_week, project_id: nil}
    {places, demand} = Demands.open_project(game.places, demand)
    %{game | places: places, demand: demand}
  end

  @doc "The open demand's project, or `nil`."
  def demand_project(game), do: Demands.project(game.demand, game.places)

  @doc "A new game without king's demands, for tests about other rules."
  def game_without_demands(config, seed), do: %{Game.new(config, seed) | demand_weeks: []}

  @doc "Runs `count` weeks, paying every due tax and delivering every demand. Returns `{reports, game}`."
  def run_weeks(game, count) do
    Enum.map_reduce(1..count//1, game, fn _, game ->
      game = if Game.tax_decision_due?(game), do: decide!(game), else: game
      game = if Game.demand_decision_due?(game), do: deliver!(game), else: game
      {:ok, report, game} = Game.run_week(game)
      {report, game}
    end)
  end

  defp deliver!(game) do
    {:ok, game} = Game.decide_demand(game, true)
    game
  end

  defp decide!(game) do
    {:ok, game} = Game.decide_tax(game, true)
    game
  end
end
