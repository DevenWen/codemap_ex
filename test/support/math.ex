defmodule Test.Support.Math do
  @moduledoc "This is a module for math operations."
  def add(a, b), do: a + b
  def subtract(a, b), do: a - b

  # 默认参数
  def add2(a, b \\ 1), do: add(a, b)
end

defmodule Test.Support.SingleFunction do
  @moduledoc false
  def double(x), do: x * 2
end

defmodule Test.Support.Caller do
  @moduledoc false

  def foo() do
    Test.Support.Math.add(1, 2)
  end

  def foo2() do
    # 连续调用
    with a <- Test.Support.Math.add(1, 2),
         b <- Test.Support.Math.subtract(a, 1),
         c <- Test.Support.Math.add2(b) do
      a + b + c
    end
  end

  alias Test.Support.Math
  alias Test.Support.{Math, SingleFunction}
  alias Test.Support.Math, as: Math2

  def alias_call() do
    # 别名
    with a <- Math.add(1, 2),
         b <- Math.subtract(a, 1) do
      a + b
    end
  end

  def alias_call2() do
    SingleFunction.double(1)
    Math2.add(1, 2)
  end

  def recursive_call() do
    # 递归调用
    recursive_call()
  end

  def call_default_param() do
    # 默认参数
    if 1 == 1 do
      Math.add2(1)
    else
      Math.add2(1, 2)
    end
  end

  def call_function2(nil) do
    "nil"
  end

  def call_function2(1) do
    "1"
  end
end
