# wifi_wiz

WiFi provisioning library for **AtomVM/ESP32**. Starts a captive portal in AP mode to collect and persist WiFi credentials via NVS.

## Commands

| Command | Purpose |
|---|---|
| `mix compile` | Compile (expect cross-reference warnings — see below) |
| `mix format` | Format all source |
| `mix test` | Runs stub test suite — no real coverage of WiFi/ESP logic |
| `mix atomvm.esp32.flash --port /dev/tty.usbserial-<X>` | Flash firmware to ESP32 |

## Architecture

- `lib/wifi_wiz.ex` — public API (`WifiWiz.start/1`); default AP: SSID `"AtomVM AP"`, PSK `"atomvm123"`
- `lib/demo.ex` — entrypoint for flashing (`WifiWiz.Demo` — referenced in `mix.exs` `atomvm: [start: WifiWiz.Demo]`)
- `lib/wifi_wiz/wifi_ap.ex` — AP or STA startup; STA path used when saved credentials exist
- `lib/wifi_wiz/captive_http.ex` — HTTP server on port 80; serves form at `/`, saves credentials at `POST /save`, reboots via `:esp.restart()`
- `lib/wifi_wiz/dns.ex` — naive DNS responder on port 53; answers all queries with ESP IP `192.168.4.1` (captive portal trick)
- `lib/wifi_wiz/wifi_config.ex` — NVS-backed credential persistence via `:esp.nvs_*`

## Cross-reference warnings are expected

`mix.exs` sets `xref: [exclude: [:network, :esp]]`. These are AtomVM ERLANGFFI modules available only on-device. Compiler warnings about them are safe to ignore.

## Testing quirks

- `test/wifi_wiz_test.exs` is a stub — all assertions commented out
- Real testing requires flashing to an ESP32
- No integration or unit tests for HTTP server, DNS, or NVS logic

## Build artifacts

`.avm` files (`priv.avm`, `wifi_wiz.avm`, `deps.avm`) are gitignored build outputs.

## GitHub dependencies

- `exatomvm` — dev-only, git dep (`AtomVM/ExAtomVM`)
- `atomvm_httpd` — git dep (`harmon25/atomvm_httpd`)
