defmodule MyLiege.Service.Admin do
  @behaviour Sim.CommandHandler

  alias Sim.Realm.Data
  alias MyLiege.Service.Creation

  def execute(:create, name: name) do
    name |> Creation.create() |> set_data()
    [{:game_created, name: name}]
  end

  defp set_data(data) do
    Data.set_data(Game.Data, data)
  end
end
