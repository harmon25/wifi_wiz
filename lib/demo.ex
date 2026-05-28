defmodule WifiWiz.Demo do
  def start() do
    # this start function will block until wifi is configured + connected
    # can launch http servers or other network services right after.
    {:ok, {ip, _, _}} = WifiWiz.start()

    :io.format("Wifi Connected with Ip: ~p!~nDo Stuff Here...~n", [ip])

    :ok
  end
end
