defmodule NovyApi.AuthProvider do
  use Ecto.Schema

  import Ecto.Changeset

  alias NovyApi.{
    Repo,
    AuthProvider,
    AuthUser,
    AuthUserSession,
    AuthProviderConfig,
    AuthProviderSession
  }

  schema "auth_provider" do
    field(:label, :string)
    field(:method, :string)

    has_many(:auth_users, AuthUser)
    has_many(:auth_provider_configs, AuthProviderConfig)
    has_many(:auth_provider_sessions, AuthProviderSession)

    timestamps()
  end

  @doc false
  def get_by(params) do
    AuthProvider
    |> Repo.get_by(params)
  end

  @doc false
  def get_by(params, associations \\ []) do
    AuthProvider
    |> Repo.get_by(params)
    |> Repo.preload(associations)
  end
end
