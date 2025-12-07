defmodule WifiWiz.DNS do
  @moduledoc """
  Responds with address of ESP for all dns queries.
  this is used to create a captive portal to enter wifi credentials
  """

  # IP of the ESP32 in AP mode
  @ip {192, 168, 4, 1}

  def start(port \\ 53) do
    {:ok, socket} = :gen_udp.open(port, [:binary, active: true, ip: {0, 0, 0, 0}])
    loop(socket)
  end

  defp loop(socket) do
    receive do
      {:udp, _socket, ip, port, packet} ->
        response = spoof_dns_response(packet, @ip)
        :gen_udp.send(socket, ip, port, response)
        loop(socket)
    end
  end

  defp spoof_dns_response(query, ip) do
    <<id::binary-size(2), _flags::binary-size(2), qdcount::binary-size(2),
      _ancount::binary-size(2), nscount::binary-size(2), arcount::binary-size(2),
      rest::binary>> = query

    # Very naive implementation: only responds with an A record with our IP
    question = rest

    answer =
      <<0xC0, 0x0C, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x3C, 0x00, 0x04>> <>
        :erlang.list_to_binary(Tuple.to_list(ip))

    id <> <<0x81, 0x80>> <> qdcount <> <<0x00, 0x01>> <> nscount <> arcount <> question <> answer
  end
end
