defmodule OpenInterclubs.Xlsx do
  @moduledoc """
  Minimal .xlsx writer: one sheet, a bold header row, numbers as numbers and
  everything else as text. Enough for exporting tables without a dependency.
  """

  @doc "Build an xlsx binary. `rows` is a list of lists of strings/numbers/nil."
  def build(sheet_name, header, rows) do
    files = [
      {~c"[Content_Types].xml", content_types()},
      {~c"_rels/.rels", rels()},
      {~c"xl/workbook.xml", workbook(sheet_name)},
      {~c"xl/_rels/workbook.xml.rels", workbook_rels()},
      {~c"xl/styles.xml", styles()},
      {~c"xl/worksheets/sheet1.xml", sheet([header | rows])}
    ]

    {:ok, {_, binary}} = :zip.create(~c"export.xlsx", files, [:memory])
    binary
  end

  defp sheet(rows) do
    data =
      rows
      |> Enum.with_index(1)
      |> Enum.map_join(fn {row, r} ->
        cells =
          row
          |> Enum.with_index()
          |> Enum.map_join(fn {v, c} -> cell(col(c) <> Integer.to_string(r), v, r == 1) end)

        ~s(<row r="#{r}">#{cells}</row>)
      end)

    ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>) <>
      ~s(<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">) <>
      ~s(<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>) <>
      ~s(<cols><col min="1" max="12" width="16" customWidth="1"/></cols>) <>
      "<sheetData>#{data}</sheetData></worksheet>"
  end

  defp cell(_ref, nil, _header), do: ""

  defp cell(ref, v, header) when is_number(v),
    do: ~s(<c r="#{ref}"#{style(header)}><v>#{v}</v></c>)

  defp cell(ref, v, header),
    do:
      ~s(<c r="#{ref}" t="inlineStr"#{style(header)}><is><t xml:space="preserve">#{escape(v)}</t></is></c>)

  defp style(true), do: ~s( s="1")
  defp style(false), do: ""

  defp col(n) when n < 26, do: <<?A + n>>
  defp col(n), do: col(div(n, 26) - 1) <> col(rem(n, 26))

  defp escape(v) do
    v
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    # strip characters that are invalid in XML 1.0
    |> String.replace(~r/[\x00-\x08\x0B\x0C\x0E-\x1F]/, "")
  end

  defp content_types do
    ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>) <>
      ~s(<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">) <>
      ~s(<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>) <>
      ~s(<Default Extension="xml" ContentType="application/xml"/>) <>
      ~s(<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>) <>
      ~s(<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>) <>
      ~s(<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>) <>
      "</Types>"
  end

  defp rels do
    ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>) <>
      ~s(<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">) <>
      ~s(<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>) <>
      "</Relationships>"
  end

  defp workbook(name) do
    name = name |> escape() |> String.replace(~r/[\\\/\?\*\[\]:]/, " ") |> String.slice(0, 31)

    ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>) <>
      ~s(<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">) <>
      ~s(<sheets><sheet name="#{name}" sheetId="1" r:id="rId1"/></sheets></workbook>)
  end

  defp workbook_rels do
    ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>) <>
      ~s(<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">) <>
      ~s(<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>) <>
      ~s(<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>) <>
      "</Relationships>"
  end

  defp styles do
    ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>) <>
      ~s(<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">) <>
      ~s(<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>) <>
      ~s(<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>) <>
      ~s(<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>) <>
      ~s(<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>) <>
      ~s(<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>) <>
      ~s(<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>) <>
      "</styleSheet>"
  end
end
