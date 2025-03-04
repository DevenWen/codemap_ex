defmodule CodemapEx.Block do
  @moduledoc """
  base code block
  """

  defstruct [
    # 块类型（module/function/clause/expression）
    type: :generic,
    # 块标识名称
    name: nil,
    # 代码位置 %Position{}
    position: nil,
    # 子代码块列表
    children: [],
    # 方法调用列表 [%Call{}]
    calls: []
  ]
end

defmodule CodemapEx.Block.Mod do
  @moduledoc false
  defstruct(
    CodemapEx.Block.__struct__()
    |> Map.merge(%{type: :module, attrs: []})
    |> Map.from_struct()
    |> Keyword.new()
  )
end

defmodule CodemapEx.Block.Func do
  @moduledoc false
  defstruct(
    CodemapEx.Block.__struct__()
    |> Map.merge(%{type: :function})
    |> Map.from_struct()
    |> Keyword.new()
  )
end
