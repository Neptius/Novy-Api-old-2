defmodule NovyApiWeb.DefaultController do
  use NovyApiWeb, :controller

  def index(conn, _params) do
    render(conn, "api-data.json", data: %{"message" => "Hi, Tenno!"})
  end
end
