defmodule BalancedTreeTest do
  use ExUnit.Case
  use ExUnitProperties

  def bigger_to_smaller(a, b) do
    cond do
      a < b -> :gt
      a > b -> :lt
      true -> :eq
    end
  end

  doctest BalancedTree

  property "elements are sorted in increasing key order" do
    check all keys <- uniq_list_of(integer()) do
      values = Enum.map(keys, fn k -> {k, 42} end)
      tree = BalancedTree.new(values)
      sorted_values = Enum.sort_by(values, fn {k, _} -> k end)

      assert sorted_values == BalancedTree.to_list(tree)
    end
  end

  property "elements can be sorted in decreasing order" do
    check all keys <- uniq_list_of(integer()) do
      values = Enum.map(keys, fn k -> {k, 42} end)
      tree = BalancedTree.new(values, comparator: &bigger_to_smaller/2)
      sorted_values = Enum.sort_by(values, fn {k, _} -> k end) |> Enum.reverse

      assert sorted_values == BalancedTree.to_list(tree)
    end
  end

  property "elements are overriden" do
    check all values <- list_of(tuple({unquoted_atom(), binary()})) do
      tree = BalancedTree.new(values)
      Enum.each(BalancedTree.to_list(tree), fn {k, v} ->
	vs = Keyword.get_values(values, k)
	assert List.last(vs) == v
      end)
    end
  end

  property "elements are removed by popping" do
    check all end_keys <- uniq_list_of(integer()),
              pop_keys <- uniq_list_of(integer()) do
      keys = end_keys ++ pop_keys
      values = Enum.map(keys, fn k -> {k, 10} end)
      tree = BalancedTree.new(values)
      final_tree = Enum.reduce(pop_keys, tree, fn k, t ->
	{_, new_tree} = BalancedTree.pop(t, k)
	new_tree
      end)
      Enum.each(pop_keys, fn k ->
	assert :error = BalancedTree.fetch(final_tree, k)
      end)
    end
  end

  test "popping a {key, nil} value should not return the default" do
    tree = BalancedTree.new([a: 1, b: 2, c: nil])
    assert {nil, _} = BalancedTree.pop(tree, :c, 42)
  end
end
