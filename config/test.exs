import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :openinterclubs, OpenInterclubsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "T8lh7mBLq6B2q+h3U/3wxfmFmZwZWclI/a2K1Namvx6IiYcISkgJ+3UWhzFvujNL",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

config :openinterclubs, season_autoload: false
