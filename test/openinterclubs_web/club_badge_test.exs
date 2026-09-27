defmodule OpenInterclubsWeb.ClubBadgeTest do
  use ExUnit.Case, async: true

  import OpenInterclubsWeb.UI, only: [initials: 1]

  test "initials skip particles and club prefixes" do
    assert initials("de Mercatel") == "ME"
    assert initials("Jean Jaures Gent") == "JJ"
    assert initials("KOSK") == "KO"
    assert initials("Het Pientere Paard") == "PP"
    assert initials("Standard de Liège") == "SL"
    assert initials("Eisden/MSK-Dilsen") == "EM"
    assert initials("") == "?"
  end
end
