defmodule OpenInterclubsWeb.SessionHTML do
  use OpenInterclubsWeb, :html

  def new(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-sm">
        <h1 class="mb-2 text-2xl font-bold">{t("Aanmelden bij de KBSB")}</h1>

        <div :if={@user} class="mb-6 rounded-xl bg-base-200 p-4 text-sm">
          Aangemeld als <b>{@user}</b>.
          <.form for={%{}} action={~p"/logout"} method="post" class="mt-2">
            <button id="logout" class="underline">{t("Afmelden")}</button>
          </.form>
        </div>

        <p class="mb-6 text-sm opacity-70">
          {t("Met je KBSB-login kan de uitslagenfiche de opstelling van je eigen club invullen.")}
          {t(
            "Je wachtwoord wordt enkel doorgegeven aan de KBSB en niet bewaard; de sessie vervalt na 12 uur."
          )}
        </p>

        <p
          :if={@error}
          id="login-error"
          class="mb-4 rounded-lg bg-error/15 px-3 py-2 text-sm text-error"
        >
          {@error}
        </p>

        <.form for={%{}} action={~p"/login"} method="post" id="login-form" class="space-y-4">
          <input type="hidden" name="return_to" value={@return_to} />
          <.input
            name="user"
            value=""
            label={t("Lidnummer of e-mail")}
            autocomplete="username"
            required
          />
          <.input
            name="password"
            value=""
            type="password"
            label={t("Wachtwoord")}
            autocomplete="current-password"
            required
          />
          <button class="w-full rounded-lg bg-primary px-4 py-2 font-semibold text-primary-content transition hover:opacity-90">
            {t("Aanmelden")}
          </button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  def two_factor(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-sm">
        <h1 class="mb-2 text-2xl font-bold">{t("Verificatiecode")}</h1>
        <p class="mb-6 text-sm opacity-70">
          {t(
            "Je account (%{user}) is beveiligd met twee-staps-verificatie. Geef de code uit je authenticator-app.",
            user: @user
          )}
        </p>

        <p
          :if={@error}
          id="login-error"
          class="mb-4 rounded-md bg-error/15 px-3 py-2 text-sm text-error"
        >
          {@error}
        </p>

        <.form for={%{}} action={~p"/login/2fa"} method="post" id="login-2fa-form" class="space-y-4">
          <input type="hidden" name="return_to" value={@return_to} />
          <.input
            name="code"
            value=""
            label={t("Code")}
            inputmode="numeric"
            autocomplete="one-time-code"
            pattern="[0-9 ]*"
            maxlength="12"
            required
            autofocus
          />
          <button class="w-full rounded-md bg-primary px-4 py-2 font-semibold text-primary-content transition hover:opacity-90">
            {t("Bevestigen")}
          </button>
        </.form>
        <p class="mt-4 text-sm">
          <.link href={~p"/login"} class="underline">{t("Opnieuw beginnen")}</.link>
        </p>
      </div>
    </Layouts.app>
    """
  end
end
