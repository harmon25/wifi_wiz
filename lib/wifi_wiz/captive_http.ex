defmodule WifiWiz.CaptiveHTTP do
  @moduledoc """
  Captive portal web server for entering wifi credentials
  """
  @page_title "Wifi Setup"

  def start(scan_results, port \\ 80) do
    config = [
      {[],
       %{
         handler: __MODULE__,
         scan_results: scan_results
       }}
    ]

    IO.puts("Starting httpd on port #{port}")

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
    {:ok, %{path_suffix: suffix, scan_results: config[:scan_results] || []}}
  end

  def handle_http_req(%{method: :get} = _req, state) do
    options =
      (state[:scan_results] || [])
      |> Enum.map(fn net ->
        ssid = escape_html(Map.get(net, :ssid, ""))
        rssi = Map.get(net, :rssi, 0)
        ~s[<option value="#{ssid}">#{ssid} (#{rssi} dBm)</option>]
      end)
      |> Enum.join("\n      ")

    body = """
    <main class="card">
      <h1>AtomVM Wi-Fi Setup</h1>
      <p>Select or enter your network SSID and passphrase.</p>
      <form method="POST" action="/save">
        <label for="network-select">Available networks</label>
        <select id="network-select" onchange="fillSSID(this)">
          <option value="">-- Select a network --</option>
          #{options}
          <option value="__custom__">Custom network...</option>
        </select>
        <label for="ssid">Network SSID</label>
        <input id="ssid" name="ssid" type="text" inputmode="text" autocapitalize="none" autocomplete="off" required />
        <label for="psk">Passphrase</label>
        <input id="psk" name="psk" type="password" inputmode="text" autocapitalize="none" autocomplete="off" required />
        <button type="submit">Save and Connect</button>
      </form>
      <script>
        function fillSSID(sel) {
          var val = sel.value;
          document.getElementById('ssid').value = val === '__custom__' ? '' : val;
        }
      </script>
    </main>
    """

    {:close, %{"Content-Type" => "text/html"}, render_html(body)}
  end

  def handle_http_req(%{method: :post} = req, _state) do
    %{
      headers: _headers,
      body: body
    } = req

    # extract body (ssid + psk and store in nvs)
    params = parse_form_body(body)
    IO.puts("received params:\n#{inspect(params)}")
    {:ok, config} = WifiWiz.Config.put(params.ssid, params.psk)

    body = """
    <section class="card">
      <h2>Connecting to #{config[:ssid]}...</h2>
      <p>Your credentials were received. Attempting to join the network now.</p>
      <p>The device may reboot or reconnect shortly. Feel free to close this tab.</p>
    </section>
    <script>
      setTimeout(()=>{
       window.close()
      }, 5500)
    </script>
    """

    # restart after responding to post req
    spawn(fn ->
      Process.sleep(5000)
      :esp.restart()
    end)

    {:close, %{"Content-Type" => "text/html"}, render_html(body)}
  end

  def handle_http_req(_req, _state) do
    {:error, :internal_server_error}
  end

  # decode application/x-www-form-urlencoded payloads into a map without URI helpers
  def parse_form_body(body) do
    body
    |> :binary.split("&")
    |> Enum.reduce(%{}, fn
      "ssid=" <> ssid, acc -> Map.put(acc, :ssid, ssid)
      "psk=" <> psk, acc -> Map.put(acc, :psk, psk)
      _, acc -> acc
    end)
  end

  defp escape_html(binary) when is_binary(binary) do
    binary
    |> :binary.replace("&", "&amp;", [:global])
    |> :binary.replace("<", "&lt;", [:global])
    |> :binary.replace(">", "&gt;", [:global])
    |> :binary.replace(~S("), ~S(&quot;), [:global])
  end

  defp escape_html(_), do: ""

  defp render_html(contents, title \\ @page_title) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="UTF-8" />
    <title>#{title}</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style>
    :root { color-scheme: light dark; font-family: -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif; line-height: 1.5; }
    *, *::before, *::after { box-sizing: border-box; }
    body { margin: 0; min-height: 100dvh; display: flex; align-items: center; justify-content: center; padding: clamp(16px, 6vw, 24px); background-color: #f3f4f6; color: #111827; }
    .card { width: min(320px, 100%); padding: clamp(18px, 5vw, 24px); border-radius: 18px; border: 1px solid rgba(15, 23, 42, 0.12); background: rgba(255, 255, 255, 0.94); box-shadow: 0 18px 36px rgba(15, 23, 42, 0.12); backdrop-filter: blur(6px); margin: 0 auto; }
    h1 { margin: 0 0 10px; font-size: clamp(20px, 3vw, 24px); font-weight: 650; text-align: center; }
    h2 { margin: 0 0 12px; font-size: clamp(20px, 3vw, 24px); font-weight: 650; text-align: center; }
    p { margin: 0 0 20px; font-size: clamp(14px, 2.5vw, 16px); text-align: center; color: #4b5563; }
    form { display: grid; gap: 8px; width: 100%; }
    label { display: block; font-size: 14px; font-weight: 600; margin-bottom: 4px; color: #1f2937; }
    input[type=\"text\"], input[type=\"password\"] { width: 100%; padding: 10px 12px; border-radius: 12px; border: 1px solid rgba(15, 23, 42, 0.16); background: rgba(249, 250, 251, 0.9); color: inherit; transition: border-color 0.2s ease, box-shadow 0.2s ease; font-size: 16px; }
    input[type=\"text\"]:focus, input[type=\"password\"]:focus { outline: none; border-color: #2563eb; box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.18); }
    button { width: 100%; padding: 10px 16px; border-radius: 999px; border: none; background: linear-gradient(135deg, #2563eb, #1d4ed8); color: #f9fafb; font-weight: 600; font-size: 16px; cursor: pointer; transition: transform 0.2s ease, box-shadow 0.2s ease; }
    button:hover { transform: translateY(-1px); box-shadow: 0 12px 16px rgba(37, 99, 235, 0.25); }
    button:focus-visible { outline: none; box-shadow: 0 0 0 4px rgba(37, 99, 235, 0.3); }
    @media (max-width: 480px) {
      body { padding: 10px; }
      .card { border-radius: 16px; padding: 16px; box-shadow: 0 14px 28px rgba(15, 23, 42, 0.12); }
      p { margin-bottom: 16px; }
    }
    @media (min-width: 768px) {
      body { padding: 48px; }
      form { gap: 16px; }
    }
    @media (prefers-color-scheme: dark) {
      body { background-color: #0f172a; color: #e2e8f0; }
      .card { background: rgba(15, 23, 42, 0.85); border: 1px solid rgba(148, 163, 184, 0.2); box-shadow: 0 24px 48px rgba(2, 6, 23, 0.6); }
      p { color: #cbd5f5; }
      label { color: #e2e8f0; }
      input[type=\"text\"], input[type=\"password\"] { background: rgba(15, 23, 42, 0.7); border: 1px solid rgba(148, 163, 184, 0.35); color: #f8fafc; }
      input[type=\"text\"]:focus, input[type=\"password\"]:focus { border-color: #38bdf8; box-shadow: 0 0 0 4px rgba(56, 189, 248, 0.22); }
      button { background: linear-gradient(135deg, #38bdf8, #0ea5e9); color: #0b1120; }
      button:hover { box-shadow: 0 12px 22px rgba(56, 189, 248, 0.35); }
    }
    </style>
    </head>
    <body>
    #{contents}
    </body>
    </html>
    """
  end
end
