defmodule OpenInterclubs.ClubLineupsTest do
  use ExUnit.Case, async: false

  alias OpenInterclubs.{ClubLineups, Fiche}

  @series "test/fixtures/series_2A.json" |> File.read!() |> Jason.decode!()
  @club "test/fixtures/club_472.json" |> File.read!() |> Jason.decode!()
  @me 777

  # de Mercatel 1 (472, home) vs Jean Jaures Gent 1 (402, away), round 1.
  setup do
    OpenInterclubs.Kbsb.Cache.clear()
    {:ok, enc} = Fiche.find_encounter(@series, 2, 1)
    fiche = Fiche.build(@series, 1, %{enc | "games" => []}, @club["players"], @club["players"])
    options = Fiche.player_options(@club["players"])

    fiche = %{
      fiche
      | home: %{fiche.home | options: options},
        visit: %{fiche.visit | options: options}
    }

    # Like the real club endpoint: BOTH sides' lineups come back.
    games = Enum.map(enc["games"], &Map.put(&1, "idnumber_visit", 6530))

    series = [
      put_in(@series, ["rounds"], [%{"round" => 1, "encounters" => [%{enc | "games" => games}]}])
    ]

    %{fiche: fiche, series: series, user: %{token: "tok", idnumber: @me}}
  end

  # `roles` maps idclub => member numbers with a club role (nil = the club
  # publishes no role list); `access` lists clubs the KBSB check says yes to.
  defp stub(series, roles, access \\ []) do
    test = self()

    Req.Test.stub(OpenInterclubs.Kbsb, fn conn ->
      case String.split(conn.request_path, "/", trim: true) do
        ["api", "v1", "clubs", "anon", "club", club] ->
          roles =
            case Map.get(roles, String.to_integer(club), []) do
              nil -> nil
              members -> [%{"nature" => "InterclubAdmin", "memberlist" => members}]
            end

          Req.Test.json(conn, %{"clubroles" => roles})

        ["api", "v1", "clubs", "clb", "club", club, "access", _role] ->
          send(test, {:access_checked, String.to_integer(club)})
          Req.Test.json(conn, String.to_integer(club) in access)

        ["api", "v1", "interclubs", "clb", "icseries"] ->
          send(test, {:series_requested, URI.decode_query(conn.query_string)["idclub"]})
          Req.Test.json(conn, series)
      end
    end)
  end

  defp filled_sides(fiche) do
    for side <- [:home, :visit], Enum.any?(fiche.boards, &Map.get(&1, side)), do: side
  end

  test "home club manager: only the home column is filled", %{fiche: f, series: s, user: u} do
    stub(s, %{472 => [@me]})
    assert filled_sides(ClubLineups.fill(f, u, 472)) == [:home]
  end

  test "away club manager: only the away column is filled", %{fiche: f, series: s, user: u} do
    stub(s, %{402 => [@me]})
    assert filled_sides(ClubLineups.fill(f, u, 402)) == [:visit]
  end

  test "managing both clubs still only fills the club being viewed", %{
    fiche: f,
    series: s,
    user: u
  } do
    stub(s, %{472 => [@me], 402 => [@me]})
    assert filled_sides(ClubLineups.fill(f, u, 472)) == [:home]
    refute_received {:series_requested, "402"}
  end

  test "not listed in the club's roles: nothing requested, nothing filled", %{
    fiche: f,
    series: s,
    user: u
  } do
    stub(s, %{472 => [1, 2, 3]})
    assert filled_sides(ClubLineups.fill(f, u, 472)) == []
    refute_received {:series_requested, _}
  end

  test "a club that doesn't play this match gets nothing", %{fiche: f, series: s, user: u} do
    stub(s, %{703 => [@me]})
    assert filled_sides(ClubLineups.fill(f, u, 703)) == []
  end

  test "no login: nothing", %{fiche: f} do
    assert ClubLineups.fill(f, %{token: nil, idnumber: nil}, 472) == f
  end

  test "club without a public role list falls back to the KBSB check", %{
    fiche: f,
    series: s,
    user: u
  } do
    # Like Eisden (703): clubroles is null, the access check says yes.
    stub(s, %{472 => nil}, [472])
    assert filled_sides(ClubLineups.fill(f, u, 472)) == [:home]

    # Only the viewed club is ever checked, never the opponent.
    assert_received {:access_checked, 472}
    refute_received {:access_checked, 402}
  end

  test "no role list and the KBSB says no: nothing", %{fiche: f, series: s, user: u} do
    stub(s, %{472 => nil}, [])
    assert filled_sides(ClubLineups.fill(f, u, 472)) == []
    refute_received {:series_requested, _}
  end
end
