defmodule MyLiege.Repo do
  use Ecto.Repo,
    otp_app: :my_liege,
    adapter: Ecto.Adapters.Postgres
end
