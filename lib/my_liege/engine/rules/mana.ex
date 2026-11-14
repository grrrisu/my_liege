defmodule MyLiege.Engine.Rules.Mana do
  @moduledoc """
  R3: mana per working worker per week: `mana_place_colour` in the place's colour and
  `mana_good_colour` in the colour of the home place of the place's good. A home place gives
  both to its own colour. The worker's own colour and training play no part. Only working
  workers (`Staffing.working/3`) make mana. A king's demand project (R7) has the colour of its
  good's home place, a book (R12) is blue knowledge, a way (R13) its own colour and good: a
  trader (R16) or hunter (R17) makes mana every week he is away.
  """

  alias MyLiege.Engine.{Config, Pentagon, Place}
  alias MyLiege.Engine.Place.{Blueprint, Building, Expedition, Project, Trade}
  alias MyLiege.Engine.Rules.Staffing

  @doc "The mana one working worker makes per week at `place`, per colour."
  def worker_mana(place, %Config{} = config)
      when is_struct(place, Building) or is_struct(place, Project) or is_struct(place, Trade) or
             is_struct(place, Expedition) do
    good_colour = place |> Place.good() |> Blueprint.home_colour()

    %{Place.colour(place) => config.mana_place_colour}
    |> Map.update(good_colour, config.mana_good_colour, &(&1 + config.mana_good_colour))
  end

  @doc "Total mana per colour in `week`, from the working workers."
  def produced(workers, places, week, %Config{} = config) do
    totals = Map.new(Pentagon.colours(), &{&1, 0})

    workers
    |> Staffing.working(places, week)
    |> Enum.reduce(totals, fn {_worker, place}, totals ->
      Map.merge(totals, worker_mana(place, config), fn _colour, total, mana ->
        total + mana
      end)
    end)
  end
end
