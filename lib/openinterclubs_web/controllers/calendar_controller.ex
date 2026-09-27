defmodule OpenInterclubsWeb.CalendarController do
  use OpenInterclubsWeb, :controller

  def team(conn, %{"id" => c, "number" => n}) do
    with {club, ""} <- Integer.parse(c),
         {number, ""} <- Integer.parse(String.replace_suffix(n, ".ics", "")),
         %{} = team <- OpenInterclubs.Season.team({club, number}) do
      filename = team.name |> String.replace(~r/[^A-Za-z0-9]+/, "_") |> Kernel.<>(".ics")

      conn
      |> put_resp_content_type("text/calendar")
      |> put_resp_header("content-disposition", ~s(inline; filename="#{filename}"))
      |> send_resp(200, OpenInterclubs.Calendar.team_ics({club, number}))
    else
      _ -> send_resp(conn, 404, "Onbekende ploeg")
    end
  end
end
