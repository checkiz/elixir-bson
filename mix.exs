defmodule Bson.Mixfile do
  use Mix.Project

  def project do
    [ app: :bson,
      name: "bson",
      version: "0.3.0",
      elixir: "~> 0.14.2",
      source_url: "https://github.com/checkiz/elixir-bson",
      deps: deps(Mix.env),
      docs: &docs/0 ]
  end

  # Configuration for the OTP application
  def application do
    []
  end
  
  # Returns the list of dependencies in the format:
  defp deps(:docs) do
    [{ :ex_doc, github: "elixir-lang/ex_doc" }]
  end
  defp deps(_), do: []

  defp docs do
    [ readme: true,
      main: "README",
      source_ref: System.cmd("git rev-parse --verify --quiet HEAD") ]
  end
end
