defmodule OpenInterclubsWeb.ExportController do
  @moduledoc "Excel (.xlsx) exports of the player lists, in the order shown on screen."
  use OpenInterclubsWeb, :controller

  alias OpenInterclubs.{Rankings, Season, TeamStats, Xlsx}
  import OpenInterclubsWeb.Fmt, only: [club_name: 1]

  @header [
    "#",
    "Stamnummer",
    "Naam",
    "Club",
    "Rating",
    "FIDE",
    "Gespeeld",
    "Score",
    "TPR",
    "+/-",
    "W-We"
  ]

  # Same filters as the Spelers page (min games, name, sort); all pages.
  def top(conn, params) do
    use_season(conn)

    filters = %{
      "min" => int(params["min"], 3),
      "sort" => if(params["sort"] in Rankings.sorts(), do: params["sort"], else: "tpr"),
      "q" => params["q"] || ""
    }

    send_xlsx(conn, "spelers", "Spelers", @header, player_rows(Rankings.list(filters)))
  end

  def club_players(conn, %{"id" => id}) do
    use_season(conn)

    with {club_id, ""} <- Integer.parse(id), %{} = club <- Season.club(club_id) do
      send_xlsx(
        conn,
        "#{slug(club.name)}_#{club.id}_spelers",
        club.name,
        @header,
        player_rows(Season.players(club.players))
      )
    else
      _ -> send_resp(conn, 404, "Onbekende club")
    end
  end

  def team_players(conn, %{"id" => c, "number" => n}) do
    use_season(conn)

    with {club, ""} <- Integer.parse(c),
         {number, ""} <- Integer.parse(n),
         %{} = team <- Season.team({club, number}) do
      header = ["#", "Stamnummer", "Naam", "Rating", "Borden", "Partijen", "Score"]

      rows =
        {club, number}
        |> TeamStats.lineup()
        |> Enum.with_index(1)
        |> Enum.map(fn {l, i} ->
          boards =
            l.boards
            |> Enum.sort()
            |> Enum.map_join(", ", fn {b, k} -> if k > 1, do: "#{b} (#{k}x)", else: "#{b}" end)

          [
            i,
            l.id,
            l.player && l.player.name,
            l.player && l.player.rating,
            boards,
            l.games,
            l.score
          ]
        end)

      send_xlsx(conn, "#{slug(team.name)}_spelers", team.name, header, rows)
    else
      _ -> send_resp(conn, 404, "Onbekende ploeg")
    end
  end

  # The row number is simply the position in the exported (displayed) order.
  defp player_rows(players) do
    players
    |> Enum.with_index(1)
    |> Enum.map(fn {p, i} ->
      [
        i,
        p.id,
        p.name,
        club_name(p.club_id),
        p.rating,
        p.fide,
        p.played,
        p.score,
        p.tpr,
        p.diff,
        p.w_we
      ]
    end)
  end

  defp send_xlsx(conn, filename, sheet, header, rows) do
    conn
    |> put_resp_content_type("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}.xlsx"))
    |> send_resp(200, Xlsx.build(sheet, header, rows))
  end

  defp use_season(conn), do: Season.use_season(get_session(conn, :season))

  defp int(v, default) do
    case Integer.parse(to_string(v || "")) do
      {n, _} -> n
      _ -> default
    end
  end

  defp slug(name) do
    name |> String.normalize(:nfd) |> String.replace(~r/[^A-Za-z0-9]+/, "_") |> String.trim("_")
  end
end
