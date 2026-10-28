defmodule MyLiegeWeb.PageController do
  use MyLiegeWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
