defmodule NovyApiWeb.AuthController do
  use NovyApiWeb, :controller

  alias NovyApi.{AuthProviderSession, User, Repo}
  alias NovyApiWeb.UserService
  import Ecto.Query

  def init_auth(conn, %{"input" => %{"provider" => provider}}) do
    case UserService.init_auth(provider) do
      {:ok, url} ->
        render(conn, "api-data.json", data: %{"url" => url})

      {:error, message} ->
        render(conn, "api-error.json", message: "Provider invalide ou non configuré")
    end
  end

  def webhook(conn, _params) do
    hasura = authenticate(conn)
    render(conn, "webhook.json", hasura: hasura)
  end

  def authenticate(conn) do
    IO.inspect("AUTH")

    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, %AuthProviderSession{user: user}} <- UserService.session_by_token(token) do
      %{
        "X-Hasura-User-Id": Integer.to_string(user.id),
        "X-Hasura-Role": "admin",
        "X-Hasura-Token": "Bearer " <> token
      }
    else
      _ ->
        %{
          "X-Hasura-Role": "user"
        }
    end
  end
end
