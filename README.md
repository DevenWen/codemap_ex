# CodeMapEx
 
CodeMapEx is an Elixir AST analysis library for building code maps and analyzing code structures. By analyzing Elixir code and its AST (Abstract Syntax Tree), CodeMap helps you understand which Elixir methods are called by each code block, providing visualization and analysis capabilities for code dependencies.

## Features

- Convert Elixir modules to AST
- Analyze AST and build structured code maps
- Identify relationships between modules, functions, and method calls
- Support for complex code structures and nested call analysis

## Installation

Add `codemap_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:codemap_ex, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
$ mix deps.get
```

## Usage

### Basic Usage

```elixir
# Analyze a module
alias CodemapEx

# Get a module's block structure
{:ok, block} = CodemapEx.get_block(MyModule)
# Or use the bang version which raises on error
block = CodemapEx.get_block!(MyModule)

# Now you can inspect the module structure
IO.inspect(block.name)          # Module name
IO.inspect(block.children)      # List of functions
IO.inspect(block.attrs)         # Module attributes

# Check calls in a specific function
function = Enum.find(block.children, &(&1.name == :your_function))
IO.inspect(function.calls)      # List of function calls
```

### Building Call Graphs

```elixir
# Build a call graph starting from a specific function
{:ok, graph} = CodemapEx.build_call_graph(MyModule, :my_function, 2)
# Or use the bang version
graph = CodemapEx.build_call_graph!(MyModule, :my_function, 2)

# The graph contains nodes (functions) and edges (calls)
IO.inspect(graph.start)         # Starting function {module, function, arity}
IO.inspect(graph.nodes)         # List of all functions in the graph
IO.inspect(graph.edges)         # List of all function calls as {caller, callee} tuples
```

### Visualizing Call Graphs

```elixir
# Print the call graph in a readable format
CodemapEx.pretty_print_call_graph(graph)

# Convert to Mermaid diagram format (for embedding in documentation)
mermaid_code = CodemapEx.to_mermaid(graph)
IO.puts(mermaid_code)
```

### Project-wide Analysis

```elixir
# List all analyzed modules
modules = CodemapEx.list_modules()

# Rescan all modules in the project (usually done automatically at startup)
CodemapEx.rescan()
```

## API Reference

### CodeMapEx

#### Module Analysis

- `get_block(module)` - Get a module's block structure
- `get_block!(module)` - Get a module's block structure or raise an error
- `list_modules()` - List all analyzed modules
- `rescan()` - Rescan all modules in the project

#### Call Graph

- `build_call_graph(module, function, arity)` - Build a call graph
- `build_call_graph!(module, function, arity)` - Build a call graph or raise an error
- `pretty_print_call_graph(graph)` - Print a call graph in a readable format
- `to_mermaid(graph)` - Convert a call graph to Mermaid diagram format
