defmodule Test.Support.Math do
  @moduledoc "This is a module for math operations."
  def add(a, b), do: a + b
  def subtract(a, b), do: a - b
end

defmodule Test.Support.SingleFunction do
  @moduledoc false
  def double(x), do: x * 2
end
