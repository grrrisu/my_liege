defmodule MyLiege do
  alias Sim.Realm.CommandBus

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

  defp send_command(command) do
    CommandBus.dispatch(MyLiege.Game.CommandBus, command)
  end
end
