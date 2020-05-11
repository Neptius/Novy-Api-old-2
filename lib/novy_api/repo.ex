defmodule NovyApi.Repo do
  use Ecto.Repo,
    otp_app: :novy_api,
    adapter: Ecto.Adapters.Postgres
end
