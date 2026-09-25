defmodule OpenInterclubs.SeasonFixtures do
  @moduledoc "A tiny synthetic season: division 4B, three teams, two rounds."

  def clubs,
    do: [
      %{"idclub" => 401, "name" => "Gent", "teams" => [team(401, "Gent 1", 1)]},
      %{"idclub" => 472, "name" => "Mercatel", "teams" => [team(472, "Mercatel 2", 2)]},
      %{"idclub" => 109, "name" => "Borgerhout", "teams" => [team(109, "Borgerhout 3", 3)]}
    ]

  def team(club, name, pnr),
    do: %{
      "idclub" => club,
      "name" => name,
      "division" => 4,
      "index" => "B",
      "pairingnumber" => pnr
    }

  def players(club, ids),
    do:
      for(
        {id, r} <- ids,
        do: %{
          "idnumber" => id,
          "first_name" => "P#{id}",
          "last_name" => "L#{id}",
          "assignedrating" => r
        }
      )
      |> then(&%{"idclub" => club, "players" => &1})

  def details,
    do: %{
      401 => players(401, [{1, 2000}, {2, 1900}, {3, 1800}, {4, 1700}]),
      472 => players(472, [{11, 1800}, {12, 1800}, {13, 1600}, {14, 1500}]),
      109 => players(109, [{21, 1500}, {22, 1400}, {23, 1300}, {24, 1200}])
    }

  def game(h, v, res),
    do: %{"idnumber_home" => h, "idnumber_visit" => v, "result" => res, "overruled" => "NOR"}

  def series,
    do: [
      %{
        "division" => 4,
        "index" => "B",
        "teams" => [
          team(401, "Gent 1", 1),
          team(472, "Mercatel 2", 2),
          team(109, "Borgerhout 3", 3)
        ],
        "rounds" => [
          %{
            "round" => 1,
            "rdate" => "2026-09-27",
            "encounters" => [
              %{
                "pairingnr_home" => 1,
                "pairingnr_visit" => 2,
                "played" => false,
                "games" => [
                  game(1, 11, "1-0"),
                  game(2, 12, "½-½"),
                  game(3, 13, "0-1"),
                  game(4, 14, "1-0 FF")
                ]
              }
            ]
          },
          %{
            "round" => 2,
            "rdate" => "2026-10-11",
            "encounters" => [
              %{
                "pairingnr_home" => 3,
                "pairingnr_visit" => 1,
                "played" => false,
                "games" => [game(21, 1, "0-1"), game(22, 2, ""), game(23, 3, ""), game(24, 4, "")]
              }
            ]
          }
        ]
      }
    ]

  def model, do: OpenInterclubs.Season.Build.build(clubs(), details(), series())
end
