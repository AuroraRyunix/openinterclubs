defmodule OpenInterclubsWeb.ExportTest do
  use OpenInterclubsWeb.ConnCase, async: false

  setup do
    OpenInterclubs.Season.put(OpenInterclubs.SeasonFixtures.model())
    :ok
  end

  defp unzip(binary) do
    {:ok, files} = :zip.unzip(binary, [:memory])
    Map.new(files, fn {name, data} -> {to_string(name), data} end)
  end

  test "club player list: row numbers 1,2,3, stamnummers, in displayed order", %{conn: conn} do
    conn = get(conn, "/export/clubs/401/spelers.xlsx")
    assert response(conn, 200)
    assert [type] = get_resp_header(conn, "content-type")
    assert type =~ "spreadsheetml.sheet"
    assert [disp] = get_resp_header(conn, "content-disposition")
    assert disp =~ "Gent_401_spelers.xlsx"

    sheet = conn.resp_body |> unzip() |> Map.fetch!("xl/worksheets/sheet1.xml")
    assert sheet =~ "Stamnummer"
    # rows are numbered 1..4 in order, with the stamnummer as a number
    assert sheet =~ ~s(<c r="A2"><v>1</v></c><c r="B2"><v>1</v></c>)
    assert sheet =~ ~s(<c r="A3"><v>2</v></c><c r="B3"><v>2</v></c>)
    assert sheet =~ "L1"
  end

  test "ranking export follows the page's filters", %{conn: conn} do
    body = conn |> get("/export/spelers.xlsx?min=2&sort=rating") |> response(200)
    sheet = body |> unzip() |> Map.fetch!("xl/worksheets/sheet1.xml")
    # only players with 2+ games, highest rating first: P1 (2000)
    assert sheet =~ ~s(<c r="B2"><v>1</v></c>)
    refute sheet =~ "L4"
  end

  test "team list and unknown club", %{conn: conn} do
    assert conn
           |> get("/export/clubs/401/teams/1/spelers.xlsx")
           |> response(200)
           |> unzip()
           |> Map.has_key?("xl/workbook.xml")

    assert conn |> get("/export/clubs/999/spelers.xlsx") |> response(404)
  end

  test "text is escaped" do
    xml =
      OpenInterclubs.Xlsx.build("A/B", ["x"], [["a < b & \"c\"", 1.5, nil]])
      |> unzip()
      |> Map.fetch!("xl/worksheets/sheet1.xml")

    assert xml =~ "a &lt; b &amp;"
    assert xml =~ "<v>1.5</v>"
  end
end
