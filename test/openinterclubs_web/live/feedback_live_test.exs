defmodule OpenInterclubsWeb.FeedbackLiveTest do
  use OpenInterclubsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "builds a pre-filled GitHub issue link", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/feedback")
    refute has_element?(view, "#send-feedback")

    view
    |> element("#feedback-form")
    |> render_change(%{f: %{kind: "bug", text: "Stand klopt niet\nin 2A", page: "/divisions/2A"}})

    [href] =
      view
      |> element("#send-feedback")
      |> render()
      |> then(&Regex.run(~r/href="([^"]+)"/, &1, capture: :all_but_first))

    href = String.replace(href, "&amp;", "&")
    query = href |> URI.parse() |> Map.get(:query) |> URI.decode_query()
    assert href =~ "github.com/AuroraRyunix/openinterclubs/issues/new"
    assert query["title"] == "[bug] Stand klopt niet"
    assert query["body"] =~ "Pagina: /divisions/2A"
  end
end
