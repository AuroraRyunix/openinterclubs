defmodule OpenInterclubsWeb.Locale do
  @moduledoc """
  Sets the interface language per request/LiveView from the session
  ("locale"), falling back to the browser's Accept-Language for first visits.
  """
  import Plug.Conn
  alias OpenInterclubsWeb.I18n

  # Plug for controllers and the first (dead) render.
  def init(opts), do: opts

  def call(conn, _opts) do
    locale = get_session(conn, "locale") || from_header(conn)
    I18n.put_locale(locale)
    conn |> put_session("locale", I18n.locale()) |> assign(:locale, I18n.locale())
  end

  # LiveView on_mount hook.
  def on_mount(:default, _params, session, socket) do
    I18n.put_locale(session["locale"])
    {:cont, Phoenix.Component.assign(socket, :locale, I18n.locale())}
  end

  defp from_header(conn) do
    conn
    |> get_req_header("accept-language")
    |> List.first("")
    |> String.downcase()
    |> then(fn h -> Enum.find(["fr", "en", "nl"], &String.starts_with?(h, &1)) end)
  end
end
