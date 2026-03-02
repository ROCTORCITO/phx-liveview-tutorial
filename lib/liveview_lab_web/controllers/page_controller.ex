defmodule LiveviewLabWeb.PageController do
  use LiveviewLabWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
