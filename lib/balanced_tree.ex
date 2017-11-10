defmodule BalancedTree do
  @moduledoc """
  This module provides an implementation of Prof. Arne Andersson's Balanced Trees.
  BalancedTree is used to store and retrieve ordered data efficiently.

  By default, two keys are considered equal if one is not less than `<` or
  greater than `>` the other. A different comparison function can be specified.

  The implementation is largely taken from Erlang `:gb_trees`, with minor modifications
  to provide an interface similar to Elixir `Map` module.
  """

  use Bitwise, only: [:<<<, :>>>]
  defstruct [:root, :comparator]

  @behaviour Access

  @typedoc "A balanced tree."
  @type t :: %__MODULE__{}

  @typedoc "A key in the tree."
  @type key :: any

  @typedoc "A value in the tree."
  @type value :: any

  @doc """
  Returns a new empty tree.

  ## Examples

      iex> BalancedTree.new
      #BalancedTree<[]>
  """
  @spec new :: t
  def new, do: new([])

  @doc """
  Creates a new tree from `values`.

  ## Options

  - `:comparator`
    function that takes two keys `(a, b)` and returns:
    + `:lt` if a < b
    + `:gt` if a > b
    + `:eq` if a == b

  ## Examples

      iex> BalancedTree.new([{1, :a}, {2, :b}, {3, :c}])
      #BalancedTree<[1 => :a, 2 => :b, 3 => :c]>

      iex> BalancedTree.new([{1, :a}, {2, :b}, {3, :c}], comparator: &bigger_to_smaller/2)
      #BalancedTree<[3 => :c, 2 => :b, 1 => :a]>
  """
  @spec new(Enumerable.t, [{:comparator, (key, key -> :lt | :gt | :eq)}]) :: t
  def new(values, opts \\ []) do
    tree = %__MODULE__{
      root: {0, nil},
      comparator: Keyword.get(opts, :comparator, &default_cmp/2),
    }
    do_new(tree, values)
  end

  @doc """
  Puts the given `value` under `key` in `tree`.

  ## Examples

      iex> BalancedTree.put(BalancedTree.new([a: 1]), :b, 2)
      #BalancedTree<[a: 1, b: 2]>
      iex> BalancedTree.put(BalancedTree.new([a: 1, b: 2]), :b, 3)
      #BalancedTree<[a: 1, b: 3]>
  """
  @spec put(t, key, value) :: t
  def put(%{root: root, comparator: cmp} = tree, key, value) do
    %{tree | root: do_put(root, cmp, key, value)}
  end

  @doc """
  Deletes the entry for the given `key` from `tree`.

  ## Examples

      iex> BalancedTree.delete(BalancedTree.new([a: 1]), :a)
      #BalancedTree<[]>
      iex> BalancedTree.delete(BalancedTree.new([a: 1]), :b)
      #BalancedTree<[a: 1]>
  """
  @spec delete(t, key) :: t
  def delete(%{root: root, comparator: cmp} = tree, key) do
    %{tree | root: do_delete(root, cmp, key)}
  end

  @doc """
  Fetches the value for a specific `key` in the given `tree`.

  ## Examples

      iex> BalancedTree.fetch(BalancedTree.new([a: 1]), :a)
      {:ok, 1}
      iex> BalancedTree.fetch(BalancedTree.new([a: 1]), :b)
      :error
  """
  @spec fetch(t, key) :: {:ok, value} | :error
  def fetch(%{root: root, comparator: cmp} = _tree, key) do
    do_fetch(root, cmp, key)
  end

  @doc """
  Fetches the value for a specific `key` in the given `tree`, raising an error
  if `tree` doesn't contain `key`.

  ## Examples

      iex> BalancedTree.fetch!(BalancedTree.new([a: 1]), :a)
      1
      iex> BalancedTree.fetch!(BalancedTree.new([a: 1]), :b)
      ** (KeyError) key nil not found

  """
  @spec fetch!(t, key) :: value | no_return
  def fetch!(tree, key) do
    case fetch(tree, key) do
      {:ok, value} -> value
      :error -> raise KeyError
    end
  end

  @doc """
  Gets the value for a specific `key` in `tree`.

  If `key` is present in `tree` with `value`, then `value` is returned.
  Otherwise, a `default` is returned.

  ## Examples

      iex> BalancedTree.get(BalancedTree.new([a: 1]), :b)
      nil
      iex> BalancedTree.get(BalancedTree.new([a: 1]), :a)
      1
      iex> BalancedTree.get(BalancedTree.new([a: 1]), :b, 3)
      3

  """
  @spec get(t, key, value) :: value
  def get(tree, key, default \\ nil) do
    case fetch(tree, key) do
      {:ok, value} -> value
      :error -> default
    end
  end

  @doc """
  Gets the value for `key` in `tree` and updates it, all in one pass.

  ## Examples

      iex> {1, tree} = BalancedTree.get_and_update(BalancedTree.new([a: 1]), :a, fn value ->
      ...>    {value, 2 * value}
      ...> end)
      iex> tree
      #BalancedTree<[a: 2]>
      iex> {1, tree} = BalancedTree.get_and_update(BalancedTree.new([a: 1]), :a, fn _ ->
      ...>   :pop
      ...> end)
      iex> tree
      #BalancedTree<[]>
      iex> {nil, tree} = BalancedTree.get_and_update(BalancedTree.new([a: 1]), :b, fn nil ->
      ...>   {nil, 2}
      ...> end)
      iex> tree
      #BalancedTree<[a: 1, b: 2]>

  """
  @spec get_and_update(t, key, (value -> {get, value} | :pop)) :: {get, t} when get: term
  def get_and_update(tree, key, fun) when is_function(fun, 1) do
    # TODO: make this really do one pass only
    current = get(tree, key)

    case fun.(current) do
      {get, update} ->
	{get, put(tree, key, update)}
      :pop ->
	{current, delete(tree, key)}
      other ->
	raise "the given function must return a two-element tuple or :pop, got: #{inspect other}"
    end
  end

  @doc """
  Gets the value fom `key` in `tree` and updates it. Raises if there is no `key`.

  ## Examples

      iex> {1, tree} = BalancedTree.get_and_update!(BalancedTree.new([a: 1]), :a, fn value ->
      ...>   {value, 2 * value}
      ...> end)
      iex> tree
      #BalancedTree<[a: 2]>
      iex> {1, tree} = BalancedTree.get_and_update!(BalancedTree.new([a: 1]), :a, fn _ ->
      ...>   :pop
      ...> end)
      iex> tree
      #BalancedTree<[]>
      iex> BalancedTree.get_and_update!(BalancedTree.new([a: 1]), :b, fn _ ->
      ...>   :pop
      ...> end)
      ** (KeyError) key nil not found

  """
  @spec get_and_update!(t, key, (value -> {get, value} | :pop)) :: {get, t} | no_return when get: term
  def get_and_update!(tree, key, fun) when is_function(fun, 1) do
    # TODO: make this really do one pass only
    current = fetch!(tree, key)

    case fun.(current) do
      {get, update} ->
	{get, put(tree, key, update)}
      :pop ->
	{current, delete(tree, key)}
      other ->
	raise "the given function must return a two-element tuple or :pop, got: #{inspect other}"
    end
  end

  @doc """
  Returns and removes the value for `key` in `tree`.

  ## Examples

      iex> {1, tree} = BalancedTree.pop(BalancedTree.new([a: 1]), :a)
      iex> tree
      #BalancedTree<[]>
      iex> {nil, tree} = BalancedTree.pop(BalancedTree.new([a: 1]), :b)
      iex> tree
      #BalancedTree<[a: 1]>
      iex> {3, tree} = BalancedTree.pop(BalancedTree.new([a: 1]), :b, 3)
      iex> tree
      #BalancedTree<[a: 1]>

  """
  @spec pop(t, key, value) :: {value, t}
  def pop(tree, key, default \\ nil) do
    case get_and_update(tree, key, fn _ -> :pop end) do
      {nil, new_tree} ->
	{default, new_tree}
      {value, new_tree} ->
	{value, new_tree}
    end
  end

  @doc """
  Maps function `fun` to all key-value pairs in `tree`.

  ## Examples

      iex> BalancedTree.map(BalancedTree.new([c: 3, b: 2, a: 1]), fn k, _ -> k end)
      #BalancedTree<[a: :a, b: :b, c: :c]>

  """
  @spec map(t, (key, value -> value)) :: t
  def map(%{root: root} = tree, fun) do
    %{tree | root: do_map(root, fun)}
  end

  @doc """
  Returns wheter the given `key` exists in `tree`.

  ## Examples

      iex> BalancedTree.has_key?(BalancedTree.new([a: 1]), :a)
      true
      iex> BalancedTree.has_key?(BalancedTree.new([a: 1]), :b)
      false

  """
  @spec has_key?(t, key) :: boolean
  def has_key?(tree, key) do
    case fetch(tree, key) do
      :error -> false
      {:ok, _} -> true
    end
  end

  @doc """
  Returs the key-value pair associated with the smallest `key` in `tree`.

  ## Examples

      iex> BalancedTree.min(BalancedTree.new([b: 2, a: 1]))
      {:a, 1}
      iex> BalancedTree.min(BalancedTree.new([b: 2, a: 1], comparator: &bigger_to_smaller/2))
      {:b, 2}

  """
  @spec min(t) :: {key, value}
  def min(%{root: root} = _tree) do
    do_min(root)
  end

  @doc """
  Returs the key-value pair associated with the largest `key` in `tree`.

  ## Examples

      iex> BalancedTree.max(BalancedTree.new([b: 2, a: 1]))
      {:b, 2}
      iex> BalancedTree.max(BalancedTree.new([b: 2, a: 1], comparator: &bigger_to_smaller/2))
      {:a, 1}

  """
  @spec max(t) :: {key, value}
  def max(%{root: root} = _tree) do
    do_max(root)
  end

  @doc """
  Returns the number of elements in `tree`.

  ## Examples

      iex> BalancedTree.size(BalancedTree.new([a: 1]))
      1

  """
  @spec size(t) :: integer
  def size(%{root: {size, _}} = _tree), do: size

  @doc """
  Returns `true` if `tree` is empty.

  ## Examples

      iex> BalancedTree.empty?(BalancedTree.new())
      true
      iex> BalancedTree.empty?(BalancedTree.new([a: 1]))
      false

  """
  @spec empty?(t) :: boolean
  def empty?(tree), do: size(tree) == 0

  @doc """
  Converts `tree` to a list.

  ## Examples

      iex> BalancedTree.to_list(BalancedTree.new([c: 1, b: 2, a: 3]))
      [a: 3, b: 2, c: 1]
  """
  @spec to_list(t) :: [{key, value}]
  def to_list(%{root: root} = _tree) do
    do_to_list(root)
  end


  defp default_cmp(a, b) do
    cond do
      a < b -> :lt
      a > b -> :gt
      true -> :eq
    end
  end

  defp do_new(tree, []) do
    tree
  end
  defp do_new(tree, [{key, value}|values]) do
    do_new(BalancedTree.put(tree, key, value), values)
  end

  defp do_put({size, root}, cmp, key, new_value)
  when is_integer(size) and size >= 0 do
    new_size = size + 1
    {new_size, do_put(root, cmp, key, new_value, pow(size+1))}
  end
  defp do_put({node_key, node_value, smaller, bigger}, cmp, key, new_value, size) do
    case cmp.(key, node_key) do
      :lt ->
	case do_put(smaller, cmp, key, new_value, div2(size)) do
	  {tree, tree_height, tree_size} ->
	    new_tree = {node_key, node_value, tree, bigger}
	    {new_tree_height, new_tree_size} = count(bigger)
	    new_height = mul2(max(tree_height, new_tree_height))
	    new_size = tree_size + new_tree_size + 1
	    p = pow(new_size)
	    if new_height > p do
	      balance(new_tree, new_size)
	    else
	      {new_tree, new_height, new_size}
	    end
	  tree ->
	    {node_key, node_value, tree, bigger}
	end
      :gt ->
	case do_put(bigger, cmp, key, new_value, div2(size)) do
	  {tree, tree_height, tree_size} ->
	    new_tree = {node_key, node_value, smaller, tree}
	    {new_tree_height, new_tree_size} = count(smaller)
	    new_height = mul2(max(tree_height, new_tree_height))
	    new_size = tree_size + new_tree_size + 1
	    p = pow(new_size)
	    if new_height > p do
	      balance(new_tree, new_size)
	    else
	      {new_tree, new_height, new_size}
	    end
	  tree ->
	    {node_key, node_value, smaller, tree}
	end
      :eq ->
	{node_key, new_value, smaller, bigger}
    end
  end
  defp do_put(nil, _cmp, key, new_value, size) when size == 0 do
    {{key, new_value, nil, nil}, 1, 1}
  end
  defp do_put(nil, _cmp, key, new_value, _size) do
    {key, new_value, nil, nil}
  end

  defp do_delete({size, root}, cmp, key) do
    {size, do_delete(root, cmp, key)}
  end
  defp do_delete(nil, _cmp, _key), do: nil
  defp do_delete({node_key, value, smaller, bigger}, cmp, key) do
    case cmp.(key, node_key) do
      :lt ->
	new_smaller = do_delete(smaller, cmp, key)
	{node_key, value, new_smaller, bigger}
      :gt ->
	new_bigger = do_delete(bigger, cmp, key)
	{node_key, value, smaller, new_bigger}
      :eq ->
	merge(smaller, bigger)
    end
  end

  defp do_fetch({_, root}, cmp, key), do: do_fetch(root, cmp, key)
  defp do_fetch(nil, _cmp, _key), do: :error
  defp do_fetch({node_key, value, smaller, bigger}, cmp, key) do
    case cmp.(key, node_key) do
      :lt -> do_fetch(smaller, cmp, key)
      :gt -> do_fetch(bigger, cmp, key)
      :eq -> {:ok, value}
    end
  end

  defp do_map({size, root}, fun), do: {size, do_map(root, fun)}
  defp do_map(nil, _fun), do: nil
  defp do_map({key, value, smaller, bigger}, fun) do
    {key, fun.(key, value), do_map(smaller, fun), do_map(bigger, fun)}
  end

  defp do_min({_, root}), do: do_min(root)
  defp do_min({key, value, nil, _bigger}), do: {key, value}
  defp do_min({_key, _value, smaller, _bigger}), do: do_min(smaller)

  defp do_max({_, root}), do: do_max(root)
  defp do_max({key, value, _smaller, nil}), do: {key, value}
  defp do_max({_key, _value, _smaller, bigger}), do: do_max(bigger)

  defp pow(size), do: 2 * size
  defp div2(size), do: size >>> 1
  defp mul2(size), do: size <<< 1

  defp count({_, _, nil, nil}), do: {1, 1}
  defp count({_, _, smaller, bigger}) do
    {h1, s1} = count(smaller)
    {h2, s2} = count(bigger)
    {mul2(max(h1, h2)), s1 + s2 + 1}
  end
  defp count(nil), do: {1, 0}

  defp merge(smaller, nil), do: smaller
  defp merge(nil, bigger), do: bigger
  defp merge(smaller, bigger) do
    {key, value, new_bigger} = take_smallest(bigger)
    {key, value, smaller, new_bigger}
  end

  defp take_smallest({key, value, nil, bigger}) do
    {key, value, bigger}
  end
  defp take_smallest({key, value, smaller, bigger}) do
    {new_key, new_value, new_smaller} = take_smallest(smaller)
    {new_key, new_value, {key, value, new_smaller, bigger}}
  end

  defp balance(tree, size) do
    {t, []} = balance_list(do_to_list(tree), size)
    t
  end

  defp balance_list(list, size) when size > 1 do
    sm = size - 1
    s2 = div(sm, 2)
    s1 = sm - s2
    {t1, [{k, v} | l1]} = balance_list(list, s1)
    {t2, l2} = balance_list(l1, s2)
    t = {k, v, t1, t2}
    {t, l2}
  end
  defp balance_list([{k, v} | l], 1) do
    {{k, v, nil, nil}, l}
  end
  defp balance_list(l, 0) do
    {nil, l}
  end

  defp do_to_list({_, t}), do: do_to_list(t, [])
  defp do_to_list(t), do: do_to_list(t, [])
  defp do_to_list({k, v, smaller, bigger}, acc) do
    do_to_list(smaller, [{k, v} | do_to_list(bigger, acc)])
  end
  defp do_to_list(nil, acc), do: acc
end

defimpl Inspect, for: BalancedTree do
  import Inspect.Algebra

  def inspect(tree, opts) do
    tree = BalancedTree.to_list(tree)
    open = color("#BalancedTree<[", :map, opts)
    sep = color(",", :map, opts)
    close = color("]>", :map, opts)
    surround_many(open, tree, close, opts, traverse_fun(tree, opts), sep)
  end

  defp traverse_fun(tree, opts) do
    if Inspect.List.keyword?(tree) do
      &Inspect.List.keyword/2
    else
      sep = color(" => ", :map, opts)
      &to_map(&1, &2, sep)
    end
  end

  defp to_map({key, value}, opts, sep) do
    concat [to_doc(key, opts), sep, to_doc(value, opts)]
  end
end
