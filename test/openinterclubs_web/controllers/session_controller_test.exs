defmodule OpenInterclubsWeb.SessionControllerTest do
  use OpenInterclubsWeb.ConnCase, async: false

  test "successful login stores the token in the session", %{conn: conn} do
    Req.Test.stub(OpenInterclubs.Kbsb, fn conn ->
      assert conn.request_path == "/api/v1/member/login"
      Req.Test.json(conn, [12345, "jwt-token"])
    end)

    conn = post(conn, ~p"/login", %{user: "12345", password: "secret", return_to: "/fiche"})
    assert redirected_to(conn) == "/fiche"
    assert get_session(conn, :kbsb_token) == "jwt-token"
    assert get_session(conn, :kbsb_user) == "12345"
    assert get_session(conn, :kbsb_idnumber) == 12345
  end

  test "wrong credentials show an error and store nothing", %{conn: conn} do
    Req.Test.stub(OpenInterclubs.Kbsb, fn conn ->
      conn
      |> Plug.Conn.put_status(401)
      |> Req.Test.json(%{"detail" => "WrongUsernamePasswordCombination"})
    end)

    conn = post(conn, ~p"/login", %{user: "1", password: "x"})
    assert html_response(conn, 401) =~ "Verkeerd lidnummer of wachtwoord"
    refute get_session(conn, :kbsb_token)
  end

  test "never redirects off-site", %{conn: conn} do
    Req.Test.stub(OpenInterclubs.Kbsb, &Req.Test.json(&1, [1, "tok"]))

    conn = post(conn, ~p"/login", %{user: "1", password: "x", return_to: "//evil.example"})
    assert redirected_to(conn) == "/fiche"
  end

  test "logout drops the session", %{conn: conn} do
    conn = conn |> init_test_session(kbsb_token: "t") |> post(~p"/logout")
    assert redirected_to(conn) == "/fiche"
  end
end
