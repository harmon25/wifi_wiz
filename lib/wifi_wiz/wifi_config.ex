defmodule WifiWiz.Config do
  @moduledoc """
  Persisted wifi credential config via nvs
  """
  @namespace :wifi_wiz

  @doc "clear nvs persisted wifi config"
  def reset() do
    :esp.nvs_erase_all(@namespace)
  end

  @doc "get persisted wifi config from nvs"
  def get() do
    [
      ssid: :esp.nvs_get_binary(@namespace, :ssid, ""),
      psk: :esp.nvs_get_binary(@namespace, :psk, "")
    ]
  end

  @doc "persist wifi config"
  def put(ssid, psk) do
    :ok = :esp.nvs_put_binary(@namespace, :ssid, ssid)
    :ok = :esp.nvs_put_binary(@namespace, :psk, psk)

    conf = [
      ssid: ssid,
      psk: psk
    ]

    {:ok, conf}
  end
end
