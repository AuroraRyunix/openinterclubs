defmodule OpenInterclubs.Kbsb.Cache do
  @moduledoc "Tiny ETS-backed TTL cache for API responses. Only successes are cached."
  use GenServer

  @table __MODULE__
  @ttl_ms :timer.minutes(5)

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def fetch(key, fun) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, key) do
      [{^key, value, expires}] when expires > now ->
        {:ok, value}

      _ ->
        with {:ok, value} <- fun.() do
          :ets.insert(@table, {key, value, now + @ttl_ms})
          {:ok, value}
        end
    end
  end

  def delete_matching(fun) do
    for {key, _, _} <- :ets.tab2list(@table), fun.(key), do: :ets.delete(@table, key)
    :ok
  end

  def clear, do: :ets.delete_all_objects(@table)

  @impl true
  def init(nil) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, nil}
  end
end
