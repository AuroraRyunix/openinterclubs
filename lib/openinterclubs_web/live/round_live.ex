defmodule OpenInterclubsWeb.RoundLive do
  use OpenInterclubsWeb.SeasonLive

  @impl true
  def mount(_params, _session, socket), do: {:ok, subscribe(socket)}

  @impl true
  def handle_params(params, _uri, socket) do
    round =
      case Integer.parse(params["round"] || "") do
        {n, ""} -> n
        _ -> Season.current_round()
      end

    {:noreply, socket |> assign(round: round, page_title: "Ronde #{round}") |> refreshed()}
  end

  defp refresh(socket) do
    round = socket.assigns.round

    assign(socket,
      rounds: Season.rounds(),
      date: Enum.find_value(Season.rounds(), &(&1.round == round && &1.date)),
      groups: Season.encounters(round)
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.page_header kicker="Alle afdelingen" title={"Ronde #{@round}"}>
        <:subtitle>{date(@date)}</:subtitle>
      </.page_header>

      <nav id="round-picker" class="mb-8 flex flex-wrap gap-2">
        <.link
          :for={r <- @rounds}
          patch={~p"/rounds/#{r.round}"}
          class={[
            "grid size-10 place-items-center rounded-xl text-sm font-semibold transition hover:-translate-y-px",
            if(r.round == @round,
              do: "bg-primary text-primary-content shadow",
              else: "bg-base-200 hover:bg-base-300"
            )
          ]}
          title={date(r.date)}
        >
          {r.round}
        </.link>
      </nav>

      <.loading :if={!@loaded?} />

      <div class="grid gap-5 md:grid-cols-2">
        <.card :for={{s, encounters} <- @groups} id={"series-#{s.label}"}>
          <:title>
            <.link navigate={series_path(s.key)} class="hover:text-primary">
              {division_name(s.division)} {s.index}
            </.link>
          </:title>
          <.encounter_row :for={e <- encounters} e={e} />
        </.card>
      </div>
    </Layouts.app>
    """
  end
end
