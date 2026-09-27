defmodule OpenInterclubs.HeadToHeadTest do
  use ExUnit.Case, async: false

  alias OpenInterclubs.{HeadToHead, Season}

  test "encounters between two clubs with totals from club a's side" do
    model = OpenInterclubs.SeasonFixtures.model()
    Season.put(model)
    # Pretend the archived seasons are loaded and identical.
    for s <- OpenInterclubs.Season.Archive.seasons(), do: Season.put(model, s)

    seasons = HeadToHead.between(472, 401)
    assert length(seasons) == 4
    assert [%{season: nil, encounters: [e]} | _] = seasons
    assert %{home_name: "Gent 1", visit_name: "Mercatel 2", a_bp: 1.5, b_bp: 2.5, a_mp: 0} = e

    assert %{won: 0, lost: 4, a_bp: 6.0, b_bp: 10.0} = HeadToHead.totals(seasons)
    assert Season.selected() == nil
  end
end
