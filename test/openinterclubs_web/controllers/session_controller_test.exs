defmodule OpenInterclubsWeb.SessionControllerTest do
  use OpenInterclubsWeb.ConnCase, async: false

  test "successful login stores the token in the session", %{conn: conn} do
    Req.Test.stub(OpenInterclubs.Kbsb, fn
      %{request_path: "/api/v1/member/login"} = conn ->
        Req.Test.json(conn, [12345, "jwt-token"])

      %{request_path: "/api/v1/member/anon/member/12345"} = conn ->
        Req.Test.json(conn, %{"first_name" => "Jorian", "last_name" => "Burssens"})
    end)

    conn = post(conn, ~p"/login", %{user: "12345", password: "secret", return_to: "/fiche"})
    assert redirected_to(conn) == "/fiche"
    assert get_session(conn, :kbsb_token) == "jwt-token"
    assert get_session(conn, :kbsb_user) == "12345"
    assert get_session(conn, :kbsb_idnumber) == 12345
    assert get_session(conn, :kbsb_name) == "Jorian Burssens"
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

  describe "KBSB login reply format and 2FA" do
    defp member_stub(conn) do
      Req.Test.json(conn, %{"first_name" => "Jorian", "last_name" => "Burssens"})
    end

    defp jwt(sub) do
      payload = Base.url_encode64(Jason.encode!(%{"sub" => sub}), padding: false)
      "h.#{payload}.s"
    end

    test "new LoginReply object without 2FA", %{conn: conn} do
      Req.Test.stub(OpenInterclubs.Kbsb, fn
        %{request_path: "/api/v1/member/login"} = conn ->
          Req.Test.json(conn, %{"id" => 777, "jwttoken" => "tok", "is2FAneeded" => false})

        conn ->
          member_stub(conn)
      end)

      conn = post(conn, ~p"/login", %{user: "a@b.be", password: "x"})
      assert redirected_to(conn)
      assert get_session(conn, :kbsb_token) == "tok"
      assert get_session(conn, :kbsb_idnumber) == 777
    end

    test "member number falls back to the token's sub", %{conn: conn} do
      token = jwt("4242")

      Req.Test.stub(OpenInterclubs.Kbsb, fn
        %{request_path: "/api/v1/member/login"} = conn ->
          Req.Test.json(conn, %{"id" => 0, "jwttoken" => token})

        conn ->
          member_stub(conn)
      end)

      conn = post(conn, ~p"/login", %{user: "a@b.be", password: "x"})
      assert get_session(conn, :kbsb_idnumber) == 4242
    end

    defp two_factor_stub(test, code_ok) do
      Req.Test.stub(OpenInterclubs.Kbsb, fn
        %{request_path: "/api/v1/member/login"} = conn ->
          Req.Test.json(conn, %{
            "id" => -1,
            "is2FAneeded" => true,
            "csrf" => "csrf-1",
            "session_id" => "sid-1",
            "state" => "state-1"
          })

        %{request_path: "/api/v1/member/login2fa"} = conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          send(test, {:login2fa, Jason.decode!(body)})
          sent = Jason.decode!(body)

          if sent["code2FA"] == code_ok do
            Req.Test.json(conn, %{"id" => 12345, "jwttoken" => "final-token"})
          else
            conn |> Plug.Conn.put_status(401) |> Req.Test.json(%{"detail" => "Wrong2FACode"})
          end

        conn ->
          member_stub(conn)
      end)
    end

    test "2FA: code page, then token after the right code", %{conn: conn} do
      two_factor_stub(self(), "123456")

      conn = post(conn, ~p"/login", %{user: "a@b.be", password: "secret", return_to: "/mgmt"})
      html = html_response(conn, 200)
      assert html =~ "login-2fa-form"
      refute get_session(conn, :kbsb_token)
      # the password is not kept anywhere in the session
      refute inspect(get_session(conn)) =~ "secret"

      conn = conn |> recycle() |> post(~p"/login/2fa", %{code: "123 456", return_to: "/mgmt"})
      assert redirected_to(conn) == "/mgmt"

      assert_received {:login2fa,
                       %{
                         "csrf" => "csrf-1",
                         "session_id" => "sid-1",
                         "state" => "state-1",
                         "code2FA" => "123456"
                       }}

      assert get_session(conn, :kbsb_token) == "final-token"
      assert get_session(conn, :kbsb_idnumber) == 12345
      assert get_session(conn, :kbsb_name) == "Jorian Burssens"
      refute get_session(conn, :kbsb_2fa)
    end

    test "2FA: wrong code shows an error and allows a retry", %{conn: conn} do
      two_factor_stub(self(), "123456")
      conn = post(conn, ~p"/login", %{user: "a@b.be", password: "x"})

      conn = conn |> recycle() |> post(~p"/login/2fa", %{code: "000000"})
      assert html_response(conn, 401) =~ "Code niet aanvaard"
      refute get_session(conn, :kbsb_token)

      conn = conn |> recycle() |> post(~p"/login/2fa", %{code: "123456"})
      assert get_session(conn, :kbsb_token) == "final-token"
    end

    test "2FA: too many wrong codes starts over", %{conn: conn} do
      two_factor_stub(self(), "123456")
      conn = post(conn, ~p"/login", %{user: "a@b.be", password: "x"})

      conn =
        Enum.reduce(1..5, conn, fn _, c ->
          c |> recycle() |> post(~p"/login/2fa", %{code: "000000"})
        end)

      conn = conn |> recycle() |> post(~p"/login/2fa", %{code: "123456"})
      assert redirected_to(conn) == "/login"
      refute get_session(conn, :kbsb_token)
    end

    test "2FA code without a pending login goes back to the login", %{conn: conn} do
      conn = post(conn, ~p"/login/2fa", %{code: "123456"})
      assert redirected_to(conn) == "/login"
    end

    test "2FA: an expired state asks to start over, new NotAuthorized text for passwords", %{
      conn: conn
    } do
      Req.Test.stub(OpenInterclubs.Kbsb, fn
        %{request_path: "/api/v1/member/login"} = conn ->
          Req.Test.json(conn, %{
            "is2FAneeded" => true,
            "csrf" => "c",
            "session_id" => "s",
            "state" => "x"
          })

        %{request_path: "/api/v1/member/login2fa"} = conn ->
          conn |> Plug.Conn.put_status(401) |> Req.Test.json(%{"detail" => "BadToken"})
      end)

      conn = post(conn, ~p"/login", %{user: "a@b.be", password: "x"})
      conn = conn |> recycle() |> post(~p"/login/2fa", %{code: "123456"})
      assert html_response(conn, 401) =~ "Sessie verlopen"
    end

    test "a wrong password (NotAuthorized) says so", %{conn: conn} do
      Req.Test.stub(OpenInterclubs.Kbsb, fn conn ->
        conn |> Plug.Conn.put_status(401) |> Req.Test.json(%{"detail" => "NotAuthorized"})
      end)

      conn = post(conn, ~p"/login", %{user: "a@b.be", password: "x"})
      assert html_response(conn, 401) =~ "Verkeerd lidnummer of wachtwoord"
    end
  end
end
