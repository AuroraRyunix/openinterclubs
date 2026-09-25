defmodule OpenInterclubsWeb.Fmt do
  @moduledoc "Formatting and path helpers shared by the season pages."

  alias OpenInterclubs.Season

  def points(nil), do: "–"

  def points(p) when is_float(p) do
    whole = trunc(p)
    half = p - whole >= 0.5

    cond do
      half and whole == 0 -> "½"
      half -> "#{whole}½"
      true -> "#{whole}"
    end
  end

  def points(p), do: to_string(p)

  def date(nil), do: ""
  def date(%Date{} = d), do: Calendar.strftime(d, "%d/%m/%Y")

  @days ~w(ma di wo do vr za zo)
  def short_date(nil), do: ""

  def short_date(%Date{} = d),
    do: "#{Enum.at(@days, Date.day_of_week(d) - 1)} #{Calendar.strftime(d, "%d/%m")}"

  def team_name({_, _} = key) do
    case Season.team(key) do
      %{name: n} -> n
      _ -> "?"
    end
  end

  def team_name(_), do: "?"

  def player_name(nil), do: "—"

  def player_name(id) do
    case Season.player(id) do
      %{name: n} -> n
      _ -> "##{id}"
    end
  end

  def series_slug({1, _}), do: "1"
  def series_slug({d, i}), do: "#{d}#{i}"

  def parse_series("1"), do: {1, ""}

  def parse_series(slug) do
    case Integer.parse(slug) do
      {d, idx} when idx != "" -> {d, String.upcase(idx)}
      _ -> nil
    end
  end

  def series_path(key), do: "/divisions/#{series_slug(key)}"
  def team_path({club, n}), do: "/clubs/#{club}/teams/#{n}"
  def club_path(id), do: "/clubs/#{id}"
  def player_path(id), do: "/players/#{id}"

  def match_path(%{series: s, round: r, home: {c, n}}),
    do: "/match/#{series_slug(s)}/#{r}/#{c}/#{n}"

  def fiche_path(%{round: r, home: home}, side \\ :home) do
    _ = side
    team = Season.team(home)
    club = if team, do: team.club_id

    "/fiche?" <>
      URI.encode_query(%{club: club, team: team && team.name, round: r})
  end

  def division_name(1), do: "Eerste afdeling"
  def division_name(n), do: "Afdeling #{n}"

  def rating(0), do: "–"
  def rating(nil), do: "–"
  def rating(r), do: to_string(r)
end
