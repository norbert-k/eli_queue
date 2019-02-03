defmodule EliQueue do
  defstruct [:internal_queue, :max_size, :length]

  def new(max_size) when is_integer(max_size) and max_size > 0 do
    %__MODULE__{
      internal_queue: :queue.new(),
      max_size: max_size,
      length: 0
    }
  end

  def from_list(list, max_size) when is_list(list) and is_integer(max_size) and max_size > 0 do
    %__MODULE__{
      max_size: max_size,
      length: Enum.count(list),
      internal_queue: :queue.from_list(list)
    }
  end

  def append(%__MODULE__{max_size: max_size, length: length} = queue, item) do
    case length + 1 > max_size do
      true -> append(:overflow, queue, item)
      false -> append(:normal, queue, item)
    end
  end

  defp append(:overflow, %__MODULE__{internal_queue: internal_queue} = queue, item) do
    internal_queue = :queue.drop(internal_queue)
    internal_queue = :queue.in(item, internal_queue)
    %{queue | :internal_queue => internal_queue}
  end

  defp append(:normal, %__MODULE__{length: length, internal_queue: internal_queue} = queue, item) do
    internal_queue = :queue.in(item, internal_queue)
    %{queue | :length => length + 1, :internal_queue => internal_queue}
  end

  def pop(%__MODULE__{length: length, internal_queue: internal_queue} = queue) do
    case :queue.out(internal_queue) do
      {:empty, internal_queue} ->
        {nil, %{queue | :internal_queue => internal_queue}}

      {{:value, value}, internal_queue} ->
        {value, %{queue | :internal_queue => internal_queue, :length => length - 1}}
    end
  end

  defimpl Enumerable do
    def reduce(_, {:halt, acc}, _fun) do
      {:halted, acc}
    end

    def reduce(queue, {:suspended, acc}, fun) do
      {:suspended, acc, &reduce(queue, &1, fun)}
    end

    def reduce(%EliQueue{internal_queue: internal_queue}, {:cont, acc}, fun) do
      reduce(:queue.to_list(internal_queue), {:cont, acc}, fun)
    end

    def reduce([], {:cont, acc}, _fun), do: {:done, acc}

    def reduce([head | tail], {:cont, acc}, fun), do: reduce(tail, fun.(head, acc), fun)

    def member?(%EliQueue{internal_queue: internal_queue}, element) do
      {:ok, :queue.member(element, internal_queue)}
    end

    def count(%EliQueue{length: length}) do
      {:ok, length}
    end

    def slice(%EliQueue{}) do
      {:error, __MODULE__}
    end
  end

  defimpl Collectable do
    def into(original) do
      {original,
       fn
         queue, {:cont, value} -> EliQueue.append(queue, value)
         queue, :done -> queue
         _, :halt -> :ok
       end}
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(queue, opts) do
      concat(["#Queue<", Inspect.List.inspect(:queue.to_list(queue.internal_queue), opts), ">"])
    end
  end
end
