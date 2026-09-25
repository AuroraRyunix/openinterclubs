defmodule OpenInterclubsWeb.HomeLive do
  use OpenInterclubsWeb.SeasonLive

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> subscribe() |> assign(q: "", page_title: "Interclubs")}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, refreshed(socket)}

  @impl true
  def handle_event("search", %{"q" => q}, socket),
    do: {:noreply, socket |> assign(q: q) |> refresh()}

  defp refresh(socket) do
    clubs = Season.clubs() |> Map.values() |> Enum.sort_by(&String.downcase(&1.name))
    round = Season.current_round()

    assign(socket,
      clubs: clubs,
      provinces: Enum.group_by(clubs, & &1.province) |> Enum.sort_by(&elem(&1, 0)),
      round: round,
      round_date: Enum.find_value(Season.rounds(), &(&1.round == round && &1.date)),
      stats: %{
        clubs: length(clubs),
        teams: map_size(Season.teams()),
        players: length(Season.players())
      },
      results: search(socket.assigns.q, clubs)
    )
  end

  defp search(q, clubs) do
    q = q |> String.trim() |> String.downcase()

    if String.length(q) < 2 do
      nil
    else
      match? = &String.contains?(String.downcase(&1), q)

      %{
        clubs: clubs |> Enum.filter(&(match?.(&1.name) or to_string(&1.id) == q)) |> Enum.take(8),
        players:
          Season.players()
          |> Enum.filter(
            &(match?.(&1.name) or match?.("#{&1.last_name} #{&1.first_name}") or
                to_string(&1.id) == q)
          )
          |> Enum.sort_by(&(-&1.rating))
          |> Enum.take(12)
      }
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section class="relative mb-10 overflow-hidden rounded-3xl bg-gradient-to-br from-primary/15 via-base-200 to-base-100 px-6 py-10 sm:px-10">
        <p class="text-xs font-semibold uppercase tracking-widest text-primary">
          KBSB · FRBE interclubs
        </p>
        <h1 class="mt-2 max-w-2xl text-4xl font-extrabold tracking-tight sm:text-5xl">
          Uitslagen, standen en spelers — live.
        </h1>
        <form id="search-form" phx-change="search" phx-submit="search" class="mt-6 max-w-xl">
          <div class="relative">
            <.icon
              name="hero-magnifying-glass"
              class="absolute left-4 top-1/2 size-5 -translate-y-1/2 opacity-50"
            />
            <input
              id="search"
              name="q"
              value={@q}
              phx-debounce="150"
              autocomplete="off"
              placeholder="Zoek een club of speler (naam of nummer)…"
              class="w-full rounded-2xl border border-base-300 bg-base-100 py-3.5 pl-12 pr-4 text-base shadow-sm outline-none transition focus:border-primary focus:ring-4 focus:ring-primary/15"
            />
          </div>
        </form>

        <div :if={@results} id="search-results" class="mt-4 grid max-w-3xl gap-4 sm:grid-cols-2">
          <div :if={@results.clubs != []} class="rounded-2xl bg-base-100 p-3 shadow-sm">
            <p class="px-2 pb-1 text-xs font-semibold uppercase opacity-50">Clubs</p>
            <.link
              :for={c <- @results.clubs}
              navigate={club_path(c.id)}
              class="flex justify-between rounded-lg px-2 py-1.5 transition hover:bg-base-200"
            >
              <span>{c.name}</span><span class="opacity-50">{c.id}</span>
            </.link>
          </div>
          <div :if={@results.players != []} class="rounded-2xl bg-base-100 p-3 shadow-sm">
            <p class="px-2 pb-1 text-xs font-semibold uppercase opacity-50">Spelers</p>
            <.link
              :for={p <- @results.players}
              navigate={player_path(p.id)}
              class="flex justify-between gap-3 rounded-lg px-2 py-1.5 transition hover:bg-base-200"
            >
              <span class="truncate">{p.name}</span>
              <span class="tabular-nums opacity-50">{rating(p.rating)}</span>
            </.link>
          </div>
          <p :if={@results.clubs == [] and @results.players == []} class="opacity-60">
            Niets gevonden.
          </p>
        </div>
      </section>

      <.loading :if={!@loaded?} />

      <div :if={@loaded?} class="grid gap-6 lg:grid-cols-3">
        <div class="grid grid-cols-3 gap-3 lg:col-span-3">
          <.stat label="Clubs" value={@stats.clubs} />
          <.stat label="Ploegen" value={@stats.teams} />
          <.stat label="Spelers" value={@stats.players} />
        </div>

        <.card class="lg:col-span-1">
          <:title>Ronde {@round}</:title>
          <p class="text-2xl font-bold">{short_date(@round_date)}</p>
          <p class="mb-4 text-sm opacity-60">{date(@round_date)}</p>
          <div class="flex flex-wrap gap-2">
            <.btn href={~p"/rounds/#{@round}"}>Alle uitslagen</.btn>
            <.btn href={~p"/fiche"}>Uitslagenfiche</.btn>
          </div>
        </.card>

        <.card class="lg:col-span-2">
          <:title>Clubs per provincie</:title>
          <div class="grid gap-2 sm:grid-cols-2">
            <details
              :for={{prov, clubs} <- @provinces}
              class="group rounded-xl bg-base-200/60 px-3 py-2"
            >
              <summary class="flex cursor-pointer list-none items-center justify-between font-medium">
                {prov}
                <span class="text-xs opacity-60">
                  {length(clubs)}
                  <.icon name="hero-chevron-down" class="size-3 transition group-open:rotate-180" />
                </span>
              </summary>
              <ul class="mt-2 space-y-0.5 text-sm">
                <li :for={c <- clubs}>
                  <.link
                    navigate={club_path(c.id)}
                    class="flex justify-between rounded px-1 hover:text-primary"
                  >
                    <span>{c.name}</span><span class="opacity-40">{c.id}</span>
                  </.link>
                </li>
              </ul>
            </details>
          </div>
        </.card>
      </div>
    </Layouts.app>
    """
  end
end
