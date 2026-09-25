defmodule OpenInterclubsWeb.SessionController do
  use OpenInterclubsWeb, :controller

  alias OpenInterclubs.Kbsb

  def new(conn, _params) do
    render(conn, :new,
      user: get_session(conn, :kbsb_user),
      error: nil,
      return_to: return_to(conn)
    )
  end

  def create(conn, %{"user" => user, "password" => password} = params) do
    case Kbsb.login(user, password) do
      {:ok, token} ->
        conn
        |> configure_session(renew: true)
        |> put_session(:kbsb_token, token)
        |> put_session(:kbsb_user, String.trim(user))
        |> put_flash(:info, "Aangemeld bij de KBSB.")
        |> redirect(to: safe_return(params["return_to"]))

      {:error, reason} ->
        conn
        |> put_status(401)
        |> render(:new,
          user: nil,
          error: describe(reason),
          return_to: safe_return(params["return_to"])
        )
    end
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Afgemeld.")
    |> redirect(to: ~p"/fiche")
  end

  defp describe("WrongUsernamePasswordCombination"), do: "Verkeerd lidnummer of wachtwoord."
  defp describe(reason) when is_binary(reason), do: "KBSB: #{reason}"
  defp describe(reason), do: "Aanmelden mislukt (#{inspect(reason)})."

  defp return_to(conn), do: safe_return(conn.params["return_to"])

  # Only allow local paths, never redirect off-site.
  defp safe_return("/" <> _ = path) do
    if String.starts_with?(path, ["//", "/\\"]), do: ~p"/fiche", else: path
  end

  defp safe_return(_), do: ~p"/fiche"
end
