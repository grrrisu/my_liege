defmodule MyLiege do
  alias Sim.Realm.{CommandBus, SimulationLoop}

  @moduledoc """
  MyLiege keeps the contexts that define your domain
  and business logic.
  """
  def create(name) do
    send_command({:admin, :create, name: name})
  end

  def tick() do
    send_command({:sim, :tick})
  end

  def start_sim() do
    send_command({:admin, :start_sim})
  end

  def stop_sim() do
    send_command({:admin, :stop_sim})
  end

  def started?() do
    SimulationLoop.running?(MyLiege.Game.SimulationLoop)
  end

  def send_command(command) do
    :ok = CommandBus.dispatch(MyLiege.Game.CommandBus, command)
  end
end
