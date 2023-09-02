defmodule TaskAfter.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications

  @moduledoc false

  use Application

  def start(_type, _args) do
    children =
      case Application.get_env(:task_after, :global_name, nil) do
        nil ->
          []

        name when is_atom(name) or is_tuple(name) ->
          [
            {TaskAfter.Worker, [name: name]}
          ]
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: TaskAfter.Supervisor)
  end
end
