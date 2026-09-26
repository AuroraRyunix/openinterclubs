defmodule OpenInterclubsWeb.FicheComponents do
  @moduledoc "Printable replica of the KBSB 'Uitslagenfiche Interclub'."
  use Phoenix.Component

  attr :fiche, OpenInterclubs.Fiche, required: true
  attr :editable, :boolean, default: false

  def fiche(assigns) do
    ~H"""
    <div class="fiche">
      <table class="fiche-head">
        <tr>
          <td>
            AFDELING : <b>{@fiche.division}</b><br />DIVISION :
          </td>
          <td>REEKS : <b>{@fiche.index}</b><br />SERIE :</td>
          <td>DATUM : <b>{format_date(@fiche.date)}</b><br />DATE :</td>
          <td class="ronde">RONDE : <b>{@fiche.round}</b></td>
        </tr>
      </table>
      <table class="fiche-body">
        <thead>
          <tr>
            <th rowspan="2" class="nr">(5)</th>
            <th rowspan="2" class="team">
              VISITES THUISPLOEG
              <div class="club">{@fiche.home.name} ({@fiche.home.idclub})</div>
              <.side_actions :if={@editable} side="home" />
            </th>
            <th rowspan="2" class="team">
              VISITEURS BEZOEKERS
              <div class="club">{@fiche.visit.name} ({@fiche.visit.idclub})</div>
              <.side_actions :if={@editable} side="visit" />
            </th>
            <th class="res">Uitslag<br />Résultat<br />(1)</th>
            <th colspan="3">COMPUTER<br />ORDINATEUR</th>
          </tr>
          <tr>
            <th></th>
            <th class="id">(2)</th>
            <th class="id">(3)</th>
            <th class="res4">(4)</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={b <- @fiche.boards}>
            <td class="nr">{b.board}</td>
            <td><.player fiche={@fiche} board={b} side={:home} editable={@editable} /></td>
            <td><.player fiche={@fiche} board={b} side={:visit} editable={@editable} /></td>
            <td class="res">-</td>
            <td class="id">{b.home && b.home.idnumber}</td>
            <td class="id">{b.visit && b.visit.idnumber}</td>
            <td class="res4"></td>
          </tr>
        </tbody>
      </table>
      <div class="fiche-foot">
        <div class="legend">
          (1) Victoire / Winst = 1; Nulle / Remise = 1/2; Défaite / Verlies = 0; Forfait = -<br />
          (2) Stamnummers thuisspelers / Matricules visités<br />
          (3) Matricules visiteurs / Stamnummers bezoekers<br />
          (4) Thuisspeler wint / Visité gagne = 1; Thuisspeler verliest / Visité perd = 0;
          Remise / Nulle = 5; Forfait = -<br /> (5) Klub : naam en nummer / Club : nom et numéro
        </div>
        <table class="total">
          <tr>
            <td>Total<br />Totaal</td>
            <td class="res">-</td>
          </tr>
        </table>
        <div class="sign"><i>Signatures<br />Handtekening</i></div>
      </div>
    </div>
    """
  end

  attr :side, :string, required: true

  defp side_actions(assigns) do
    ~H"""
    <div class="screen-only side-actions">
      <button type="button" id={"clear-#{@side}"} phx-click="clear" phx-value-side={@side}>
        Wissen
      </button>
    </div>
    """
  end

  attr :fiche, :any, required: true
  attr :board, :map, required: true
  attr :side, :atom, required: true
  attr :editable, :boolean, default: false

  defp player(assigns) do
    assigns = assign(assigns, :current, Map.get(assigns.board, assigns.side))

    ~H"""
    <span class={@editable && "print-only"}>
      {@current && (@current.name || "?")}
      <span :if={@current && @current[:rating] not in [nil, 0]}>({@current.rating})</span>
    </span>
    <form
      :if={@editable}
      id={"board-form-#{@board.board}-#{@side}"}
      phx-change="set_player"
      class="screen-only"
    >
      <input type="hidden" name="board" value={@board.board} />
      <input type="hidden" name="side" value={@side} />
      <select
        name="idnumber"
        id={"board-#{@board.board}-#{@side}"}
        class="fiche-select"
      >
        <option value="">—</option>
        {Phoenix.HTML.Form.options_for_select(
          Map.fetch!(@fiche, @side).options,
          @current && @current.idnumber
        )}
      </select>
    </form>
    """
  end

  defp format_date(nil), do: ""

  defp format_date(iso) do
    case Date.from_iso8601(iso) do
      {:ok, d} -> Calendar.strftime(d, "%d/%m/%Y")
      _ -> iso
    end
  end
end
