defmodule OpenInterclubs.CalendarTest do
  use OpenInterclubsWeb.ConnCase, async: false

  setup do
    OpenInterclubs.Season.put(OpenInterclubs.SeasonFixtures.model())
    OpenInterclubs.Kbsb.Cache.clear()
    :ok
  end

  test "one event per round, 14:00 Brussels time, with the home club's venue" do
    ics =
      OpenInterclubs.Calendar.team_ics({401, 1}, fn club, round -> "Zaal #{club} R#{round}" end)

    assert ics =~ "BEGIN:VCALENDAR"
    assert ics =~ "X-WR-CALNAME:Gent 1"
    assert length(String.split(ics, "BEGIN:VEVENT")) - 1 == 2
    assert ics =~ "DTSTART;TZID=Europe/Brussels:20260927T140000"
    assert ics =~ "SUMMARY:R1: Gent 1 – Mercatel 2"
    # round 2 is played at Borgerhout (home team)
    assert ics =~ "LOCATION:Zaal 109 R2"
    assert ics =~ "\r\n"
  end

  test "served as text/calendar; unknown team is 404", %{conn: conn} do
    Req.Test.stub(
      OpenInterclubs.Kbsb,
      &Req.Test.json(&1, %{"venues" => [%{"address" => "Straat 1\n9000 Gent", "rounds" => ["1"]}]})
    )

    Req.Test.set_req_test_to_shared()

    conn1 = get(conn, "/clubs/401/teams/1/calendar.ics")

    assert response_content_type(conn1, :ics) =~ "text/calendar" or
             conn1.resp_headers
             |> Enum.any?(fn {k, v} -> k == "content-type" and v =~ "text/calendar" end)

    assert response(conn1, 200) =~ "LOCATION:Straat 1\\, 9000 Gent"

    assert get(conn, "/clubs/999/teams/1/calendar.ics") |> response(404)
  end
end
