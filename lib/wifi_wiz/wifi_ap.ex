defmodule WifiWiz.Ap do
  @moduledoc """
  Starts an AP for clients to connect to - they are issued an IP once connected.

  WIP - captive portal - to allow updating wifi credentials for STA mode
  """

  @default_sta_retry [
    max_duration_ms: 600_000,
    backoff_base_ms: 5_000,
    backoff_cap_ms: 30_000,
    on_exhausted: :wipe_and_reboot
  ]

  @doc """
  Wifi configuration helper

  If there are no saved wifi credentials an AP is booted up
  serving a captive portal to enter your wifi credentials

  ## Options

    * `:ap` - Access point configuration keyword list (passed through)
    * `:sta_retry` - STA retry configuration keyword list:
      * `:max_duration_ms` - total time to keep retrying before giving up (default: 600_000)
      * `:backoff_base_ms` - delay for first retry, doubles each attempt (default: 5_000)
      * `:backoff_cap_ms` - maximum per-retry delay (default: 30_000)
      * `:on_exhausted` - `:wipe_and_reboot` (default) or `:return_error`
  """
  def start(opts) do
    ap_opts = Keyword.get(opts, :ap)
    sta_retry_opts = Keyword.get(opts, :sta_retry, [])
    nvs_config = WifiWiz.Config.get()

    if nvs_config[:ssid] !== "" and nvs_config[:psk] !== "" do
      config = create_sta_config(nvs_config)
      start_sta(config, sta_retry_opts)
    else
      cbs = Keyword.take(ap_opts, [:ap_started])

      create_ap_config(ap_opts[:ssid], ap_opts[:psk], cbs)
      |> start_ap()
    end
  end

  defp start_sta(config, sta_retry_opts) do
    retry = Keyword.merge(@default_sta_retry, sta_retry_opts)
    start_sta(config, retry[:max_duration_ms], retry[:backoff_base_ms], retry[:backoff_cap_ms],
      retry[:on_exhausted], 0, 0)
  end

  defp start_sta(_config, max_ms, _base_ms, _cap_ms, on_exhausted, _attempt, elapsed)
       when elapsed >= max_ms do
    :io.format("STA retry exhausted after ~ps~n", [div(elapsed, 1000)])

    case on_exhausted do
      :return_error ->
        Process.sleep(100)
        {:error, :sta_exhausted}

      :wipe_and_reboot ->
        IO.puts("Clearing creds + rebooting")
        WifiWiz.Config.reset()
        Process.sleep(5000)
        :esp.restart()
    end
  end

  defp start_sta(config, max_ms, base_ms, cap_ms, on_exhausted, attempt, elapsed) do
    case :network.wait_for_sta(config[:sta]) do
      {:ok, {ip, _mask, _gateway}} ->
        :io.format("Got ~p~n", [ip])
        Process.sleep(:infinity)

      {:error, {:already_started, _pid}} ->
        :io.format("WiFi already started, stopping and retrying~n")
        :network.stop()
        Process.sleep(1000)
        start_sta(config, max_ms, base_ms, cap_ms, on_exhausted, attempt, elapsed + 1000)

      {:error, reason} ->
        :io.format("Attempt ~p failed (~p), retry in ~ps~n", [
          attempt + 1,
          reason,
          div(backoff_ms(attempt, base_ms, cap_ms), 1000)
        ])

        :network.stop()
        backoff = backoff_ms(attempt, base_ms, cap_ms)
        Process.sleep(backoff)
        start_sta(config, max_ms, base_ms, cap_ms, on_exhausted, attempt + 1, elapsed + backoff)
    end
  end

  defp backoff_ms(0, base, _cap), do: base
  defp backoff_ms(1, base, _cap), do: base * 2
  defp backoff_ms(2, base, _cap), do: base * 4

  defp backoff_ms(_attempt, _base, cap) do
    cap
  end

  @doc """
  Start AP mode with the given config. Blocks indefinitely.
  Useful as a fallback when STA retries are exhausted.
  """
  def start_ap(config) do
    case :network.start(config) do
      {:ok, _pid} ->
        IO.puts("AP Network started! - waiting for credentials")
        Process.sleep(:infinity)

      {:error, {:already_started, _pid}} ->
        IO.puts("AP already running, blocking")
        Process.sleep(:infinity)

      error ->
        error
    end
  end

  defp create_sta_config(nvs_config) do
    sta_config =
      [
        connected: fn ->
          :io.format("Connected to ~s~n", [nvs_config[:ssid]])
        end,
        got_ip: fn {ip, _netmask, gateway} ->
          :io.format("Got ~p from ~p~n", [ip, gateway])
        end,
        disconnected: fn ->
          IO.puts("Disconnected — rebooting to retry")
          :esp.restart()
        end
      ] ++
        nvs_config

    # snpm_config = [
    #   host: "time-d-b.nist.gov",
    #   synchronized: fn {tv_sec, tv_usec} ->
    #     IO.inspect("Synchronized time with SNTP server. tv_sec=#{tv_sec} tv_usec=#{tv_usec}")
    #   end
    # ]

    [
      sta: sta_config
      # snpm: snpm_config
    ]
  end

  @doc """
  Build the AP + managed STA config tuple for `:network.start/1`.
  """
  def create_ap_config(ssid, psk, callbacks) do
    ap_started = callbacks[:ap_started] || fn -> :ok end

    ap_config = [
      ssid: ssid,
      psk: psk,
      ap_started: fn ->
        IO.puts("WifiWiz.AP Started ")
        spawn(fn -> WifiWiz.DNS.start() end)

        spawn(fn ->
          Process.sleep(2000)

          IO.puts("WifiWiz: scanning...")
          scan_result = :network.wifi_scan([{:results, 10}, {:dwell, 300}])

          networks =
            case scan_result do
              {:ok, {num, nets}} ->
                :io.format("WifiWiz: got ~p nets~n", [num])
                nets

              _other ->
                IO.puts("WifiWiz: scan fail")
                []
            end

          filtered =
            :lists.filter(
              fn net -> Map.get(net, :ssid, "") != "" end,
              networks
            )

          sorted =
            :lists.sort(
              fn a, b -> Map.get(a, :rssi, -100) >= Map.get(b, :rssi, -100) end,
              filtered
            )

          deduped =
            :lists.foldl(
              fn net, acc ->
                ssid = Map.get(net, :ssid)

                case :lists.any(fn n -> Map.get(n, :ssid) == ssid end, acc) do
                  true -> acc
                  false -> [net | acc]
                end
              end,
              [],
              sorted
            )

          sorted = :lists.reverse(deduped)

          :lists.foreach(
            fn net ->
              :io.format("SSID: ~s RSSI: ~p~n", [Map.get(net, :ssid, ""), Map.get(net, :rssi, 0)])
            end,
            sorted
          )

          WifiWiz.CaptiveHTTP.start(sorted)
        end)

        ap_started.()
      end,
      sta_connected: fn mac ->
        :io.format("STA connected with mac ~p~n", [mac])
      end,
      sta_ip_assigned: fn ip ->
        :io.format("STA assigned address ~p~n", [ip])
      end,
      sta_disconnected: fn mac ->
        :io.format("STA disconnected with mac ~p~n", [mac])
      end
    ]

    [
      ap: ap_config,
      sta: [:managed]
    ]
  end
end
