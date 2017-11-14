defmodule BalancedTree.Mixfile do
  use Mix.Project

  @version "0.2.1"
  @github "https://github.com/fracek/balanced_tree"

  def project do
    [app: :balanced_tree,
     version: @version,
     elixir: "~> 1.5",
     deps: deps(),
     name: "BalancedTree",
     source_url: @github,
     docs: [source_ref: "v#{@version}", main: "readme", extras: ["README.md"]],
     description: description(),
     package: package()]
  end

  def application do
    []
  end

  defp deps do
    [{:ex_doc, ">= 0.0.0", only: :dev},
     {:earmark, ">= 0.0.0", only: :dev},
     {:stream_data, "~> 0.1", only: :test}]
  end

  defp description() do
    "AA Tree implementation."
  end

  defp package() do
    [maintainers: ["Francesco Ceccon"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => @github}]
  end
end
