defmodule NovyApiWeb.Router do
  use NovyApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api/v1", NovyApiWeb do
    pipe_through :api
    get "/auth/webhook", AuthController, :webhook
    post "/auth/init", AuthController, :init_auth
  end
end
