# OpenInterclubs

Generates pre-filled, printable **uitslagenfiches / feuilles de résultats** for
KBSB/FRBE interclub encounters, using the public API at
<https://www.frbe-kbsb-ksb.be/docs>.

Pick a club, team and round. The fiche is filled in with division, series,
date, both teams and the board lineups from the KBSB site. Boards that have no
lineup yet (usually the visitors) can be filled in from the club's player
list. Print it, or save it as a PDF from the browser (A4 landscape).
`/print/:idclub/:round` renders every team of a club for one round, one page
per fiche.

## API endpoints used

| Endpoint | Used for |
|---|---|
| `GET /api/v1/interclubs/anon/icclub` | club list with teams (division, index, pairing number) |
| `GET /api/v1/interclubs/anon/icclub/{idclub}` | player list (names ↔ stamnummers) |
| `GET /api/v1/interclubs/anon/icresults/{division}/{index}` | series teams, rounds, dates, encounters, per-board lineup |

Responses are cached for 5 minutes in ETS.

## Development

    mix setup
    mix phx.server     # http://localhost:4000
    mix test

Needs Elixir ≥ 1.15. Set `HTTPS_PROXY` (and optionally `KBSB_CACERTFILE`) if
outbound traffic must go through a proxy.

## Deploying

No database. The generated `Dockerfile` (`mix phx.gen.release --docker`)
works on Fly.io, Render, etc. Set `SECRET_KEY_BASE` (`mix phx.gen.secret`),
`PHX_HOST` and `PORT`.
