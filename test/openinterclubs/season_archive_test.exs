defmodule OpenInterclubs.SeasonArchiveTest do
  use ExUnit.Case, async: false

  alias OpenInterclubs.Season
  alias OpenInterclubs.Season.Archive

  test "per-round archive answers are merged into whole series" do
    part = fn round ->
      %{"division" => 4, "index" => "B", "teams" => [:t], "rounds" => [%{"round" => round}]}
    end

    assert [%{"division" => 4, "index" => "B", "teams" => [:t], "rounds" => rounds}] =
             Archive.merge_series([part.(2), part.(1)])

    assert Enum.map(rounds, & &1["round"]) == [1, 2]
  end

  test "labels" do
    assert Archive.label("2526") == "2025-26"
  end

  test "a process can read an archived season without affecting others" do
    model = OpenInterclubs.SeasonFixtures.model()
    Season.put(model)
    Season.put(%{model | clubs: Map.take(model.clubs, [401])}, "2526")

    assert map_size(Season.clubs()) == 3

    Season.use_season("2526")
    assert Season.selected() == "2526"
    assert Map.keys(Season.clubs()) == [401]
    assert Season.player(1).name == "P1 L1"

    Season.use_season("current")
    assert map_size(Season.clubs()) == 3

    # unknown seasons fall back to the current one
    Season.use_season("1999")
    assert Season.selected() == nil
  end
end
