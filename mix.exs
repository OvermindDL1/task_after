defmodule TaskAfter.Mixfile do
  use Mix.Project

  def project do
    [
      app: :task_after,
      version: "1.0.0",
      elixir: "~> 1.4",
      description: description(),
      package: package(),
      docs: docs(),
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
    ]
  end

  def description do
    """
    """
  end

  def package do
    [
      licenses: ["MIT"],
      name: :task_after,
      maintainers: ["OvermindDL1"],
      links: %{
        "Github" => "https://github.com/OvermindDL1/task_after",
      },
    ]
  end

  def docs do
    [
      #logo: "path/to/logo.png",
      extras: ["README.md"],
      main: "readme",
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {TaskAfter.Application, []},
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.15.1", only: [:dev]},
    ]
  end
end
