# TaskAfter

**TODO: Add description**

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

It can be used as in these examples:

```elixir
defmodule TaskAfterTest do
  use ExUnit.Case, async: true
  doctest TaskAfter

  test "TaskAfter and forget" do
    s = self()
    {:ok, _auto_id} = TaskAfter.task_after(500, fn -> send(s, 42) end)
    assert_receive(42, 600)
  end

  test "TaskAfter and receive" do
    {:ok, _auto_id} = TaskAfter.task_after(500, fn -> 42 end, send_result: self())
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
end
```
