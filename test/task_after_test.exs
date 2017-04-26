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
