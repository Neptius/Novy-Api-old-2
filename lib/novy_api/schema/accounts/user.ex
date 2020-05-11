defmodule NovyApi.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias NovyApi.{Repo, AuthUser, AuthProviderSession}

  schema "user" do
    field(:pseudo, :string)

    belongs_to(:auth_user_default, AuthUser)

    has_many(:auth_users, AuthUser)
    has_many(:auth_provider_sessions, AuthProviderSession)

    timestamps()
  end

  @doc false
  def get_by_id(id) do
    User
    |> Repo.get!(id)
  end

  def changeset(user, params \\ %{}) do
    user
    |> cast(params, [:pseudo, :auth_user_default_id])
    |> validate_required([:pseudo, :auth_user_default_id])
  end
end
