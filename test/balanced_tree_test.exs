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
end
