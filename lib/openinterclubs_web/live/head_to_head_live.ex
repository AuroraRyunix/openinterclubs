defmodule OpenInterclubsWeb.HeadToHeadLive do
  use OpenInterclubsWeb.SeasonLive

  alias OpenInterclubs.HeadToHead
  alias OpenInterclubs.Season.Archive

  @impl true
  def mount(%{"a" => a, "b" => b}, session, socket) do
    socket = subscribe(socket, session)
    a = String.to_integer(a)
    b = String.to_integer(b)

    socket =
      socket
      |> assign(a: a, b: b, seasons: nil, totals: nil, page_title: "Onderlinge duels")
      |> start_async(:load, fn -> HeadToHead.between(a, b) end)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, refresh(socket)}

  @impl true
  def handle_async(:load, {:ok, seasons}, socket),
    do: {:noreply, assign(socket, seasons: seasons, totals: HeadToHead.totals(seasons))}

  def handle_async(:load, _, socket), do: {:noreply, assign(socket, seasons: [], totals: nil)}

  defp refresh(socket) do
    Season.use_season(socket.assigns.season)

    assign(socket,
      club_a: Season.club(socket.assigns.a),
      club_b: Season.club(socket.assigns.b),
      clubs: Season.clubs() |> Map.values() |> Enum.sort_by(&String.downcase(&1.name))
    )
  end

  @impl true
  def handle_event("pick", %{"b" => b}, socket),
    do: {:noreply, push_navigate(socket, to: ~p"/clubs/#{socket.assigns.a}/vs/#{b}")}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} season={@season}>
      <.page_header
        kicker={t("Onderlinge duels")}
        title={"#{name(@club_a, @a)} – #{name(@club_b, @b)}"}
      >
        <:subtitle>
          {t("Alle ontmoetingen tussen beide clubs, dit seizoen en de voorbije seizoenen.")}
        </:subtitle>
      </.page_header>

      <form id="pick-form" phx-change="pick" class="mb-6">
        <select name="b" class="rounded-lg border border-base-300 bg-base-100 px-3 py-2">
          {Phoenix.HTML.Form.options_for_select(
            for(c <- @clubs, c.id != @a, do: {"#{c.name} (#{c.id})", c.id}),
            @b
          )}
        </select>
      </form>

      <.loading :if={is_nil(@seasons)} />

      <div :if={@totals} class="mb-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <.stat label={"Gewonnen door #{name(@club_a, @a)}"} value={@totals.won} />
        <.stat label={t("Gelijk")} value={@totals.drawn} />
        <.stat label={"Gewonnen door #{name(@club_b, @b)}"} value={@totals.lost} />
        <.stat label={t("Bordpunten")} value={"#{points(@totals.a_bp)} – #{points(@totals.b_bp)}"} />
      </div>

      <p :if={@seasons == []} class="opacity-60">{t("Deze clubs speelden nog niet tegen elkaar.")}</p>

      <.card :for={s <- @seasons || []} class="mb-4" id={"h2h-#{s.season || "current"}"}>
        <:title>{if s.season, do: Archive.label(s.season), else: "Dit seizoen"}</:title>
        <div
          :for={e <- s.encounters}
          class="grid grid-cols-[4rem_1fr_auto_1fr] items-center gap-3 border-t border-base-200 py-1.5 text-sm first:border-0"
        >
          <span class="opacity-50">R{e.round} · {series_slug(e.series)}</span>
          <span class="truncate text-right">{e.home_name}</span>
          <.score e={e} />
          <span class="truncate">{e.visit_name}</span>
        </div>
      </.card>
    </Layouts.app>
    """
  end

  defp name(nil, id), do: to_string(id)
  defp name(club, _), do: club.name
end
