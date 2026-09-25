defmodule OpenInterclubsWeb.DivisionsLive do
  use OpenInterclubsWeb.SeasonLive

  @impl true
  def mount(_params, _session, socket),
    do: {:ok, socket |> subscribe() |> assign(page_title: "Afdelingen")}

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, refreshed(socket)}

  defp refresh(socket) do
    groups =
      Season.series()
      |> Map.values()
      |> Enum.sort_by(& &1.key)
      |> Enum.group_by(& &1.division)
      |> Enum.sort()

    assign(socket, groups: groups)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.page_header kicker="Seizoen" title="Afdelingen" />
      <.loading :if={!@loaded?} />
      <section :for={{div, series} <- @groups} class="mb-10">
        <h2 class="mb-3 text-lg font-semibold">{division_name(div)}</h2>
        <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <.link
            :for={s <- series}
            navigate={series_path(s.key)}
            id={"division-#{s.label}"}
            class="group rounded-2xl border border-base-300 bg-base-100 p-4 shadow-sm transition hover:-translate-y-0.5 hover:border-primary hover:shadow-md"
          >
            <div class="mb-2 flex items-baseline justify-between">
              <span class="text-2xl font-extrabold">{s.label}</span>
              <span class="text-xs opacity-50">{length(s.teams)} ploegen</span>
            </div>
            <ol class="space-y-0.5 text-sm">
              <li :for={row <- Enum.take(s.standings, 3)} class="flex justify-between">
                <span class="truncate"><span class="opacity-40">{row.rank}.</span> {team_name(
                  row.team
                )}</span>
                <span class="tabular-nums opacity-70">{row.mp}</span>
              </li>
            </ol>
          </.link>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
