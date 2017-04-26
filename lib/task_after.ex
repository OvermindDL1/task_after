defmodule TaskAfter do
  @moduledoc """
  Documentation for TaskAfter.
  """

  @doc """
  task_after

  timeout_after_ms -> integer millisecond timeout
  callback -> the callback function
  opts -> Can be:

    * `name: name` | `pid: pid` -> Specify a non-global task handler, if unspecified that the application `:global_name` must be specified
    * `id: id` -> A unique id, if nil or unspecified then it is auto-generated
    * `call_timeout: timeout` -> Override the timeout on calling to the `TaskAfter.Worker`
    * `no_return: true` -> Do not return the id or error, just try to register and forget results otherwise
    * `send_result: pid` -> Sends the result of the task to the specified pid
    * `send_result: :in_process` -> Runs the task in the `TaskAfter.Worker` process to do internal work, do not use this

  ## Examples

      iex> {:ok, _auto_id} = TaskAfter.task_after(500, fn -> 21 end)
      iex> :ok
      :ok

      iex> {:ok, :myid} = TaskAfter.task_after(500, fn -> 42 end, send_result: self(), id: :myid)
      iex> receive do m -> m after 5 -> :blah end
      :blah
      iex> receive do m -> m after 1000 -> :blah end
      42

  """
  def task_after(timeout_after_ms, callback, opts \\ []) when is_integer(timeout_after_ms) and is_function(callback, 0) do
    name = opts[:name] || opts[:pid] || Application.get_env(:task_after, :global_name, nil) || throw "TaskAfter:  `:name` not defined and no global name defined"

    data = %{
      timeout_after: timeout_after_ms,
      callback: callback,
      id: opts[:id],
      send_result: opts[:send_result],
    }

    if opts[:no_return] do
      GenServer.cast(name, {:register_callback, data})
    else
      GenServer.call(name, {:register_callback, data}, opts[:call_timeout] || 5000)
    end
  end
end
