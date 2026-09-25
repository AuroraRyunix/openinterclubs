defmodule OpenInterclubs.Season do
  @moduledoc """
  In-memory model of the current interclub season.

  A loader process pulls everything from the KBSB API on boot and then every
  `:refresh_ms` (more often on match days), rebuilds the model with
  `OpenInterclubs.Season.Build` and stores it in ETS. LiveViews read from ETS
  and subscribe to `topic/0` to re-render when new results arrive.
  """
  use GenServer
  require Logger

  alias OpenInterclubs.Kbsb
  alias OpenInterclubs.Season.Build

  @table __MODULE__
  @topic "season"
  @concurrency 8

  # ---- read API ----------------------------------------------------------

  def topic, do: @topic
  def subscribe, do: Phoenix.PubSub.subscribe(OpenInterclubs.PubSub, @topic)

  def loaded?, do: get(:loaded_at) != nil
  def loaded_at, do: get(:loaded_at)

  def clubs, do: get(:clubs, %{})
  def club(id), do: Map.get(clubs(), id)
  def teams, do: get(:teams, %{})
  def team(key), do: Map.get(teams(), key)
  def series, do: get(:series, %{})
  def series(key), do: Map.get(series(), key)
  @doc "Light player rows (no games) for search and rankings."
  def players, do: get(:player_index, [])
  def player(id), do: get({:player, id})
  def players(ids), do: ids |> Enum.map(&player/1) |> Enum.reject(&is_nil/1)
  def rounds, do: get(:rounds, [])

  @doc "The round being played now or next (by date), else the last one."
  def current_round(today \\ Date.utc_today()) do
    rs = rounds()

    case Enum.find(rs, &(&1.date && Date.compare(&1.date, Date.add(today, -1)) != :lt)) do
      nil -> rs |> List.last() |> then(&(&1 && &1.round)) || 1
      r -> r.round
    end
  end

  @doc "All encounters of a round across every series, in series order."
  def encounters(round) do
    series()
    |> Map.values()
    |> Enum.sort_by(& &1.key)
    |> Enum.map(fn s -> {s, Enum.find(s.rounds, &(&1.round == round))} end)
    |> Enum.reject(fn {_, r} -> is_nil(r) end)
    |> Enum.map(fn {s, r} -> {s, r.encounters} end)
  end

  def encounter(series_key, round, home_team) do
    with %{} = s <- series(series_key),
         %{} = r <- Enum.find(s.rounds, &(&1.round == round)) do
      Enum.find(r.encounters, &(&1.home == home_team))
    end
  end

  @doc "Encounters of one team, one per round."
  def team_encounters(key) do
    with %{series: sk} <- team(key), %{} = s <- series(sk) do
      for r <- s.rounds, e <- r.encounters, key in [e.home, e.visit], do: e
    else
      _ -> []
    end
  end

  defp get(key, default \\ nil) do
    case :ets.lookup(@table, key) do
      [{^key, v}] -> v
      _ -> default
    end
  rescue
    ArgumentError -> default
  end

  @doc "Store an already built model (used by tests and the loader)."
  def put(model) do
    {players, model} = Map.pop(model, :players, %{})
    for {k, v} <- model, do: :ets.insert(@table, {k, v})
    :ets.insert(@table, Enum.map(players, fn {id, p} -> {{:player, id}, p} end))

    index =
      players
      |> Map.values()
      |> Enum.map(&Map.delete(&1, :games))
      |> Enum.sort_by(&{&1.last_name, &1.first_name})

    :ets.insert(@table, {:player_index, index})
    :ets.insert(@table, {:loaded_at, DateTime.utc_now()})
    Phoenix.PubSub.broadcast(OpenInterclubs.PubSub, @topic, :season_updated)
    :ok
  end

  def refresh, do: GenServer.cast(__MODULE__, :refresh)

  # ---- loader ------------------------------------------------------------

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    autoload = Keyword.get(opts, :autoload, true)
    if autoload, do: send(self(), :refresh)
    {:ok, %{autoload: autoload}}
  end

  @impl true
  def handle_cast(:refresh, state) do
    send(self(), :refresh)
    {:noreply, state}
  end

  @impl true
  def handle_info(:refresh, state) do
    started = System.monotonic_time(:millisecond)

    case load() do
      {:ok, model} ->
        put(model)

        Logger.info(
          "season loaded: #{map_size(model.series)} series, #{map_size(model.players)} players " <>
            "in #{System.monotonic_time(:millisecond) - started} ms"
        )

      {:error, reason} ->
        Logger.warning("season load failed: #{inspect(reason)}")
    end

    if state.autoload, do: Process.send_after(self(), :refresh, interval())
    {:noreply, state}
  end

  # Sundays (match day) refresh every 2 minutes, otherwise every 15.
  defp interval do
    if Date.day_of_week(Date.utc_today()) == 7, do: :timer.minutes(2), else: :timer.minutes(15)
  end

  defp load do
    with {:ok, clubs} <- Kbsb.clubs() do
      clubs = Enum.filter(clubs, &(&1["teams"] != []))

      series_keys =
        clubs
        |> Enum.flat_map(& &1["teams"])
        |> Enum.map(&{&1["division"], &1["index"] || ""})
        |> Enum.uniq()

      details =
        clubs
        |> fetch_all(fn c -> {c["idclub"], Kbsb.club(c["idclub"])} end)
        |> Enum.flat_map(fn
          {id, {:ok, d}} -> [{id, d}]
          _ -> []
        end)
        |> Map.new()

      series =
        series_keys
        |> fetch_all(fn {d, i} -> Kbsb.series(d, i) end)
        |> Enum.flat_map(fn
          {:ok, s} -> [s]
          _ -> []
        end)

      {:ok, Build.build(clubs, details, series)}
    end
  end

  defp fetch_all(items, fun) do
    items
    |> Task.async_stream(fun,
      max_concurrency: @concurrency,
      timeout: 60_000,
      on_timeout: :kill_task
    )
    |> Enum.flat_map(fn
      {:ok, v} -> [v]
      _ -> []
    end)
  end
end
