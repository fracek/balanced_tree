defmodule BalancedTreeTest do
  use ExUnit.Case

  def bigger_to_smaller(a, b) do
    cond do
      a < b -> :gt
      a > b -> :lt
      true -> :eq
    end
  end

  doctest BalancedTree
  test "popping a {key, nil} value should not return the default" do
    tree = BalancedTree.new([a: 1, b: 2, c: nil])
    assert {nil, _} = BalancedTree.pop(tree, :c, 42)
  end
end
