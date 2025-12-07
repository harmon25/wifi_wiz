# WifiWiz

WiFi provisioning library for AtomVM - uses a captive portal in AP mode to configure and persist WiFi station credentials.

## Examples

Flash Demo

```sh
mix atomvm.esp32.flash --port /dev/tty.usbserial-014863E5
```

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

