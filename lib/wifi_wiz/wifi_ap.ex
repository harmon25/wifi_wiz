defmodule WifiWiz.Ap do
  @moduledoc """
  Starts an AP for clients to connect to - they are issued an IP once connected.

  WIP - captive portal - to allow updating wifi credentials for STA mode
  """




  @doc """
  Wifi configuration helper

  If there are no saved wifi credentials an AP is booted up
  serving a captive portal to enter your wifi credentials
  """
  def start(opts) do
    ap_opts = Keyword.get(opts, :ap)
    #  WifiWiz.Config.reset()
    # if we have persisted ssid + psk connect as sta, do not run ap.
    nvs_config =  WifiWiz.Config.get()

    if nvs_config[:ssid] !== "" and nvs_config[:psk] !== "" do
      create_sta_config(nvs_config)
      |> start_sta()
    else
      create_ap_config(ap_opts[:ssid], ap_opts[:psk])
      |> start_ap()
    end
  end

  defp start_sta(config) do
    case :network.wait_for_sta(config[:sta], 10000) do
      {:ok, {ip, _mask, gateway}} ->
        IO.inspect("Got #{inspect(ip)} from #{inspect(gateway)}")

        Process.sleep(:infinity)

      {:error, reason} ->
        IO.inspect("failed to connect for #{reason}, clearing config + rebooting")
        Process.sleep(5000)
         WifiWiz.Config.reset()
        :esp.restart()
    end
  end

  defp start_ap(config) do
    case :network.start(config) do
      {:ok, _pid} ->
        IO.puts("AP Network started! - waiting for credentials")
        Process.sleep(:infinity)

      error ->
        error
    end
  end

  defp create_sta_config(nvs_config) do
    sta_config =
      [
        connected: fn ->
          IO.inspect("Connected to #{nvs_config[:ssid]}")
        end,
        got_ip: fn {ip, _netmask, gateway} ->
          IO.inspect("Got #{inspect(ip)} from #{inspect(gateway)}")
        end,
        disconnected: fn ->
          IO.inspect("Disconnected from #{nvs_config[:ssid]}")
          # must be bad creds? clear and reboot
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

  defp create_ap_config(ssid, psk) do
    ap_config = [
      ssid: ssid,
      psk: psk,
      ap_started: fn ->
        IO.puts("WifiWiz.AP Started ")

        spawn(fn -> WifiWiz.DNS.start() end)
        spawn(fn -> WifiWiz.CaptiveHTTP.start() end)
      end,
      sta_connected: fn mac ->
        IO.puts("STA connected with mac #{inspect(mac)}")
      end,
      sta_ip_assigned: fn ip ->
        IO.puts("STA assigned address #{inspect(ip)}")
      end,
      sta_disconnected: fn mac ->
        IO.puts("STA disconnected with mac #{inspect(mac)}")
      end
    ]

    [
      ap: ap_config
    ]
  end
end
