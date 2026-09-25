defmodule OpenInterclubsWeb.Router do
  use OpenInterclubsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OpenInterclubsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", OpenInterclubsWeb do
    pipe_through :browser

    live "/", HomeLive
    live "/rounds", RoundLive
    live "/rounds/:round", RoundLive
    live "/divisions", DivisionsLive
    live "/divisions/:series", DivisionLive
    live "/match/:series/:round/:club/:team", MatchLive
    live "/clubs/:id", ClubLive
    live "/clubs/:id/teams/:number", TeamLive
    live "/players/:id", PlayerLive
    live "/top", TopLive
    live "/fiche", FicheLive
    live "/print/:idclub/:round", PrintLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", OpenInterclubsWeb do
  #   pipe_through :api
  # end
end
