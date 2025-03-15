defmodule Server do
  def start do
    IO.puts("Starting Mindre.Cash server at http://localhost:4000")
    {:ok, _} = Plug.Cowboy.http(SimpleServer, [], port: 4000)
    Process.sleep(:infinity)
  end
end
