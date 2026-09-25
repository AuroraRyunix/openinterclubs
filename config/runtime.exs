import Config

# Optional outbound HTTP proxy for KBSB API calls (HTTPS_PROXY=http://host:port),
# with an optional extra CA bundle for TLS-intercepting proxies (KBSB_CACERTFILE).
if proxy = System.get_env("HTTPS_PROXY") || System.get_env("https_proxy") do
  %URI{scheme: scheme, host: host, port: port} = URI.parse(proxy)

  connect_options =
    [proxy: {String.to_existing_atom(scheme), host, port, []}] ++
      case System.get_env("KBSB_CACERTFILE") do
        nil -> []
        file -> [transport_opts: [cacertfile: file]]
      end

  config :openinterclubs, :kbsb_req_options, connect_options: connect_options
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/openinterclubs start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :openinterclubs, OpenInterclubsWeb.Endpoint, server: true
end

config :openinterclubs, OpenInterclubsWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :openinterclubs, OpenInterclubsWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$",
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/openinterclubs_web/router\.ex$",
        ~r"lib/openinterclubs_web/(controllers|live|components)/.*\.(ex|heex)$"
      ]
    ]
end

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :openinterclubs, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :openinterclubs, OpenInterclubsWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    # Accept LiveView connections on PHX_HOST and on the platform's own
    # hostname (Render sets RENDER_EXTERNAL_HOSTNAME automatically).
    check_origin:
      Enum.map(
        [host, System.get_env("RENDER_EXTERNAL_HOSTNAME")] |> Enum.reject(&is_nil/1),
        &"//#{&1}"
      ),
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://bandit.hexdocs.pm/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :openinterclubs, OpenInterclubsWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :openinterclubs, OpenInterclubsWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
