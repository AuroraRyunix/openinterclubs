defmodule OpenInterclubsWeb.FeedbackLive do
  @moduledoc "Feedback form that opens a pre-filled GitHub issue (no database needed)."
  use OpenInterclubsWeb, :live_view

  @repo "https://github.com/AuroraRyunix/openinterclubs/issues/new"
  @kinds [
    {"Fout in de gegevens", "gegevens"},
    {"Bug", "bug"},
    {"Idee", "idee"},
    {"Andere", "andere"}
  ]

  @impl true
  def mount(params, _session, socket) do
    form = to_form(%{"kind" => "gegevens", "text" => "", "page" => params["page"] || ""}, as: :f)
    {:ok, assign(socket, form: form, kinds: @kinds, url: nil, page_title: "Feedback")}
  end

  @impl true
  def handle_event("change", %{"f" => f}, socket) do
    {:noreply, assign(socket, form: to_form(f, as: :f), url: issue_url(f))}
  end

  defp issue_url(%{"text" => text} = f) do
    if String.trim(text) == "" do
      nil
    else
      title = "[#{f["kind"]}] " <> (text |> String.split("\n") |> hd() |> String.slice(0, 80))
      body = text <> if(f["page"] in [nil, ""], do: "", else: "\n\nPagina: #{f["page"]}")
      @repo <> "?" <> URI.encode_query(%{title: title, body: body, labels: f["kind"]})
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-xl">
        <.page_header kicker="OpenInterclubs" title={t("Feedback")}>
          <:subtitle>{t("Fout gezien of een idee? Je bericht wordt een issue op GitHub.")}</:subtitle>
        </.page_header>
        <.form for={@form} id="feedback-form" phx-change="change" class="space-y-4">
          <.input field={@form[:kind]} type="select" label={t("Soort")} options={@kinds} />
          <.input
            field={@form[:text]}
            type="textarea"
            label={t("Bericht")}
            rows="6"
            phx-debounce="300"
          />
          <.input field={@form[:page]} type="text" label={t("Over welke pagina? (optioneel)")} />
        </.form>
        <a
          :if={@url}
          id="send-feedback"
          href={@url}
          target="_blank"
          rel="noopener"
          class="mt-4 inline-block rounded-lg bg-primary px-4 py-2 font-semibold text-primary-content transition hover:opacity-90"
        >
          {t("Versturen via GitHub")}
        </a>
        <p class="mt-3 text-xs opacity-60">
          {t("Je hebt een (gratis) GitHub-account nodig; het bericht is openbaar.")}
        </p>
      </div>
    </Layouts.app>
    """
  end
end
