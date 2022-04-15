defmodule MyLiege.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      MyLiege.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: MyLiege.PubSub}
      # Start a worker by calling: MyLiege.Worker.start_link(arg)
      # {MyLiege.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MyLiege.Supervisor)
  end
end
