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

  # `access` lists the clubs the KBSB access check allows (403 otherwise).
  defp stub(series, access) do
    test = self()

    Req.Test.stub(OpenInterclubs.Kbsb, fn conn ->
      case String.split(conn.request_path, "/", trim: true) do
        ["api", "v1", "clubs", "clb", "club", club, "access", _role] ->
          club = String.to_integer(club)
          send(test, {:access_checked, club})

          if club in access,
            do: Req.Test.json(conn, true),
            else: conn |> Plug.Conn.put_status(403) |> Req.Test.json(%{"detail" => "NoAccess"})

        ["api", "v1", "interclubs", "clb", "icseries"] ->
          send(test, {:series_requested, URI.decode_query(conn.query_string)["idclub"]})
          Req.Test.json(conn, series)
      end
    end)
  end

  defp filled_sides({:ok, fiche}), do: filled_sides(fiche)
  defp filled_sides({:error, _, fiche}), do: filled_sides(fiche)

  defp filled_sides(fiche) do
    for side <- [:home, :visit], Enum.any?(fiche.boards, &Map.get(&1, side)), do: side
  end

  test "access to the home club: only the home column is filled", %{fiche: f, series: s, user: u} do
    stub(s, [472])
    assert filled_sides(ClubLineups.fill(f, u, 472)) == [:home]
  end

  test "access to the away club: only the away column is filled", %{fiche: f, series: s, user: u} do
    stub(s, [402])
    assert filled_sides(ClubLineups.fill(f, u, 402)) == [:visit]
  end

  test "superuser with access to both: still only the selected club", %{
    fiche: f,
    series: s,
    user: u
  } do
    stub(s, [472, 402])
    assert filled_sides(ClubLineups.fill(f, u, 472)) == [:home]
    refute_received {:access_checked, 402}
    refute_received {:series_requested, "402"}
  end

  test "no access: error and nothing filled or requested", %{fiche: f, series: s, user: u} do
    stub(s, [])
    assert {:error, :no_access, ^f} = ClubLineups.fill(f, u, 472)
    refute_received {:series_requested, _}
  end

  test "selected club doesn't play this match: nothing", %{fiche: f, series: s, user: u} do
    stub(s, [703])
    assert {:error, :not_playing, ^f} = ClubLineups.fill(f, u, 703)
    refute_received {:access_checked, _}
  end

  test "not logged in: nothing", %{fiche: f} do
    assert {:error, :not_logged_in, ^f} = ClubLineups.fill(f, %{token: nil, idnumber: nil}, 472)
  end
end
