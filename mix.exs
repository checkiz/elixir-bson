defmodule Bson.Mixfile do
  use Mix.Project

  def project do
    [ app: :bson,
      name: "bson",
      version: "0.0.1",
      elixir: "~> 0.12.2",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    []
  end
  
  # Returns the list of dependencies in the format:
  defp deps do
    []
  end
end