defmodule NovyApi.AuthUser do
  use Ecto.Schema
  import Ecto.Changeset

  alias NovyApi.{User, AuthProvider, AuthUserSession}

  schema "auth_user" do
    field :auth_provider_user_id, :string
    field(:auth_provider_user_pseudo, :string)
    field(:auth_provider_user_img, :string)
    field(:user_data, :map)

    belongs_to(:user, User)
    belongs_to(:auth_provider, AuthProvider)

    timestamps()
  end

  def change_one(auth_user, attrs \\ %{}) do
    AuthUser.changeset(auth_user, attrs)
  end

  def changeset(auth_user, params \\ %{}) do
    auth_user
    |> cast(params, [
      :auth_provider_user_id,
      :auth_provider_user_img,
      :auth_provider_user_pseudo,
      :user_data
    ])
    |> validate_required([:auth_provider_user_id, :user_data])
  end
end
