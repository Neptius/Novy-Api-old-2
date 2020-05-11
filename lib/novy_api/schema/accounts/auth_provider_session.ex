defmodule NovyApi.AuthProviderSession do
  use Ecto.Schema
  
  import Ecto.Changeset

  alias NovyApi.{Repo, AuthProvider, AuthProviderSession, User}

  schema "auth_provider_session" do
    field(:state, :string)
    field(:scope, :string)
    field(:verify, :boolean)
    field(:token, :string)
    field(:refresh_token, :string)
    field(:revoke, :boolean, default: false)

    belongs_to(:auth_provider, AuthProvider)
    belongs_to(:user, User)

    timestamps()
  end

  def change_one(auth_provider_session, attrs \\ %{}) do
    AuthProviderSession.changeset(auth_provider_session, attrs)
  end

  def changeset(auth_provider_session, params \\ %{}) do
    auth_provider_session
    |> cast(params, [:verify, :token, :refresh_token, :revoke])
    |> validate_required([])
  end

  @doc """
  Updates a auth_provider_session.
  ## Examples
      iex> update_one(auth_provider_session, %{field: new_value})
      {:ok, %AuthProviderSession{}}
      iex> update_one(auth_provider_session, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_one(%AuthProviderSession{} = auth_provider_session, attrs) do
    auth_provider_session
    |> AuthProviderSession.changeset(attrs)
    |> Repo.update()
  end
end
