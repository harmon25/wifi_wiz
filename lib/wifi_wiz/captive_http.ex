defmodule WifiWiz.CaptiveHTTP do
  @moduledoc """
  Minimal captive portal web server for entering wifi credentials.
  Designed for severe RAM constraints (ESP32-C3 / AtomVM).
  """

  @compile {:no_warn_undefined, [:avm_pubsub]}

  def start(scan_results, pubsub_channel, port \\ 80) do
    config = [
      {[],
       %{
         handler: __MODULE__,
         handler_config: %{scan_results: scan_results, pubsub_channel: pubsub_channel}
       }}
    ]

    :io.format("Starting httpd on port ~p~n", [port])

    case AtomvmHttpd.start(port, config) do
      {:ok, pid} ->
        IO.puts("httpd started")
        {:ok, pid}

      err ->
        :io.format("An error occurred: ~p~n", [err])
        {:error, err}
    end
  end

  def init_handler(suffix, config) do
    results =
      case Map.get(config, :scan_results) do
        nil -> []
        r -> r
      end

    pubsub_channel = Map.get(config, :pubsub_channel, :pubsub)

    {:ok, %{path_suffix: suffix, scan_results: results, pubsub_channel: pubsub_channel}}
  end

  # Build option iolists — never creates intermediate concatenated binaries.
  defp opt_lines([], acc), do: :lists.reverse(acc)

  defp opt_lines([net | rest], acc) do
    ssid = escape_html(Map.get(net, :ssid, ""))
    rssi = Map.get(net, :rssi, 0)

    opt = [
      "<option value=\"",
      ssid,
      "\">",
      ssid,
      " (",
      :erlang.integer_to_binary(rssi),
      " dBm)</option>"
    ]

    opt_lines(rest, [opt | acc])
  end

  def handle_http_req(req, state) do
    :io.format("HTTP req method=~p~n", [Map.get(req, :method)])

    case Map.get(req, :method) do
      :get ->
        nets =
          case Map.get(state, :scan_results) do
            nil -> []
            r -> r
          end

        :io.format("HTTP rendering ~p nets~n", [:erlang.length(nets)])
        options = opt_lines(nets, [])

        body = [
          "<h1>WiFi Setup</h1>",
          "<form method=\"POST\" action=\"/save\">",
          "<label>Network</label>",
          "<select onchange=\"document.getElementById('s').value=this.value=='__custom__'?'':this.value\">",
          "<option value=\"\">-- Select --</option>",
          options,
          "<option value=\"__custom__\">Custom...</option>",
          "</select>",
          "<label>SSID</label>",
          "<input id=\"s\" name=\"ssid\" type=\"text\" required placeholder=\"SSID\">",
          "<label>Password</label>",
          "<input name=\"psk\" type=\"password\" required placeholder=\"Password\">",
          "<button>Connect</button>",
          "</form>"
        ]

        {:close, %{"Content-Type" => "text/html"}, html_page(body)}

      :post ->
        %{body: body} = req
        params = parse_form_body(body)
        ssid = Map.get(params, :ssid)
        psk = Map.get(params, :psk)

        :io.format("HTTP post for ssid=~p~n", [ssid])

        cond do
          ssid in [nil, ""] or psk in [nil, ""] ->
            err_body = [
              "<h2>Missing credentials</h2>",
              "<p>SSID and password are required.</p>",
              "<p><a href=\"/\">Try again</a></p>"
            ]

            {:close, %{"Content-Type" => "text/html"}, html_page(err_body)}

          true ->
            {:ok, config} = WifiWiz.Config.put(ssid, psk)
            saved_ssid = :proplists.get_value(:ssid, config)
            pubsub_channel = Map.get(state, :pubsub_channel, :pubsub)

            :avm_pubsub.pub(
              pubsub_channel,
              [:wifi_wiz, :wifi_status],
              {:credentials_saved, saved_ssid}
            )

            body = [
              "<h2>Saved</h2>",
              "<p>Connecting to ",
              escape_html(saved_ssid),
              "...</p>",
              "<script>setTimeout(()=>window.close(),5500)</script>"
            ]

            spawn(fn ->
              Process.sleep(5000)
              :esp.restart()
            end)

            {:close, %{"Content-Type" => "text/html"}, html_page(body)}
        end

      _ ->
        {:error, :internal_server_error}
    end
  end

  defp parse_form_body(body) do
    :lists.foldl(
      fn
        "ssid=" <> ssid, acc -> Map.put(acc, :ssid, url_decode(ssid))
        "psk=" <> psk, acc -> Map.put(acc, :psk, url_decode(psk))
        _, acc -> acc
      end,
      %{},
      :binary.split(body, "&", [:global])
    )
  end

  # Minimal application/x-www-form-urlencoded decoder.
  # Converts '+' to space, then decodes '%XX' percent-encoded sequences.
  defp url_decode(binary) do
    binary
    |> :binary.replace("+", " ", [:global])
    |> percent_decode()
  end

  defp percent_decode(<<>>), do: <<>>

  defp percent_decode(<<"%", h1, h2, rest::binary>>) do
    # Malformed sequences (e.g. "%ZZ") would crash list_to_integer/2; fall back
    # to emitting the literal bytes so user input can't take down the portal.
    try do
      :erlang.list_to_integer([h1, h2], 16)
    rescue
      _ -> :error
    else
      byte -> {:ok, byte}
    end
    |> case do
      {:ok, byte} -> <<byte::8, percent_decode(rest)::binary>>
      :error -> <<"%", h1, h2, percent_decode(rest)::binary>>
    end
  end

  defp percent_decode(<<c, rest::binary>>) do
    <<c, percent_decode(rest)::binary>>
  end

  defp escape_html(binary) when is_binary(binary) do
    binary
    |> :binary.replace("&", "&amp;", [:global])
    |> :binary.replace("<", "&lt;", [:global])
    |> :binary.replace(">", "&gt;", [:global])
    |> :binary.replace(~S("), ~S(&quot;), [:global])
  end

  defp escape_html(_), do: ""

  # Build the full page as an iolist, then convert to a single binary once.
  defp html_page(body) do
    :erlang.iolist_to_binary([
      "<!DOCTYPE html><html><head><meta charset=\"UTF-8\">",
      "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">",
      "<title>WiFi</title><style>",
      "body{font-family:sans-serif;margin:0;padding:16px;background:#f0f0f0}",
      ".card{background:#fff;padding:20px;border-radius:8px;",
      "box-shadow:0 2px 8px rgba(0,0,0,0.1);width:100%;max-width:320px;margin:auto}",
      "h1,h2{margin:0 0 12px;font-size:20px;text-align:center}",
      "label{display:block;margin:8px 0 4px;font-size:14px;font-weight:bold}",
      "input,select,button{width:100%;padding:10px;border:1px solid #ccc;",
      "border-radius:4px;box-sizing:border-box;font-size:16px;margin-bottom:8px}",
      "button{background:#2563eb;color:#fff;border:none;cursor:pointer}",
      "</style></head><body><div class=\"card\">",
      body,
      "</div></body></html>"
    ])
  end
end
