defmodule BalancedTree.Mixfile do
  use Mix.Project

  def project do
    [app: :balanced_tree,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:ex_doc, "~> 0.16", only: :dev, runtime: false}]
  end
end
