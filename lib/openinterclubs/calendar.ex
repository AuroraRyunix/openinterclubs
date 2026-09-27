defmodule OpenInterclubs.Calendar do
  @moduledoc "iCalendar (.ics) feed with all matches of one team."

  alias OpenInterclubs.Kbsb
  alias OpenInterclubs.Season

  @doc "Builds the .ics for a team key; venues are looked up per home club."
  def team_ics(team_key, venue_fun \\ &venue/2) do
    team = Season.team(team_key)

    events =
      for e <- Season.team_encounters(team_key), e.date do
        home = Season.team(e.home)
        visit = Season.team(e.visit)
        location = venue_fun.(home && home.club_id, e.round)

        event(
          uid:
            "#{elem(e.series, 0)}#{elem(e.series, 1)}-r#{e.round}-#{elem(e.home, 0)}-#{elem(e.home, 1)}@openinterclubs",
          date: e.date,
          summary: "R#{e.round}: #{home && home.name} – #{visit && visit.name}",
          location: location
        )
      end

    """
    BEGIN:VCALENDAR\r
    VERSION:2.0\r
    PRODID:-//OpenInterclubs//NL\r
    CALSCALE:GREGORIAN\r
    X-WR-CALNAME:#{escape(team && team.name)}\r
    #{vtimezone()}#{Enum.join(events)}END:VCALENDAR\r
    """
  end

  # Interclub rounds start at 14:00 Belgian time.
  defp event(opts) do
    d = Calendar.strftime(opts[:date], "%Y%m%d")

    """
    BEGIN:VEVENT\r
    UID:#{opts[:uid]}\r
    DTSTAMP:#{Calendar.strftime(DateTime.utc_now(), "%Y%m%dT%H%M%SZ")}\r
    DTSTART;TZID=Europe/Brussels:#{d}T140000\r
    DTEND;TZID=Europe/Brussels:#{d}T190000\r
    SUMMARY:#{escape(opts[:summary])}\r
    #{if opts[:location], do: "LOCATION:#{escape(opts[:location])}\r\n", else: ""}END:VEVENT\r
    """
  end

  defp vtimezone do
    """
    BEGIN:VTIMEZONE\r
    TZID:Europe/Brussels\r
    BEGIN:DAYLIGHT\r
    TZOFFSETFROM:+0100\r
    TZOFFSETTO:+0200\r
    TZNAME:CEST\r
    DTSTART:19700329T020000\r
    RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU\r
    END:DAYLIGHT\r
    BEGIN:STANDARD\r
    TZOFFSETFROM:+0200\r
    TZOFFSETTO:+0100\r
    TZNAME:CET\r
    DTSTART:19701025T030000\r
    RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU\r
    END:STANDARD\r
    END:VTIMEZONE\r
    """
  end

  @doc "Address of the home club's venue for a round (public data)."
  def venue(nil, _round), do: nil

  def venue(idclub, round) do
    with {:ok, %{"venues" => [_ | _] = venues}} <- Kbsb.venue(idclub) do
      v = Enum.find(venues, hd(venues), &(to_string(round) in (&1["rounds"] || [])))

      v["address"]
      |> to_string()
      |> String.split("\n", trim: true)
      |> Enum.map_join(", ", &String.trim/1)
    else
      _ -> nil
    end
  end

  defp escape(nil), do: ""

  defp escape(s),
    do:
      s
      |> to_string()
      |> String.replace("\\", "\\\\")
      |> String.replace(",", "\\,")
      |> String.replace(";", "\;")
      |> String.replace("\n", "\\n")
end
