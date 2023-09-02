defmodule TaskAfter.Mixfile do
  use Mix.Project

  def project do
    [
      app: :task_after,
      version: "1.3.0",
      elixir: "~> 1.11",
      description: description(),
      package: package(),
      docs: docs(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def description do
    """
    This is a library to call a function after a set delay.  Usage is as simple as:  `TaskAfter.task_after(500, fn -> do_something_after_500_ms() end)`
    """
  end

  def package do
    [
      licenses: ["MIT"],
      name: :task_after,
      maintainers: ["OvermindDL1"],
      links: %{
        "Github" => "https://github.com/OvermindDL1/task_after"
      }
    ]
  end

  def docs do
    [
      extras: ["README.md"],
      main: "readme"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {TaskAfter.Application, []}
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.30.6", only: [:dev]}
    ]
  end
end
