defmodule MyLiegeWeb.PageController do
  use MyLiegeWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
