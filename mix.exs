defmodule CodemapEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :codemap_ex,
      version: "0.0.1",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  defp elixirc_paths(env) when env in [:test, :dev], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {CodemapEx.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:patch, "~> 0.15.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Elixir AST analysis library for building code maps and analyzing code structures. 

    """
  end

  defp package do
    [
      name: :codemap_ex,
      maintainers: ["Deven Wen"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/DevenWen/codemap_ex"}
    ]
  end
end
