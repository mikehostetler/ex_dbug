# ExDbug

A lightweight, namespace-based debugging utility for Elixir, inspired by Node.js's "debug" library. ExDbug enables contextual logging with zero production overhead and runtime-configurable output.

## Features

- Toggle debug output dynamically via environment variables
- Zero overhead in production builds through compile-time optimization
- Namespace-based log filtering with wildcard support 
- Rich contextual debugging messages
- Seamless value tracking across function chains
- Designed for both human debugging and LLM-assisted development

## Installation

Add `ex_dbug` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_dbug, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Configuration

### Compile-time Settings

Configure ExDbug in your `config.exs` (or environment-specific config):

```elixir
config :ex_dbug,
  enabled: true  # Set to false to compile out debug statements
```

### Runtime Control

Control debug output using the `DEBUG` environment variable:

```bash
# Enable all debug output
DEBUG="*" mix run

# Enable specific namespace
DEBUG="myapp:specific" mix run

# Enable all except specific namespace
DEBUG="*,-myapp:secret" mix run
```

Pattern syntax:
- `*` - Enable all namespaces
- `myapp:*` - Enable all namespaces starting with `myapp:`
- `*,-myapp:db` - Enable all except `myapp:db`
- Multiple patterns can use commas or spaces as separators

## Usage

### Basic Debugging

```elixir
defmodule MyModule do
  use ExDbug, context: :my_namespace

  def my_function do
    dbug("Starting my_function")
    # Your code here
    error("An error occurred")  # Logs error-level message
  end
end
```

### Value Tracking

```elixir
defmodule MyCalculations do
  use ExDbug, context: :my_calculations

  def compute do
    track(1 + 2, "sum_of_1_and_2")  # Logs and returns the computed value
  end
end
```

## LLM-Assisted Development

ExDbug enhances AI-assisted development by providing detailed execution traces that help language models:

- Understand complex call paths
- Debug concurrent operations
- Generate accurate Elixir code
- Analyze runtime behavior

The detailed logs and namespace organization make it easier for AI tools to interpret program flow and state changes.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for your changes
4. Submit a pull request

## License

Released under the MIT License. See [LICENSE](LICENSE) for details.