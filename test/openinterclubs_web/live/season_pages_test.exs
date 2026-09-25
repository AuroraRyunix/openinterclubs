defmodule OpenInterclubsWeb.SeasonPagesTest do
  use OpenInterclubsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    # The club page fetches venues in a background task.
    Req.Test.set_req_test_to_shared()
    Req.Test.stub(OpenInterclubs.Kbsb, &Req.Test.json(&1, %{"venues" => []}))
    OpenInterclubs.Season.put(OpenInterclubs.SeasonFixtures.model())
    :ok
  end

  test "home searches clubs and players", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/")
    view |> element("#search-form") |> render_change(%{q: "merc"})
    assert has_element?(view, "#search-results a[href='/clubs/472']")

    view |> element("#search-form") |> render_change(%{q: "L11"})
    assert has_element?(view, "#search-results a[href='/players/11']")
  end

  test "round page lists encounters per series", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/rounds/1")
    assert has_element?(view, "#series-4B a[href='/match/4B/1/401/1']")
  end

  test "division standings, crosstable and rounds", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/divisions/4B")
    assert has_element?(view, "#standings a[href='/clubs/401/teams/1']")

    {:ok, view, _} = live(conn, ~p"/divisions/4B?tab=kruistabel")
    assert has_element?(view, "#crosstable a[href='/match/4B/1/401/1']")
  end

  test "match page shows boards and links to the fiche", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/match/4B/1/401/1")
    assert has_element?(view, "#boards a[href='/players/1']")
    assert has_element?(view, "#to-fiche")
  end

  test "club, team and player pages", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/clubs/401")
    assert has_element?(view, "#teams a[href='/clubs/401/teams/1']")

    {:ok, view, _} = live(conn, ~p"/clubs/401/teams/1?tab=spelers&board=1")
    assert has_element?(view, "#lineup a[href='/players/1']")
    refute has_element?(view, "#lineup a[href='/players/2']")

    {:ok, view, _} = live(conn, ~p"/players/1")
    assert has_element?(view, "#games a[href='/players/21']")
  end

  test "top list filters by minimum games", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/top?min=2")
    assert has_element?(view, "#ranking a[href='/players/1']")
    refute has_element?(view, "#ranking a[href='/players/4']")
  end

  test "pages re-render when the season updates", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/players/1")
    OpenInterclubs.Season.put(OpenInterclubs.SeasonFixtures.model())
    assert render(view) =~ "2450"
  end
end
