defmodule Mix.Tasks.Server.Start do
  @moduledoc """
  Starts the Mindre Cash web server.

  ## Examples

      $ mix server.start

  """
  use Mix.Task

  @shortdoc "Starts the Mindre Cash web server"
  def run(_) do
    # Make sure our application and all dependencies are started
    Mix.Task.run("app.start")

    # Print a nice message
    Mix.shell().info("Starting Mindre Cash web server on http://localhost:4000")

    # The server is already started by the application, just keep the process running
    Process.sleep(:infinity)
  end
end
