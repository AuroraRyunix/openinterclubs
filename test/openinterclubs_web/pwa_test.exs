defmodule OpenInterclubsWeb.PwaTest do
  use OpenInterclubsWeb.ConnCase, async: true

  test "manifest, service worker and icons are served", %{conn: conn} do
    manifest = conn |> get("/manifest.webmanifest") |> response(200) |> Jason.decode!()
    assert manifest["start_url"] == "/"
    assert conn |> get("/sw.js") |> response(200) =~ "openinterclubs-v1"
    assert conn |> get("/images/icon-192.png") |> response(200)
  end
end
