import Config

database_url =
  System.get_env("DATABASE_URL_TEST") ||
    raise """
    environment variable DATABASE_URL_TEST is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

# Configure your database
config :novy_api, NovyApi.Repo,
  url: database_url,
  show_sensitive_data_on_connection_error: true,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :novy_api, NovyApiWeb.Endpoint,
  http: [port: 10000],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn
