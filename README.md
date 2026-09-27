# OpenInterclubs

Results, standings, players and printable result sheets (*uitslagenfiches*)
for the KBSB/FRBE chess interclubs, built on the public API at
<https://www.frbe-kbsb-ksb.be/docs>.

## What it does

**For everyone** (no login):

- **Uitslagen** – all encounters of a round across every series, with live
  scores while a round is being played.
- **Afdelingen** – every series with its ranking (*rangschikking*), a cross
  table (*onderlinge resultaten*) and results per round.
- **Clubs / ploegen** – teams with their position, players, playing hall,
  and a calendar feed (`.ics`) per team.
- **Spelers** – player cards (ratings, score, TPR, all games) and a ranking
  by TPR with filters.
- **Uitslagenfiche** – a replica of the paper result sheet, with the
  interclub rating after every name. The print page of a club puts all its
  sheets of a round on separate pages, or downloads them as one ZIP with a
  PDF per sheet (`clubname_clubnumber_RXX_series.pdf`).

**For club and interclub admins** (KBSB login):

- The result sheets fill in your **own** team's lineup (home or away),
  for the club you selected. The opponent's side is never filled.
- **Clubbeheer** (`/beheer/:club/:round`): all teams of your club in a
  round. Before the round, edit the lineups, check them against the KBSB
  rules and submit them. Once the round is open, enter and save the results.

## Security model

Lineups are only shown to the club they belong to. The app:

1. logs in with the member's KBSB login; the password is passed to the KBSB
   once and never stored, the token lives in an encrypted session cookie
   (12 hours);
2. asks the KBSB whether that member has a role (interclub admin, captain,
   club admin) in the **selected** club – never for the opponent;
3. only takes that club's own side of each encounter from the KBSB answer.

Without access an error is shown and nothing is filled.

## Data

| Endpoint | Used for |
|---|---|
| `interclubs/anon/icclub[/{id}]` | clubs, teams, player lists |
| `interclubs/anon/icresults/{div}/{idx}` | series, rounds, results (encounters appear once a round is open; before that the pairings are rebuilt from the fixed KBSB schedules) |
| `interclubs/anon/venue/{id}` | playing halls |
| `member/login` | KBSB login |
| `clubs/clb/club/{id}/access/{role}` | role check for the selected club |
| `interclubs/clb/icseries` | the club's own lineups |
| `interclubs/clb/icplanning[validate]` | check / submit lineups |
| `interclubs/clb/icresults` | save results |

The whole season is loaded in memory in the background (every 15 minutes,
every 2 minutes on Sundays) and open pages update live. There is no
database.

## Development

    mix setup
    mix phx.server     # http://localhost:4000
    mix precommit      # compile with warnings as errors, format, test

Elixir 1.18 / Erlang/OTP 27. Set `HTTPS_PROXY` (and optionally
`KBSB_CACERTFILE`) if outbound traffic must go through a proxy. CI runs the
tests and a Docker build on every push.

## Deploying

The `Dockerfile` works on Render, Fly.io, etc. Set `SECRET_KEY_BASE`
(`mix phx.gen.secret`), `PHX_HOST` (e.g. `openinterclubs.zerotwo.cloud`) and
`PORT`. On Render, the service's own `*.onrender.com` address is accepted
too.
