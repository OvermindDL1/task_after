defmodule TaskAfter.Worker do
  @moduledoc """
  """

  use GenServer
  require Logger
  import Record


  defrecordp :t, [
    timeout_time: -1, # This must remain first
    id: nil,
    cb: nil,
    send_result: nil,
  ]

  defrecordp :s, [
    next_id: 0,
    cbs_by_id: %{},
    ids_by_time: :ordsets.new()
  ]


  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: opts[:name])
  end


  def init(_opts) do
    {:ok, s()}
  end


  def handle_cast({:register_callback, data}, state) do
    {state, result} = register_callback(data, state)
    {state, timeout} = get_next_timeout(state)
    Logger.debug("TaskAfter: register_cast: #{inspect {timeout, result, state}}")
    {:noreply, state, timeout}
  end

  def handle_call({:register_callback, data}, _from, state) do
    {state, result} = register_callback(data, state)
    {state, timeout} = get_next_timeout(state)
    Logger.debug("TaskAfter: register_call: #{inspect {timeout, result, state}}")
    {:reply, result, state, timeout}
  end

  def handle_info(:timeout, state) do
    state = process(state)
    {state, timeout} = get_next_timeout(state)
    Logger.debug("TaskAfter: timeout: #{inspect {timeout, state}}")
    {:noreply, state, timeout}
  end

  def handle_info({ref, res}, state) when is_reference(ref) do
    {state, timeout} = get_next_timeout(state)
    Logger.debug("TaskAfter: info task msg: #{inspect {timeout, res, state}}")
    {:noreply, state, timeout}
  end

  def handle_info({:DOWN, ref, :process, pid, :normal}, state) when is_reference(ref) and is_pid(pid) do
    {state, timeout} = get_next_timeout(state)
    Logger.debug("TaskAfter: info task down: #{inspect {timeout, state}}")
    {:noreply, state, timeout}
  end

  def handle_info(msg, state) do
    Logger.warn("TaskAfter:  Unknown message received:  #{inspect msg}")
    {state, timeout} = get_next_timeout(state)
    {:noreply, state, timeout}
  end





  defp register_callback(data, state) do
    case data[:id] do
      nil -> install_callback(data, state)
      [] -> install_callback(data, state)
      id ->
        case s(state, :cbs_by_id)[id] do
          nil -> install_callback(data, state)
          _cbs -> {state, {:error, {:duplicate_id, id}}}
        end
    end
  end

  defp install_callback(data, state) do
    {state, id} =
      case data[:id] do
        nil -> generate_new_id(state)
        [] -> generate_new_id(state)
        id -> {state, id}
      end

    install_callback(data, id, state)
  end

  defp install_callback(data, id, s(cbs_by_id: cbs, ids_by_time: times) = state) do
    timeout_time =
      case data[:timeout_time] do
        nil -> ((data.timeout_after) + (get_current_ms()))
        time -> time
      end

    task = t(timeout_time: timeout_time, id: id, cb: data.callback, send_result: data[:send_result])
    cbs = Map.put(cbs, id, task)
    times = :ordsets.add_element(task, times)

    state = s(state, cbs_by_id: cbs, ids_by_time: times)
    result = {:ok, id}
    {state, result}
  end


  defp get_next_timeout(s(ids_by_time: [t(timeout_time: next) | _]) = state) do
    case next - get_current_ms() do
      timeout when timeout < 0 -> {state, 0}
      timeout -> {state, timeout}
    end
  end
  defp get_next_timeout(state), do: {state, :infinity}


  defp get_current_ms() do
    :erlang.monotonic_time(:millisecond)
  end


  defp generate_new_id(s(next_id: next_id) = state) do
    state = s(state, next_id: next_id+1)
    id = {__MODULE__, next_id}
    {state, id}
  end


  defp process(s(ids_by_time: [t(timeout_time: timeout_time, id: id, cb: cb, send_result: send_result) | rest], cbs_by_id: cbs) = state) do
    cur = get_current_ms()
    if timeout_time > cur do
      state # No more to process since they are later
    else
      case send_result do
        nil -> Task.async(cb) # Spawn and forget
        :in_process ->
          try do
            cb.() # Uhh, hope they know what they are doing...
          catch
            error, reason -> Logger.error("TaskAfter: Task `#{inspect id}` crashed due to: #{inspect error} -> #{inspect reason}")
          rescue
            exc -> Logger.error("TaskAfter: Task `#{inspect id}` crashed due to exception: #{Exception.message(exc)}")
          end
        pid when is_pid(pid) -> Task.async(fn -> send(pid, cb.()) end)
      end
      state = s(state, ids_by_time: rest, cbs_by_id: Map.delete(cbs, id))
      process(state)
    end
  end
  defp process(state) do
    state # No more to process since it is empty
  end


end
