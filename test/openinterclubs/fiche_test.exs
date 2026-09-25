defmodule OpenInterclubs.FicheTest do
  use ExUnit.Case, async: true

  alias OpenInterclubs.Fiche

  @series "test/fixtures/series_2A.json" |> File.read!() |> Jason.decode!()
  @club "test/fixtures/club_472.json" |> File.read!() |> Jason.decode!()

  test "finds the encounter for a team by pairing number, home or away" do
    assert {:ok, %{"icclub_home" => 472, "icclub_visit" => 402, "rdate" => "2026-09-27"}} =
             Fiche.find_encounter(@series, 2, 1)

    assert {:ok, %{"icclub_home" => 472}} = Fiche.find_encounter(@series, 11, 1)
    assert {:error, :no_encounter} = Fiche.find_encounter(@series, 2, 9)
  end

  test "starts blank; fill copies the KBSB lineup, clear removes it" do
    {:ok, enc} = Fiche.find_encounter(@series, 2, 1)
    fiche = Fiche.build(@series, 1, enc, @club["players"], [])
    assert Enum.all?(fiche.boards, &(&1.home == nil and &1.visit == nil))
    assert Fiche.api_lineup?(fiche, :home)
    refute Fiche.api_lineup?(fiche, :visit)

    fiche = Fiche.fill(fiche, :all)

    assert %Fiche{division: 2, index: "A", round: 1, date: "2026-09-27"} = fiche
    assert fiche.home.name == "de Mercatel 1"
    assert fiche.visit.name == "Jean Jaures Gent 1"
    assert length(fiche.boards) == 8

    assert %{board: 1, home: %{idnumber: 14108, name: "Goddé Matthias", rating: 2129}, visit: nil} =
             hd(fiche.boards)

    assert Enum.all?(Fiche.clear(fiche, :home).boards, &(&1.home == nil))
  end

  test "falls back to the division's board count when no lineup exists" do
    {:ok, enc} = Fiche.find_encounter(@series, 1, 1)
    fiche = Fiche.build(@series, 1, enc, [], [])
    assert length(fiche.boards) == 8
    assert Enum.all?(fiche.boards, &(&1.home == nil and &1.visit == nil))
  end

  test "set_player fills and clears a board" do
    {:ok, enc} = Fiche.find_encounter(@series, 2, 1)
    fiche = Fiche.build(@series, 1, enc, @club["players"], [])
    fiche = %{fiche | visit: %{fiche.visit | options: Fiche.player_options(@club["players"])}}

    fiche = Fiche.set_player(fiche, 3, :visit, 6530)

    assert %{visit: %{idnumber: 6530, name: "Coupe Rudy", rating: 1755}} =
             Enum.at(fiche.boards, 2)

    fiche = Fiche.set_player(fiche, 3, :visit, nil)
    assert %{visit: nil} = Enum.at(fiche.boards, 2)
  end

  test "merge_club_series only fills the logged-in club's own side" do
    {:ok, enc} = Fiche.find_encounter(@series, 2, 1)
    # The club endpoint answer contains BOTH sides' lineups.
    games = Enum.map(enc["games"], &Map.put(&1, "idnumber_visit", 6530))

    club_series = [
      put_in(@series, ["rounds"], [%{"round" => 1, "encounters" => [%{enc | "games" => games}]}])
    ]

    fiche = Fiche.build(@series, 1, %{enc | "games" => []}, @club["players"], @club["players"])

    fiche = %{
      fiche
      | home: %{fiche.home | options: Fiche.player_options(@club["players"])},
        visit: %{fiche.visit | options: Fiche.player_options(@club["players"])}
    }

    # Logged in as the home club (472): home filled, opponent never.
    own = fiche |> Fiche.merge_club_series(club_series, 472) |> Fiche.fill(:all)
    assert %{home: %{idnumber: 14108, name: "Goddé Matthias"}, visit: nil} = hd(own.boards)
    refute Fiche.api_lineup?(own, :visit)

    # Logged in as the visiting club (402): only its own side is taken.
    away = Fiche.merge_club_series(fiche, club_series, 402)
    refute Fiche.api_lineup?(away, :home)
    assert Fiche.api_lineup?(away, :visit)

    # A club that doesn't play this match gets nothing.
    other = Fiche.merge_club_series(fiche, club_series, 999)
    refute Fiche.api_lineup?(other, :home) or Fiche.api_lineup?(other, :visit)
  end
end
