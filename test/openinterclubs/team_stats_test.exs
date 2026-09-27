defmodule OpenInterclubs.TeamStatsTest do
  use ExUnit.Case, async: false

  setup do
    OpenInterclubs.Season.put(OpenInterclubs.SeasonFixtures.model())
    :ok
  end

  test "board and player statistics over played games" do
    %{boards: boards, players: players} = OpenInterclubs.TeamStats.for_team({401, 1})

    # Gent 1 played 4 boards in round 1 and 1 board (so far) in round 2.
    assert %{board: 1, games: 2, score: 2.0, own_rating: 2000} = hd(boards)
    # board 4 was a forfeit win: no ratings counted
    assert %{board: 4, games: 1, own_rating: nil} = List.last(boards)

    assert %{id: 1, games: 2, white: 1, black: 1, score: 2.0, avg_board: 1.0} = hd(players)
  end
end
