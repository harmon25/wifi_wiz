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

  ## Examples

      # Start with default configuration
      WifiWiz.start()

      # Start with custom SSID and password
      WifiWiz.start(ap: [ssid: "MyNetwork", psk: "secret123"])

  """
  def start(opts \\ [ap: @default_ap_config]) do
    # before booting up wifi - wait for things to settle.
    Process.sleep(100)
    WifiWiz.Ap.start(opts)
  end
end
