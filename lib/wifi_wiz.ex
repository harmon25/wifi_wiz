defmodule WifiWiz do
  @moduledoc """
  Documentation for `WifiWiz`.
  """

  @default_ap_config [ssid: "AtomVM AP", psk: "atomvm123"]

  @doc """

  """
  def start(opts \\ [ap: @default_ap_config]) do
    WifiWiz.Ap.start(opts)
  end
end
