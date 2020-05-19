defmodule NovyApiWeb.DefaultView do
  use NovyApiWeb, :view

  def render("api-data.json", %{data: data}) do
    data
  end
end
