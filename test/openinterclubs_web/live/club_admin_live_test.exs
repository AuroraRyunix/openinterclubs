defmodule OpenInterclubsWeb.ClubAdminLiveTest do
  use OpenInterclubsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @series "test/fixtures/series_2A.json" |> File.read!() |> Jason.decode!()
  @club "test/fixtures/club_472.json" |> File.read!() |> Jason.decode!()

  setup do
    OpenInterclubs.Kbsb.Cache.clear()
    Req.Test.set_req_test_to_shared()
    :ok
  end

  defp series(date),
    do: [put_in(@series, ["rounds"], [%{hd(@series["rounds"]) | "rdate" => date}])]

  # `access`: clubs the KBSB grants; `errors`: validation answer.
  defp stub(opts) do
    test = self()
    access = Keyword.get(opts, :access, [472])
    date = Keyword.get(opts, :date, "2099-01-01")
    errors = Keyword.get(opts, :errors, [])

    Req.Test.stub(OpenInterclubs.Kbsb, fn conn ->
      case {conn.method, String.split(conn.request_path, "/", trim: true)} do
        {"GET", ["api", "v1", "clubs", "clb", "club", club, "access", _]} ->
          if String.to_integer(club) in access,
            do: Req.Test.json(conn, true),
            else: conn |> Plug.Conn.put_status(403) |> Req.Test.json(%{"detail" => "no"})

        {"GET", ["api", "v1", "interclubs", "clb", "icseries"]} ->
          Req.Test.json(conn, series(date))

        {"GET", ["api", "v1", "interclubs", "anon", "icclub", _]} ->
          Req.Test.json(conn, @club)

        {"PUT", ["api", "v1", "interclubs", "clb", path]} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          send(test, {:put, path, Jason.decode!(body)})
          Req.Test.json(conn, if(path == "icplanningvalidate", do: errors, else: nil))
      end
    end)
  end

  defp login(conn), do: init_test_session(conn, kbsb_token: "tok")

  test "asks to log in first", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/beheer/472/1")
    assert html =~ "aan met je KBSB-login"
  end

  test "no access: refused, nothing loaded", %{conn: conn} do
    stub(access: [])
    {:ok, view, _} = live(login(conn), ~p"/beheer/472/1")
    assert has_element?(view, "#forbidden")
    refute_received {:put, _, _}
  end

  test "shows the club's team with its lineup and checks it with the KBSB", %{conn: conn} do
    stub(
      errors: [
        %{
          "division" => 2,
          "index" => "A",
          "pnr_offender" => 2,
          "boardnr" => 3,
          "errormessage" => "ELO order"
        }
      ]
    )

    {:ok, view, _} = live(login(conn), ~p"/beheer/472/1")

    assert has_element?(view, "#team-2A-2")
    view |> element("#validate") |> render_click()

    assert_received {:put, "icplanningvalidate",
                     %{"idclub" => 472, "round" => 1, "plannings" => [plan]}}

    assert %{"playinghome" => true, "games" => [%{"idnumber_home" => 14108} | _]} = plan
    html = render(view)
    assert html =~ "ELO order" and html =~ "Bord 3"
  end

  test "submit only saves when the KBSB finds no errors", %{conn: conn} do
    stub(
      errors: [
        %{
          "division" => 2,
          "index" => "A",
          "pnr_offender" => 2,
          "boardnr" => 1,
          "errormessage" => "x"
        }
      ]
    )

    {:ok, view, _} = live(login(conn), ~p"/beheer/472/1")
    view |> element("#submit") |> render_click()
    refute_received {:put, "icplanning", _}

    stub(errors: [])
    view |> element("#submit") |> render_click()
    assert_received {:put, "icplanning", %{"plannings" => [_]}}
  end

  test "changing a board goes into the planning", %{conn: conn} do
    stub([])
    {:ok, view, _} = live(login(conn), ~p"/beheer/472/1")

    view
    |> element("#plan-2A-2-1")
    |> render_change(%{"team" => "2A-2", "board" => "1", "idnumber" => "6530"})

    view |> element("#validate") |> render_click()

    assert_received {:put, "icplanningvalidate",
                     %{"plannings" => [%{"games" => [%{"idnumber_home" => 6530} | _]}]}}
  end

  test "open round: results can be saved for a team", %{conn: conn} do
    stub(date: "2000-01-01")
    {:ok, view, _} = live(login(conn), ~p"/beheer/472/1")
    refute has_element?(view, "#submit")

    view
    |> element("#result-2A-2-1")
    |> render_change(%{"team" => "2A-2", "board" => "1", "result" => "1-0"})

    view |> element("#save-results-2A-2") |> render_click()

    assert_received {:put, "icresults", %{"results" => [item]}}
    assert %{"icclub_home" => 472, "icclub_visit" => 402, "round" => 1} = item

    assert hd(item["games"]) == %{
             "idnumber_home" => 14108,
             "idnumber_visit" => 0,
             "result" => "1-0"
           }
  end

  test "confirm as captain sends the member number for the own side", %{conn: conn} do
    stub(date: "2000-01-01")
    conn = init_test_session(conn, kbsb_token: "tok", kbsb_idnumber: 12345)
    {:ok, view, _} = live(conn, ~p"/beheer/472/1")

    view |> element("#confirm-2A-2") |> render_click()
    view |> element("#save-results-2A-2") |> render_click()

    assert_received {:put, "icresults", %{"results" => [item]}}
    assert item["signhome_idnumber"] == 12345
    assert is_binary(item["signhome_ts"])
    refute Map.has_key?(item, "signvisit_idnumber")
  end
end
