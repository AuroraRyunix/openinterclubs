defmodule OpenInterclubs.SeasonIntervalTest do
  use ExUnit.Case, async: false

  alias OpenInterclubs.Season

  setup do
    Season.put(%{
      OpenInterclubs.SeasonFixtures.model()
      | rounds: [%{round: 1, date: ~D[2026-09-27]}]
    })

    :ok
  end

  test "every minute on a round date between 14:00 and 20:00 Belgian time" do
    # 27/09 is summer time: 14:00 CEST = 12:00 UTC
    assert Season.interval(~U[2026-09-27 12:00:00Z]) == :timer.minutes(1)
    assert Season.interval(~U[2026-09-27 17:59:00Z]) == :timer.minutes(1)
    assert Season.interval(~U[2026-09-27 11:59:00Z]) == :timer.minutes(5)
    assert Season.interval(~U[2026-09-27 18:00:00Z]) == :timer.minutes(5)
  end

  test "every 5 minutes on days without a round" do
    assert Season.interval(~U[2026-09-28 15:00:00Z]) == :timer.minutes(5)
  end
end
