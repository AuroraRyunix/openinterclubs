defmodule OpenInterclubsWeb.MatchdayLive do
  @moduledoc "Match day view: all of a club's encounters in a round, live, for phones."
  use OpenInterclubsWeb.SeasonLive

  alias OpenInterclubs.Season.Result

  @impl true
  def mount(%{"id" => id}, session, socket) do
    {:ok, socket |> subscribe(session) |> assign(id: String.to_integer(id))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    round =
      case Integer.parse(params["round"] || "") do
        {n, ""} -> n
        _ -> Season.current_round()
      end

    {:noreply, socket |> assign(round: round) |> refreshed()}
  end

  defp refresh(socket) do
    club = Season.club(socket.assigns.id)

    encounters =
      for key <- (club && club.teams) || [],
          e <- Season.team_encounters(key),
          e.round == socket.assigns.round,
          do: e

    assign(socket,
      club: club,
      encounters: Enum.uniq_by(encounters, &{&1.series, &1.home, &1.visit}),
      page_title: club && "Live · #{club.name}"
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} season={@season}>
      <.loading :if={!@loaded?} />
      <div :if={@club} class="mx-auto max-w-md">
        <p class="text-xs font-semibold uppercase tracking-widest text-primary">
          Live · ronde {@round}
        </p>
        <h1 class="mb-4 text-2xl font-bold">{@club.name}</h1>

        <p :if={@encounters == []} class="opacity-60">{t("Geen ontmoetingen in deze ronde.")}</p>

        <.link
          :for={e <- @encounters}
          navigate={match_path(e)}
          id={"live-#{series_slug(e.series)}-#{elem(e.home, 0)}-#{elem(e.home, 1)}"}
          class="mb-3 block rounded-2xl border border-base-300 bg-base-100 p-4 shadow-sm transition active:scale-[0.99]"
        >
          <div class="mb-2 flex items-center justify-between gap-2">
            <div class="min-w-0">
              <p class={["truncate", own?(e.home, @club.id) && "font-bold"]}>{team_name(e.home)}</p>
              <p class={["truncate", own?(e.visit, @club.id) && "font-bold"]}>{team_name(e.visit)}</p>
            </div>
            <.score e={e} for={if own?(e.home, @club.id), do: :home, else: :visit} />
          </div>
          <div class="flex gap-1">
            <span
              :for={g <- e.games}
              title={"Bord #{g.board}"}
              class={[
                "h-2 flex-1 rounded-full",
                board_class(g.result, if(own?(e.home, @club.id), do: :home, else: :visit))
              ]}
            />
          </div>
        </.link>

        <p class="mt-4 text-center text-xs opacity-50">
          Werkt vanzelf bij · laatste update {last(@loaded?)}
        </p>
      </div>
    </Layouts.app>
    """
  end

  defp own?({club, _}, club), do: true
  defp own?(_, _), do: false

  defp board_class(nil, _), do: "bg-base-300"

  defp board_class(result, side) do
    case Result.score(result, side) do
      1.0 -> "bg-success"
      0.5 -> "bg-warning"
      _ -> "bg-error"
    end
  end

  defp last(false), do: "–"

  defp last(true) do
    case Season.loaded_at() do
      %DateTime{} = dt ->
        dt
        |> DateTime.add(if(dt.month in 4..10, do: 7200, else: 3600))
        |> Calendar.strftime("%H:%M")

      _ ->
        "–"
    end
  end
end
