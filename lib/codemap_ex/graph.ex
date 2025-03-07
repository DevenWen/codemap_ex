defmodule CodemapEx.Graph do
  @moduledoc """
  表示函数调用图的数据结构。

  调用图是一个有向图，表示函数之间的调用关系。每个节点代表一个函数（由模块、函数名和参数数量组成），
  边表示从一个函数到另一个函数的调用关系。
  """

  @type function_ref :: {module(), atom(), non_neg_integer()}
  @type t :: %__MODULE__{
          start: function_ref(),
          nodes: [function_ref()],
          edges: [{function_ref(), function_ref()}]
        }

  defstruct [
    # 起始函数，格式为 {模块, 函数名, 参数数量}
    start: nil,
    # 图中的所有节点（函数）列表
    nodes: [],
    # 边列表，每条边是一个 {from_mfa, to_mfa} 元组
    edges: []
  ]

  @doc """
  创建一个新的调用图。

  ## 参数

    * `start` - 起始函数，格式为 {模块, 函数名, 参数数量}

  ## 返回值

    * 新的调用图结构
  """
  def new(start) when is_tuple(start) and tuple_size(start) == 3 do
    %__MODULE__{
      start: start,
      nodes: [start],
      edges: []
    }
  end

  @doc """
  向图中添加一个节点。

  ## 参数

    * `graph` - 现有的调用图
    * `node` - 要添加的节点，格式为 {模块, 函数名, 参数数量}

  ## 返回值

    * 更新后的调用图
  """
  def add_node(graph, node) do
    if Enum.member?(graph.nodes, node) do
      graph
    else
      %{graph | nodes: [node | graph.nodes]}
    end
  end

  @doc """
  向图中添加一条边。

  ## 参数

    * `graph` - 现有的调用图
    * `from` - 边的起始节点
    * `to` - 边的目标节点

  ## 返回值

    * 更新后的调用图
  """
  def add_edge(graph, from, to) do
    edge = {from, to}

    if Enum.member?(graph.edges, edge) do
      graph
    else
      graph = add_node(graph, from)
      graph = add_node(graph, to)
      %{graph | edges: [edge | graph.edges]}
    end
  end

  @doc """
  格式化打印调用图。

  ## 参数

    * `graph` - 要打印的调用图

  ## 返回值

    * 原始调用图（方便链式调用）
  """
  def pretty_print(graph) do
    # 打印起始点
    IO.puts("函数调用图 - 起始点: #{inspect_mfa(graph.start)}")

    # 打印基本统计信息
    IO.puts("节点数量: #{length(graph.nodes)}")
    IO.puts("边数量: #{length(graph.edges)}")
    IO.puts("")

    # 打印节点列表
    IO.puts("节点列表:")

    Enum.each(graph.nodes, fn node ->
      IO.puts("- #{inspect_mfa(node)}")
    end)

    IO.puts("")

    # 打印调用关系
    IO.puts("调用关系:")

    Enum.each(graph.edges, fn {from, to} ->
      IO.puts("- #{inspect_mfa(from)} -> #{inspect_mfa(to)}")
    end)

    IO.puts("")

    # 返回原始图结构
    graph
  end

  # 格式化 MFA 三元组为可读字符串
  defp inspect_mfa({mod, fun, arity}) do
    "#{inspect(mod)}.#{fun}/#{arity}"
  end

  @doc """
  将调用图转换为 Mermaid 图表格式的字符串。

  ## 参数

    * `graph` - 要转换的调用图

  ## 返回值

    * 包含 Mermaid 图表定义的字符串
  """
  def to_mermaid(graph) do
    # 初始化 Mermaid 图表头部
    header = "graph TD\n"

    # 为每个节点生成唯一标识符
    node_ids = Map.new(graph.nodes, fn node -> {node, "node_#{:erlang.phash2(node)}"} end)

    # 生成节点定义
    nodes =
      Enum.map(graph.nodes, fn node ->
        id = Map.get(node_ids, node)
        "  #{id}[\"#{escape_mermaid_label(inspect_mfa(node))}\"]"
      end)

    # 生成边定义
    edges =
      Enum.map(graph.edges, fn {from, to} ->
        from_id = Map.get(node_ids, from)
        to_id = Map.get(node_ids, to)
        "  #{from_id} --> #{to_id}"
      end)

    # 组合所有部分
    [header, Enum.join(nodes, "\n"), Enum.join(edges, "\n")]
    |> Enum.join("\n")
  end

  # 转义 Mermaid 标签中的特殊字符
  defp escape_mermaid_label(label) do
    label
    |> String.replace("\"", "\\\"")
    |> String.replace(~r/[\[\]]/, fn
      "[" -> "("
      "]" -> ")"
      other -> other
    end)
  end
end
