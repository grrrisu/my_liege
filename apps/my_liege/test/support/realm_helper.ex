defmodule MyLiege.RealmHelper do
  alias Sim.Realm.Data

  import MyLiege.MapAggregator

  def set_realm(state) do
    Data.set_data(MyLiege.Game.Data, state)
  end

  def change_realm(delta) do
    Data.update(MyLiege.Game.Data, fn current ->
      aggregate_map(current, delta)
    end)
  end
end
