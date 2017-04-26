defmodule TaskAfter.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    worker =
      case Application.get_env(:task_after, :global_name, nil) do
        nil -> []
        name when is_atom(name) or is_tuple(name) -> [worker(TaskAfter.Worker, [[name: name]])]
      end

    children =
      worker

    opts = [strategy: :one_for_one, name: TaskAfter.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
