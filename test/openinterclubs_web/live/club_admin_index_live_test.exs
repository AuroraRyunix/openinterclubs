defmodule OpenInterclubsWeb.ClubAdminIndexLiveTest do
  use OpenInterclubsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    OpenInterclubs.Season.put(OpenInterclubs.SeasonFixtures.model())
    Req.Test.set_req_test_to_shared()
    :ok
  end

  defp stub(access) do
    Req.Test.stub(OpenInterclubs.Kbsb, fn conn ->
      case String.split(conn.request_path, "/", trim: true) do
        ["api", "v1", "member", "anon", "member", _] ->
          Req.Test.json(conn, %{"idclub" => 401})

        ["api", "v1", "clubs", "clb", "club", club, "access", _] ->
          if String.to_integer(club) in access,
            do: Req.Test.json(conn, true),
            else: conn |> Plug.Conn.put_status(403) |> Req.Test.json(%{})
      end
    end)
  end

  test "menu shows Clubbeheer only when logged in", %{conn: conn} do
    refute conn |> get("/rounds/1") |> html_response(200) =~ ~s(href="/mgmt")

    html =
      conn
      |> init_test_session(kbsb_token: "t", kbsb_user: "12345")
      |> get("/rounds/1")
      |> html_response(200)

    assert html =~ ~s(href="/mgmt")
  end

  test "opens the member's own club when the KBSB grants access", %{conn: conn} do
    stub([401])
    conn = init_test_session(conn, kbsb_token: "t", kbsb_user: "12345", kbsb_idnumber: 12345)
    {:ok, view, _} = live(conn, ~p"/mgmt")

    assert render_async(view) =~ "Gent"
    assert has_element?(view, "#own-club[href^='/mgmt/401/']")
  end

  test "no rights for the own club: offers the search instead", %{conn: conn} do
    stub([])
    conn = init_test_session(conn, kbsb_token: "t", kbsb_user: "12345", kbsb_idnumber: 12345)
    {:ok, view, _} = live(conn, ~p"/mgmt")

    render_async(view)
    assert has_element?(view, "#no-own-club")
    view |> element("#club-search-form") |> render_change(%{q: "merc"})
    assert render(view) =~ "/mgmt/472/"
  end

  test "asks to log in first", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/mgmt")
    assert html =~ "Meld je aan met je KBSB-login"
  end

  test "old /beheer links redirect to /mgmt", %{conn: conn} do
    assert conn |> get("/beheer") |> redirected_to() == "/mgmt"
    assert conn |> get("/beheer/703/2") |> redirected_to() == "/mgmt/703/2"
  end

  test "menu shows the member's name when logged in", %{conn: conn} do
    html =
      conn
      |> init_test_session(kbsb_token: "t", kbsb_user: "x@y.be", kbsb_name: "Jorian Burssens")
      |> get("/rounds/1")
      |> html_response(200)

    assert html =~ "Jorian Burssens"
    assert html =~ "Afmelden"
  end
end
