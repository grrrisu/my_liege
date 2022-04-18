defmodule MyLiege.Service.Admin do
  @behaviour Sim.CommandHandler

  alias Sim.Realm.Data
  alias MyLiege.Game

  def execute(:create, name: name) do
    name |> Game.create() |> set_data()
    [{:game_created, name: name}]
  end

  defp set_data(data) do
    Data.set_data(Game.Data, data)
  end
end
