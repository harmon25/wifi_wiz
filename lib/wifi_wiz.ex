defmodule WifiWiz do
  @moduledoc """
  Documentation for `WifiWiz`.
  """

  @default_ap_config [ssid: "AtomVM AP", psk: "atomvm123"]

  @doc """
  Starts the WiFi access point with a captive portal.

  ## Options

    * `:ap` - Access point configuration keyword list with:
      * `:ssid` - The network name (default: `"AtomVM AP"`)
      * `:psk` - The network password (default: `"atomvm123"`)
    * `:sntp_host` - SNTP time-sync server hostname (default: `"time-d-b.nist.gov"`,
      `nil` to disable time sync)
    * `:pubsub` - Atom name of the `avm_pubsub` channel to publish status events on
      (default: `:pubsub`). All events are published on the topic `[:wifi_wiz, :wifi_status]`
      with the following messages:
      * `:connecting` — saved credentials found; attempting STA connection
      * `:ap_mode` — no saved credentials; launching captive portal AP
      * `{:ap_mode, ssid}` — AP network interface is up and serving the portal
      * `{:connected, {ip, gateway}}` — STA connected and got an IP
      * `:disconnected` — STA lost connection
      * `{:sta_retry, attempt, reason}` — STA connection attempt `attempt` failed with `reason`
      * `:sta_exhausted` — STA retry budget exhausted; about to wipe creds or return error
      * `{:credentials_saved, ssid}` — user submitted the captive portal form; reboot pending
      * `{:client_connected, mac}` — a device connected to the AP
      * `{:client_disconnected, mac}` — a device disconnected from the AP
    * `:sta_retry` - STA retry configuration keyword list:
      * `:max_duration_ms` - total time to keep retrying before giving up (default: 600_000)
      * `:backoff_base_ms` - delay for first retry, doubles each attempt (default: 5_000)
      * `:backoff_cap_ms` - maximum per-retry delay (default: 30_000)
      * `:on_exhausted` - `:wipe_and_reboot` (default) or `:return_error`

  ## Examples

      # Start with default configuration
      WifiWiz.start()

      # Start with custom SSID, password, and pubsub channel
      WifiWiz.start(ap: [ssid: "MyNetwork", psk: "secret123"], pubsub: :my_pubsub)

      # Subscribe to status events (using avm_pubsub)
      :avm_pubsub.sub(:pubsub, [:wifi_wiz, :wifi_status])
      receive do
        {:pubsub, [:wifi_wiz, :wifi_status], {:connected, {ip, _gateway}}} ->
          IO.inspect(ip, label: "got ip")
      end

  """
  def start(opts \\ [ap: @default_ap_config]) do
    # before booting up wifi - wait for things to settle.
    Process.sleep(100)
    WifiWiz.Ap.start(opts)
  end
end
