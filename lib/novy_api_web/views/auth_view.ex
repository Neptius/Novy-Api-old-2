defmodule NovyApiWeb.AuthView do
  use NovyApiWeb, :view

  def render("api-data.json", %{data: data}) do
    data
  end

  def render("webhook.json", %{hasura: hasura}) do
    hasura
  end

  def render("api-error.json", %{message: message}) do
    %{message: message}
  end

end
