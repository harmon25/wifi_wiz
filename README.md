# WifiWiz

WiFi provisioning library for AtomVM - uses a captive portal in AP mode to configure and persist WiFi station credentials.

## Usage

```elixir
# Simplest usage — blocks until connected
{:ok, {ip, _, _}} = WifiWiz.start()

# Custom AP credentials
WifiWiz.start(ap: [ssid: "MySetup", psk: "secret123"])

# Custom pubsub channel
WifiWiz.start(pubsub: :my_pubsub)
```

## PubSub Events

WifiWiz publishes status events via `avm_pubsub` so your application can react to WiFi lifecycle changes without polling.

**Topic:** `[:wifi_wiz, :wifi_status]`  
**Default channel:** `:pubsub` (override with the `:pubsub` option)

| Message | When |
|---|---|
| `:connecting` | Saved credentials found; attempting STA connection |
| `:ap_mode` | No saved credentials; launching captive portal AP |
| `{:ap_mode, ssid}` | AP network interface is up and serving the portal |
| `{:connected, {ip, gateway}}` | STA connected and received an IP address |
| `:disconnected` | STA lost connection |
| `{:sta_retry, attempt, reason}` | STA connection attempt failed; will retry |
| `:sta_exhausted` | STA retry budget exhausted; wiping creds or returning error |
| `{:credentials_saved, ssid}` | User submitted the captive portal form; reboot pending |
| `{:client_connected, mac}` | A device connected to the AP |
| `{:client_disconnected, mac}` | A device disconnected from the AP |

### Subscribing

```elixir
:avm_pubsub.sub(:pubsub, [:wifi_wiz, :wifi_status])

receive do
  {:pubsub, [:wifi_wiz, :wifi_status], {:connected, {ip, _gateway}}} ->
    :io.format("Connected! IP: ~p~n", [ip])

  {:pubsub, [:wifi_wiz, :wifi_status], {:sta_retry, attempt, reason}} ->
    :io.format("Retry ~p: ~p~n", [attempt, reason])

  {:pubsub, [:wifi_wiz, :wifi_status], :sta_exhausted} ->
    IO.puts("Giving up on STA connection")
end
```

## Options

| Option | Default | Description |
|---|---|---|
| `:ap` | `[ssid: "AtomVM AP", psk: "atomvm123"]` | AP mode SSID and PSK |
| `:pubsub` | `:pubsub` | `avm_pubsub` channel atom for status events |
| `:sntp_host` | `"time-d-b.nist.gov"` | SNTP time-sync server hostname (`nil` to disable) |
| `:sta_retry` | see below | STA reconnection retry config |

### `:sta_retry` options

| Key | Default | Description |
|---|---|---|
| `:max_duration_ms` | `600_000` | Total retry window before giving up |
| `:backoff_base_ms` | `5_000` | Initial retry delay (doubles each attempt) |
| `:backoff_cap_ms` | `30_000` | Maximum per-retry delay |
| `:on_exhausted` | `:wipe_and_reboot` | `:wipe_and_reboot` or `:return_error` |

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `wifi_wiz` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:wifi_wiz, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/wifi_wiz>.

## Flashing

```sh
mix atomvm.esp32.flash --port /dev/tty.usbserial-014863E5
```
