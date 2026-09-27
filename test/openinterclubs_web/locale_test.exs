defmodule OpenInterclubsWeb.LocaleTest do
  use OpenInterclubsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    OpenInterclubs.Season.put(OpenInterclubs.SeasonFixtures.model())
    :ok
  end

  test "switching language translates the interface", %{conn: conn} do
    conn = get(conn, "/taal?lang=fr")
    assert redirected_to(conn) == "/"

    {:ok, _view, html} = conn |> recycle() |> live(~p"/divisions/4B")
    assert html =~ "Classement"
    assert html =~ "Série 4B"
    refute html =~ ">Rangschikking<"

    conn = conn |> recycle() |> get("/taal?lang=en")
    {:ok, _view, html} = conn |> recycle() |> live(~p"/divisions/4B")
    assert html =~ "Standings"
  end

  test "first visit follows the browser language", %{conn: conn} do
    conn = conn |> put_req_header("accept-language", "fr-BE,fr;q=0.9") |> get("/divisions/4B")
    assert html_response(conn, 200) =~ "Classement"
  end

  test "Dutch stays the default", %{conn: conn} do
    assert conn |> get("/divisions/4B") |> html_response(200) =~ "Rangschikking"
  end
end
