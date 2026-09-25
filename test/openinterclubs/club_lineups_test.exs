defmodule OpenInterclubs.ClubLineupsTest do
  use ExUnit.Case, async: false

  alias OpenInterclubs.{ClubLineups, Fiche}

  @series "test/fixtures/series_2A.json" |> File.read!() |> Jason.decode!()
  @club "test/fixtures/club_472.json" |> File.read!() |> Jason.decode!()

  # de Mercatel 1 (472, home) vs Jean Jaures Gent 1 (402, away), round 1.
  setup do
    {:ok, enc} = Fiche.find_encounter(@series, 2, 1)
    fiche = Fiche.build(@series, 1, %{enc | "games" => []}, @club["players"], @club["players"])
    options = Fiche.player_options(@club["players"])

    fiche = %{
      fiche
      | home: %{fiche.home | options: options},
        visit: %{fiche.visit | options: options}
    }

    # Like the real endpoint: whatever idclub is asked, BOTH sides come back.
    games = Enum.map(enc["games"], &Map.put(&1, "idnumber_visit", 6530))

    series = [
      put_in(@series, ["rounds"], [%{"round" => 1, "encounters" => [%{enc | "games" => games}]}])
    ]

    %{fiche: fiche, series: series}
  end

  defp stub(series, managed) do
    test = self()

    Req.Test.stub(OpenInterclubs.Kbsb, fn conn ->
      case String.split(conn.request_path, "/", trim: true) do
        ["api", "v1", "clubs", "clb", "club", club, "access", _role] ->
          send(test, {:access_checked, String.to_integer(club)})
          Req.Test.json(conn, String.to_integer(club) in managed)

        ["api", "v1", "interclubs", "clb", "icseries"] ->
          send(test, {:series_requested, conn.query_string})
          Req.Test.json(conn, series)
      end
    end)
  end

  test "manager of the home club gets the home side only", %{fiche: fiche, series: series} do
    stub(series, [472])
    {fiche, access} = ClubLineups.apply(fiche, "tok")

    assert Fiche.api_lineup?(fiche, :home)
    refute Fiche.api_lineup?(fiche, :visit)
    assert access == %{472 => true, 402 => false}
    # The opponent's club is never requested.
    refute_received {:series_requested, "idclub=402" <> _}
  end

  test "manager of the away club gets the away side only", %{fiche: fiche, series: series} do
    stub(series, [402])
    {fiche, _} = ClubLineups.apply(fiche, "tok")

    refute Fiche.api_lineup?(fiche, :home)
    assert Fiche.api_lineup?(fiche, :visit)
  end

  test "no role for either club means no lineups at all", %{fiche: fiche, series: series} do
    stub(series, [703])
    {fiche, _} = ClubLineups.apply(fiche, "tok")

    refute Fiche.api_lineup?(fiche, :home) or Fiche.api_lineup?(fiche, :visit)
    refute_received {:series_requested, _}
  end

  test "access answers are memoized across fiches", %{fiche: fiche, series: series} do
    stub(series, [472])
    {_, access} = ClubLineups.apply(fiche, "tok")
    flush()
    ClubLineups.apply(fiche, "tok", access)
    refute_received {:access_checked, _}
  end

  test "without a token nothing is requested", %{fiche: fiche} do
    assert {^fiche, %{}} = ClubLineups.apply(fiche, nil)
  end

  defp flush do
    receive do
      _ -> flush()
    after
      0 -> :ok
    end
  end
end
