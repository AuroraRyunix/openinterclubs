defmodule OpenInterclubsWeb.SeasonLive do
  @moduledoc """
  `use OpenInterclubsWeb.SeasonLive` in LiveViews that render season data.
  They implement `refresh/1` (load assigns from `OpenInterclubs.Season`);
  it runs from `handle_params/3` and again whenever the loader broadcasts
  new data, so open pages update live during a match day.
  """

  defmacro __using__(_opts) do
    quote do
      use OpenInterclubsWeb, :live_view
      alias OpenInterclubs.Season

      @impl true
      def handle_info(:season_updated, socket), do: {:noreply, refresh(socket)}

      # Subscribe to live updates and select the season from the session
      # (nil = current, or an archived season like "2526").
      defp subscribe(socket, session) do
        if connected?(socket), do: Season.subscribe()
        Season.use_season(session["season"])
        assign(socket, loaded?: Season.loaded?(), season: Season.selected())
      end

      defp refreshed(socket), do: socket |> assign(loaded?: Season.loaded?()) |> refresh()
    end
  end
end
