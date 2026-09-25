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

    live "/", FicheLive
    live "/print/:idclub/:round", PrintLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", OpenInterclubsWeb do
  #   pipe_through :api
  # end
end
