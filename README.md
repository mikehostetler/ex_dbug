# ExDbug

ExDbug is an debug utility for Elixir applications, providing enhanced debugging and analysis capabilities.

## Features

- Automatic value tracking across function calls
- Performance timing information
- Stack trace integration
- Context preservation

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex_dbug` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_dbug, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ex_dbug>.

## Usage

Include the `ExDbug` module in your module and configure it with the desired options.

```elixir
defmodule MyModule do
  use ExDbug, enabled: true, context: :my_feature

  def my_function do
    debug("Starting my_function")
  end
end
```

To turn off debugging for a specific module, you can set `enabled: false` in the configuration.

```elixir
defmodule MyModule do
  use ExDbug, enabled: false
end
```
