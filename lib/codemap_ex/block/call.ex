defmodule CodemapEx.Block.Call do
  @moduledoc """
  method call
  """

  defstruct [
    # 调用类型（function/macro/special_form）
    type: :function,
    # 模块原子（如: String）
    module: nil,
    # 方法原子（如: upcase）
    name: nil,
    # 参数数量
    arity: nil,
    # 调用位置 %Position{}
    position: nil
  ]
end
