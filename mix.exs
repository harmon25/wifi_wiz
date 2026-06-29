defmodule WifiWiz.MixProject do
  use Mix.Project

  def project do
    [
      app: :wifi_wiz,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      atomvm: [
        start: WifiWiz.Demo,
        flash_offset: 0x250000
      ],
      xref: [exclude: [:network, :esp]]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:exatomvm, github: "AtomVM/ExAtomVM", runtime: false, only: :dev},
      {:atomvm_httpd, github: "harmon25/atomvm_httpd", branch: "main"}
    ]
  end
end
