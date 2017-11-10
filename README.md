# BalancedTree

This module provides an implementation of Prof. Arne Andersson's Balanced Trees.
Balanced trees are used to store and retrieve ordered data efficiently.


The implementation is largely taken from Erlang `:gb_trees`, with minor modifications
to provide an interface similar to Elixir `Map` module.

## Usage

Add `balanced_tree` as a dependency in your `mix.exs` file, then run `mix deps.get`.

```elixir
def deps do
  [{:balanced_tree, "~> 0.1.0"}]
end
```

Start an interactive Elixir shell with `iex -S mix`.

```elixir
iex> tree = BalancedTree.new([d: 4, b: 2, a: 1])
#BalancedTree<[a: 1, b: 2, d: 4]>
iex> BalancedTree.put(tree, :c, 3)
#BalancedTree<[a: 1, b: 2, c: 3, d: 4]>
```

## License

Copyright 2017 Francesco Ceccon

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
