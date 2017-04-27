# TaskAfter

This is a library to call a function after a set delay.  Usage is as simple as:  `TaskAfter.task_after(500, fn -> do_something_after_500_ms() end)`

## Installation

- [Available in Hex](https://hex.pm/packages/task_after)
- [Documentation](https://hexdocs.pm/task_after)

Install this package by adding `task_after` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:task_after, "~> 1.0.0"},
  ]
end
```

### Global installation

To use this globally without needing to add it to your own supervision tree just add this to your configuration:

```elixir
config :task_after, global_name: TaskAfter
```

Feel free to replace the global name of `TaskAfter` with anything you want. If the global name is unspecified then all usage of TaskAfter must have the `:name` or `:pid` options specified.

### Local Installation

To use this locally to your application or to give distinct names so you can have different schedulars then just add the `TaskAfter.Worker.start_link/1` to your supervision tree as normal, such as via:

```elixir
children = [
  worker(TaskAfter.Worker, [[name: MyCustomName]]),
]
```

Note the 2 sets of list elements. You can have a nameless worker by leaving the name option out, such as:

```elixir
children = [
  worker(TaskAfter.Worker, [[]]),
]
```

You will have to acquire the PID some other way, such as by querying your supervisor.

## Usage

The main interface point is `TaskAfter.task_after/2` and `TaskAfter.task_after/3` where `TaskAfter.task_after/2` just calls `TaskAfter.task_after/3` with an empty set of options to use the defaults.

The arguments to `TaskAfter.task_after/3` are, in this order:

1. timeout_after_ms -> integer millisecond timeout
2. callback -> The 0-arg callback function
3. opts -> Can be:
   - `name: name` | `pid: pid` -> Specify a non-global task handler, if unspecified that the application `:global_name` must be specified
   - `id: id` -> A unique id, if nil or unspecified then it is auto-generated
   - `call_timeout: timeout` -> Override the timeout on calling to the `TaskAfter.Worker`
   - `no_return: true` -> Do not return the id or error, just try to register and forget results otherwise
   - `send_result: pid` -> Sends the result of the task to the specified pid
   - `send_result: :in_process` -> Runs the task in the `TaskAfter.Worker` process to do internal work, do not use this

You can also cancel a task via `TaskAfter.cancel_task_after/1` and `TaskAfter.cancel_task_after/2` where `TaskAfter.cancel_task_after/1` just defaults to having an empty opts list.

The arguments to `TaskAfter.cancel_task_after/2` are, in this order:

1. task_id -> A task id
2. opts -> Can be:
   * `name: name` | `pid: pid` -> Specify a non-global task handler, if unspecified that the application `:global_name` must be specified
   * `call_timeout: timeout` -> Override the timeout on calling to the `TaskAfter.Worker`
   * `no_return: true` -> Do not return the id or error, just try to register and forget results otherwise
   * `run_result: pid` -> Sends the result of the task to the specified pid after running it as an async task while returning the Task
   * `run_result: :in_process` -> Runs the task in the `TaskAfter.Worker` process to do internal work, do not use this, returns the value directly though
   * `run_result: :async` -> Runs the task as an async task and dismisses the result  while returning the Task
   * `run_result: nil` -> **Default**: Does not run the task now, just cancels it immediately, returns the callback function


They can be used as in these examples:

```elixir
defmodule TaskAfterTest do
  use ExUnit.Case, async: true
  doctest TaskAfter

  test "TaskAfter and forget" do
    s = self()
    assert {:ok, _auto_id} = TaskAfter.task_after(500, fn -> send(s, 42) end)
    assert_receive(42, 600)
  end

  test "TaskAfter and receive" do
    assert {:ok, _auto_id} = TaskAfter.task_after(500, fn -> 42 end, send_result: self())
    assert_receive(42, 600)
  end

  test "TaskAfter with custom id" do
    assert {:ok, :my_id} = TaskAfter.task_after(500, fn -> 42 end, id: :my_id, send_result: self())
    assert_receive(42, 600)
  end

  test "TaskAfter with custom id duplicate fails" do
    assert {:ok, :dup_id} = TaskAfter.task_after(500, fn -> 42 end, id: :dup_id, send_result: self())
    assert {:error, {:duplicate_id, :dup_id}} = TaskAfter.task_after(500, fn -> 42 end, id: :dup_id, send_result: self())
    assert_receive(42, 600)
  end

  test "TaskAfter lots of tasks" do
    assert {:ok, _} = TaskAfter.task_after(400, fn -> 400 end, send_result: self())
    assert {:ok, _} = TaskAfter.task_after(200, fn -> 200 end, send_result: self())
    assert {:ok, _} = TaskAfter.task_after(500, fn -> 500 end, send_result: self())
    assert {:ok, _} = TaskAfter.task_after(100, fn -> 100 end, send_result: self())
    assert {:ok, _} = TaskAfter.task_after(300, fn -> 300 end, send_result: self())
    assert {:ok, _} = TaskAfter.task_after(600, fn -> 600 end, send_result: self())
    assert_receive(100, 150)
    assert_receive(200, 150)
    assert_receive(300, 150)
    assert_receive(400, 150)
    assert_receive(500, 150)
    assert_receive(600, 150)
  end

  test "TaskAfter non-global by name" do
    assert {:ok, pid} = TaskAfter.Worker.start_link(name: :testing_name)
    {:ok, _auto_id} = TaskAfter.task_after(500, fn -> 42 end, send_result: self(), name: :testing_name)
    assert_receive(42, 600)
    GenServer.stop(pid)
  end

  test "TaskAfter non-global by pid" do
    assert {:ok, pid} = TaskAfter.Worker.start_link()
    assert {:ok, _auto_id} = TaskAfter.task_after(500, fn -> 42 end, send_result: self(), pid: pid)
    assert_receive(42, 600)
    GenServer.stop(pid)
  end

  test "TaskAfter in process (unsafe, can freeze the task worker if the task does not return fast)" do
    assert {:ok, pid} = TaskAfter.Worker.start_link()
    s = self()
    assert {:ok, _auto_id} = TaskAfter.task_after(500, fn -> send(s, self()) end, send_result: :in_process, pid: pid)
    assert_receive(^pid, 600)
    GenServer.stop(pid)
  end

  test "TaskAfter and cancel timer, do not run the callback" do
    cb = fn -> 42 end
    assert {:ok, auto_id} = TaskAfter.task_after(500, cb)
    assert {:ok, ^cb} = TaskAfter.cancel_task_after(auto_id)
  end

  test "TaskAfter and cancel but also run the callback in process (unsafe again)" do
    assert {:ok, auto_id} = TaskAfter.task_after(500, fn -> 42 end)
    assert {:ok, 42} = TaskAfter.cancel_task_after(auto_id, run_result: :in_process)
  end

  test "TaskAfter and cancel but also run the callback async" do
    s = self()
    assert {:ok, auto_id} = TaskAfter.task_after(500, fn -> send(s, 42) end)
    assert {:ok, :task} = TaskAfter.cancel_task_after(auto_id, run_result: :async)
    assert_receive(42, 600)
  end

  test "TaskAfter and cancel but also run the callback async while returning result to pid" do
    s = self()
    assert {:ok, auto_id} = TaskAfter.task_after(500, fn -> 42 end)
    assert {:ok, :task} = TaskAfter.cancel_task_after(auto_id, run_result: s)
    assert_receive(42, 600)
  end

  test "TaskAfter and crash" do
    s = self()
    len = &length/1
    d = len.([])
    assert {:ok, _auto_id2} = TaskAfter.task_after(100, fn -> send(s, 21) end)
    assert {:ok, _auto_id1} = TaskAfter.task_after(250, fn -> send(s, 1/d) end)
    assert {:ok, _auto_id2} = TaskAfter.task_after(500, fn -> send(s, 42) end)
    assert_receive(42, 600)
    assert_receive(21, 1)
    assert :no_message == (receive do m -> m after 1 -> :no_message end)
  end
end
```
