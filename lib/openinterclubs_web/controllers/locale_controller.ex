defmodule OpenInterclubsWeb.LocaleController do
  use OpenInterclubsWeb, :controller

  def select(conn, %{"lang" => lang}) do
    lang = if lang in OpenInterclubsWeb.I18n.locales(), do: lang, else: "nl"

    back =
      with [ref | _] <- get_req_header(conn, "referer"),
           %URI{path: "/" <> _ = path, query: q} <- URI.parse(ref),
           false <- String.starts_with?(path, "/taal") do
        if q, do: path <> "?" <> q, else: path
      else
        _ -> "/"
      end

    conn |> put_session("locale", lang) |> redirect(to: back)
  end
end
