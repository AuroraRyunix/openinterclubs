defmodule OpenInterclubsWeb.ClubLive do
  use OpenInterclubsWeb.SeasonLive

  alias OpenInterclubs.Kbsb

  @impl true
  def mount(%{"id" => id}, session, socket) do
    id = String.to_integer(id)

    {:ok,
     socket
     |> subscribe(session)
     |> assign(id: id, venues: nil)
     |> start_async(:venues, fn -> Kbsb.venue(id) end)}
  end

  @impl true
  def handle_params(params, _uri, socket),
    do: {:noreply, socket |> assign(tab: params["tab"] || "ploegen") |> refreshed()}

  @impl true
  def handle_async(:venues, {:ok, {:ok, %{"venues" => v}}}, socket),
    do: {:noreply, assign(socket, venues: v)}

  def handle_async(:venues, _, socket), do: {:noreply, assign(socket, venues: [])}

  defp refresh(socket) do
    club = Season.club(socket.assigns.id)

    teams =
      for key <- (club && club.teams) || [], t = Season.team(key), t do
        s = Season.series(t.series)
        row = s && Enum.find(s.standings, &(&1.team == key))
        %{team: t, row: row, size: s && length(s.teams)}
      end

    assign(socket,
      club: club,
      teams: teams,
      players: if(club, do: Season.players(club.players), else: []),
      page_title: club && club.name
    )
  end

  # First opponent of this club's first team, else any other club.
  defp h2h_default(id) do
    with [key | _] <- (Season.club(id) || %{teams: []}).teams,
         [e | _] <- Season.team_encounters(key) do
      opp = if e.home == key, do: e.visit, else: e.home
      elem(opp, 0)
    else
      _ -> Season.clubs() |> Map.keys() |> Enum.find(id, &(&1 != id))
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} season={@season}>
      <.loading :if={!@loaded?} />
      <p :if={@loaded? and is_nil(@club)}>{t("Deze club bestaat niet.")}</p>
      <div :if={@club}>
        <.page_header kicker={"Club #{@club.id} · #{t(@club.province)}"} title={@club.name}>
          <:subtitle>{length(@teams)} ploegen · {length(@players)} spelers</:subtitle>
          <:actions>
            <.btn href={~p"/beheer/#{@club.id}/#{Season.current_round()}"}>
              <.icon name="hero-clipboard-document-list" class="size-4" /> Clubbeheer
            </.btn>
            <.btn href={~p"/live/#{@club.id}"}>
              <.icon name="hero-signal" class="size-4" /> Live
            </.btn>
            <.btn href={~p"/clubs/#{@club.id}/vs/#{h2h_default(@club.id)}"}>
              <.icon name="hero-arrows-right-left" class="size-4" /> Onderlinge duels
            </.btn>
            <.btn href={~p"/print/#{@club.id}/#{Season.current_round()}"}>
              <.icon name="hero-printer" class="size-4" /> {t("Fiches ronde %{n}",
                n: Season.current_round()
              )}
            </.btn>
          </:actions>
        </.page_header>

        <.tabs
          active={@tab}
          tabs={[
            {"ploegen", t("Ploegen"), ~p"/clubs/#{@club.id}"},
            {"spelers", t("Spelers"), ~p"/clubs/#{@club.id}?tab=spelers"},
            {"lokaal", t("Speellokaal"), ~p"/clubs/#{@club.id}?tab=lokaal"}
          ]}
        />

        <div :if={@tab == "ploegen"} id="teams" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <.link
            :for={t <- @teams}
            navigate={team_path(t.team.key)}
            class="rounded-2xl border border-base-300 bg-base-100 p-5 shadow-sm transition hover:-translate-y-0.5 hover:border-primary hover:shadow-md"
          >
            <p class="text-xs uppercase opacity-50">
              {t("Reeks %{s}", s: series_slug(t.team.series))}
            </p>
            <p class="text-xl font-bold">{t.team.name}</p>
            <p :if={t.row && t.row.played > 0} class="mt-3 flex items-baseline gap-4 text-sm">
              <span><span class="text-2xl font-extrabold">{t.row.rank}</span><span class="opacity-50">/{t.size}</span></span>
              <span class="opacity-70">{t.row.mp} MP · {points(t.row.bp)} BP</span>
            </p>
            <p :if={t.row && t.row.played == 0} class="mt-3 text-sm opacity-60">
              {t("Nog niet gespeeld")}
            </p>
          </.link>
        </div>

        <.card :if={@tab == "spelers"} id="players">
          <.player_table players={@players} />
        </.card>

        <div :if={@tab == "lokaal"} id="venues" class="grid gap-4 md:grid-cols-2">
          <p :if={is_nil(@venues)} class="opacity-60">{t("Laden…")}</p>
          <p :if={@venues == []} class="opacity-60">{t("Geen speellokaal gekend.")}</p>
          <.card :for={v <- @venues || []}>
            <p class="whitespace-pre-line font-medium">{String.trim(v["address"] || "")}</p>
            <a
              class="mt-1 inline-block text-sm text-primary underline"
              target="_blank"
              href={"https://www.openstreetmap.org/search?query=" <> URI.encode_www_form(v["address"] || "")}
            >
              {t("Toon op kaart")}
            </a>
            <dl class="mt-4 grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm">
              <dt :if={v["rounds"] not in [nil, []]} class="opacity-60">{t("Rondes")}</dt>
              <dd :if={v["rounds"] not in [nil, []]}>{Enum.join(v["rounds"], ", ")}</dd>
              <dt :if={v["capacity"]} class="opacity-60">{t("Capaciteit")}</dt>
              <dd :if={v["capacity"]}>{v["capacity"]}</dd>
              <dt class="opacity-60">{t("Rolstoel")}</dt>
              <dd>{if v["wheelchair"], do: "toegankelijk", else: "niet vermeld"}</dd>
              <dt :if={v["parking"] not in [nil, ""]} class="opacity-60">{t("Parking")}</dt>
              <dd :if={v["parking"] not in [nil, ""]}>{v["parking"]}</dd>
              <dt :if={v["remarks"] not in [nil, ""]} class="opacity-60">{t("Opmerkingen")}</dt>
              <dd :if={v["remarks"] not in [nil, ""]}>{v["remarks"]}</dd>
            </dl>
          </.card>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
