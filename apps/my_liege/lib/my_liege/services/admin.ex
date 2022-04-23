defmodule MyLiege.Service.Admin do
  use Sim.Commands.SimHelpers, app_module: MyLiege.Game
  @behaviour Sim.CommandHandler

  alias Sim.Realm.Data
  alias MyLiege.Game

  def execute(:create, name: name) do
    name |> Game.create() |> set_data()
    [{:game_created, name: name}]
  end

  def execute(:start_sim, []) do
    start_simulation_loop(1_000, &MyLiege.tick/0)
    [{:sim_started, started: true}]
  end

  def execute(:stop_sim, []) do
    stop_simulation_loop()
    [{:sim_started, started: false}]
  end

  defp set_data(data) do
    Data.set_data(Game.Data, data)
  end
end
