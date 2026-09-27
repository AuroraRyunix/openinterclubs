defmodule OpenInterclubsWeb.ClubAdminIndexLive do
  @moduledoc "Entry to Clubbeheer: your own club, or pick another club you manage."
  use OpenInterclubsWeb, :live_view

  alias OpenInterclubs.{Kbsb, Season}

  @impl true
  def mount(_params, session, socket) do
    token = session["kbsb_token"]
    round = Season.current_round()

    socket =
      assign(socket,
        token: token,
        round: round,
        own: nil,
        q: "",
        results: [],
        error: nil,
        page_title: t("Mgmt")
      )

    socket =
      if token && connected?(socket) do
        idnumber = session["kbsb_idnumber"]
        start_async(socket, :own, fn -> own_club(token, idnumber) end)
      else
        socket
      end

    {:ok, socket}
  end

  # The member's own club, if the KBSB confirms a role there.
  defp own_club(token, idnumber) do
    with {:ok, club} <- Kbsb.member_club(idnumber),
         true <- Kbsb.club_access?(token, club) do
      club
    else
      _ -> nil
    end
  end

  @impl true
  def handle_async(:own, {:ok, club}, socket), do: {:noreply, assign(socket, own: club || :none)}
  def handle_async(:own, _, socket), do: {:noreply, assign(socket, own: :none)}

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    q = String.trim(q)

    results =
      if String.length(q) < 2 do
        []
      else
        down = String.downcase(q)

        Season.clubs()
        |> Map.values()
        |> Enum.filter(
          &(String.contains?(String.downcase(&1.name), down) or to_string(&1.id) == q)
        )
        |> Enum.sort_by(& &1.name)
        |> Enum.take(10)
      end

    {:noreply, assign(socket, q: q, results: results)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-xl">
        <.page_header kicker={t("Ronde %{n}", n: @round)} title={t("Mgmt")}>
          <:subtitle>{t("Opstellingen controleren en indienen, uitslagen ingeven.")}</:subtitle>
        </.page_header>

        <%= if is_nil(@token) do %>
          <p>
            <.link href={~p"/login?#{%{return_to: "/mgmt"}}"} class="underline">
              {t("Meld je aan met je KBSB-login")}
            </.link>
          </p>
        <% else %>
          <.card class="mb-6">
            <:title>{t("Jouw club")}</:title>
            <p :if={is_nil(@own)} class="opacity-60">{t("Laden…")}</p>
            <p :if={@own == :none} id="no-own-club" class="text-sm opacity-70">
              {t("Geen beheerrechten gevonden voor je eigen club. Kies hieronder een club.")}
            </p>
            <.link
              :if={is_integer(@own)}
              id="own-club"
              navigate={~p"/mgmt/#{@own}/#{@round}"}
              class="flex items-center justify-between rounded-xl bg-primary px-4 py-3 font-semibold text-primary-content transition hover:opacity-90"
            >
              <span>{club_name(@own)} ({@own})</span>
              <span>→</span>
            </.link>
          </.card>

          <.card>
            <:title>{t("Andere club")}</:title>
            <form id="club-search-form" phx-change="search">
              <input
                name="q"
                value={@q}
                phx-debounce="150"
                autocomplete="off"
                placeholder={t("Zoek club op naam of nummer…")}
                class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2"
              />
            </form>
            <.link
              :for={c <- @results}
              navigate={~p"/mgmt/#{c.id}/#{@round}"}
              class="mt-1 flex justify-between rounded-lg px-2 py-1.5 transition hover:bg-base-200"
            >
              <span>{c.name}</span><span class="opacity-50">{c.id}</span>
            </.link>
            <p class="mt-2 text-xs opacity-60">
              {t("Je ziet enkel clubs waarvoor de KBSB je rechten geeft.")}
            </p>
          </.card>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
