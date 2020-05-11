defmodule NovyApi.AuthProviderConfig do
  use Ecto.Schema

  alias NovyApi.{AuthProvider}

  schema "auth_provider_config" do
    field(:key, :string)
    field(:value, :string)

    belongs_to(:auth_provider, AuthProvider)

    timestamps()
  end
end
