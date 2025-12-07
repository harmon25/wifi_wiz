defmodule WifiWiz.Demo do
  def start() do
    # this start function will block until wifi is configured + connected
    # can launch http servers or other network services right after.
    {:ok, {ip, _, _}} = WifiWiz.start()

    IO.puts("Wifi Connected with Ip: #{inspect(ip)}!\nDo Stuff Here...")

    :ok
  end
end
