# ExDbug

[![Hex.pm](https://img.shields.io/hexpm/v/ex_dbug.svg)](https://hex.pm/packages/ex_dbug)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/ex_dbug)

Debug utility for Elixir applications, inspired by the Node.js 'debug' package. 
Version 2.0 introduces decorator-based function tracing while maintaining compatibility with 1.x style debugging.

## Features

* 🎯 **Decorator-based function tracing** - Zero-cost, compile-time instrumentation
* 🔄 **1.x Compatibility Mode** - Seamless upgrade path from earlier versions
* 🔍 **Namespace-based filtering** - Filter debug output by context
* 📊 **Rich metadata support** - Attach and format detailed debug information
* ⚡ **Zero runtime cost when disabled** - Compile-time optimization
* 🌍 **Environment variable-based filtering** - Easy runtime control
* 📝 **Automatic metadata truncation** - Smart handling of large values
* 🔧 **Hierarchical configuration** - Global, module, and function-level settings
* 📈 **Value tracking** - Monitor values through pipelines
* ⏱️ **Optional timing and stack traces** - Deep insights when needed

## Installation

Add `ex_dbug` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_dbug, "~> 2.0"}
  ]
end
```

## Usage (2.0 Style)

The new decorator-based approach makes debugging more elegant and maintainable:

```elixir
defmodule MyApp.Worker do
  use ExDbug, enabled: true

  # Simple debug trace
  @decorate dbug()
  def process(data) do
    # Implementation
  end

  # Configured debug trace
  @decorate dbug(context: :important)
  def process_important(data) do
    # Implementation
  end

  # Debug all functions in module
  @decorate_all dbug()
  
  def bulk_1(arg), do: arg
  def bulk_2(arg), do: arg
end
```

## Compatibility Mode (1.x Style)

For existing projects or gradual migration, use compatibility mode:

```elixir
defmodule MyApp.LegacyWorker do
  use ExDbug, compatibility_mode: true

  def process(data) do
    dbug("Processing data", size: byte_size(data))
    # ... processing logic
    dbug("Completed processing", status: :ok)
  end
end
```

## Configuration

### Compile-Time Configuration

In your `config.exs`:

```elixir
config :ex_dbug,
  enabled: true,
  config: [
    max_depth: 3,
    include_timing: true,
    include_stack: true,
    truncate: 100,
    levels: [:debug, :error]
  ]
```

### Module-Level Configuration

```elixir
use ExDbug,
  enabled: true,
  max_depth: 5,
  include_timing: true,
  include_stack: false,
  levels: [:debug, :error]
```

### Function-Level Configuration (2.0)

```elixir
@decorate dbug(
  context: :important,
  include_timing: true,
  include_stack: true
)
def critical_function(arg) do
  # Implementation
end
```

### Runtime Configuration

Control debug output using the `DEBUG` environment variable:

```bash
# Enable all debug output
DEBUG="*" mix run

# Enable specific namespace
DEBUG="myapp:worker" mix run

# Enable multiple patterns
DEBUG="myapp:*,other:thing" mix run

# Enable all except specific namespace
DEBUG="*,-myapp:secret" mix run
```

## Migrating from 1.x to 2.0

### Option 1: Direct Upgrade (Recommended)

Replace debug calls with decorators:
```elixir
# Before (1.x)
def process(arg) do
  dbug("Processing", value: arg)
  # Implementation
end

# After (2.0)
@decorate dbug()
def process(arg) do
  # Implementation
end
```

### Option 2: Compatibility Mode

For gradual migration, enable compatibility mode:

```elixir
use ExDbug, compatibility_mode: true
# All 1.x code continues to work
```

### Configuration Updates

Update your configuration to use the new hierarchical structure:

```elixir
# Before (1.x)
config :ex_dbug, enabled: true

# After (2.0)
config :ex_dbug,
  enabled: true,
  config: [
    max_depth: 3,
    include_timing: true
  ]
```

## Best Practices

1. Use descriptive context names matching your application structure
2. Prefer decorator-based debugging for new code
3. Use compatibility mode for gradual migration
4. Set appropriate DEBUG patterns for different environments
5. Configure hierarchically (global → module → function)
6. Disable in production for zero overhead

## Production Use

While ExDbug has minimal overhead when disabled, it's recommended to set 
`config :ex_dbug, enabled: false` in production unless debugging is specifically 
needed. This ensures zero runtime cost as debug calls are compiled out completely.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

MIT License - see LICENSE.md for details.