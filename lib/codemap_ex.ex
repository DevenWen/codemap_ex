defmodule CodemapEx do
  @moduledoc """
  CodemapEx - Elixir 代码映射和分析工具。

  提供对项目中所有模块的分析和查询功能，可以了解每个代码块调用了哪些 Elixir 方法，
  帮助理解代码结构和依赖关系。
  """
  alias CodemapEx.Graph
  alias CodemapEx.Parser
  require Logger

  @doc """
  获取指定模块的代码块结构。

  ## 参数

    * `module` - 要查询的模块（原子）

  ## 返回值

    * `{:ok, block}` - 成功返回模块的代码块结构
    * `{:error, reason}` - 发生错误，返回错误原因
    
  ## 示例

      iex> CodemapEx.get_block(Test.Support.Math)
      {:ok, %CodemapEx.Block.Mod{}}
  """
  def get_block(module) when is_atom(module) do
    Parser.get_block(module)
  end

  @doc """
  获取指定模块的代码块结构，如果模块不存在则抛出错误。

  ## 参数

    * `module` - 要查询的模块（原子）

  ## 返回值

    * 模块的代码块结构
    
  ## 示例

      iex> block = CodemapEx.get_block!(Test.Support.Math)
      %CodemapEx.Block.Mod{}
  """
  def get_block!(module) when is_atom(module) do
    case get_block(module) do
      {:ok, block} -> block
      {:error, reason} -> raise "无法获取模块 #{inspect(module)} 的代码块：#{reason}"
    end
  end

  @doc """
  列出已解析的所有模块。

  ## 返回值

    * 模块名称（原子）的列表

  """
  def list_modules do
    Parser.list_modules()
  end

  @doc """
  手动触发重新扫描项目中的所有模块。

  此操作将重新扫描并解析项目中的所有模块，更新内部 ETS 表。
  """
  def rescan do
    Parser.scan_modules()
  end

  @doc """
  构建函数调用图。

  从指定的函数开始，递归遍历所有相关的函数调用，构建一个有向无环图。

  ## 参数

    * `module` - 起始函数所在的模块（原子）
    * `function` - 起始函数的名称（原子）
    * `arity` - 起始函数的参数数量（整数）
    
  ## 返回值

    * `{:ok, graph}` - 成功构建调用图
    * `{:error, reason}` - 发生错误，返回错误原因
    
  ## 示例

      iex> CodemapEx.build_call_graph(Enum, :map, 2)
      {:ok, %CodemapEx.Graph{start: {Enum, :map, 2}, nodes: [{Enum, :map, 2}], edges: []}}
  """
  def build_call_graph(module, function, arity)
      when is_atom(module) and is_atom(function) and is_integer(arity) do
    try do
      start_node = {module, function, arity}

      # 初始化图结构
      graph = Graph.new(start_node)

      # 开始递归遍历
      result = traverse_calls(graph, [start_node], MapSet.new([start_node]))

      {:ok, result}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  @doc """
  构建函数调用图，如果失败则抛出错误。

  ## 参数

    * `module` - 起始函数所在的模块（原子）
    * `function` - 起始函数的名称（原子）
    * `arity` - 起始函数的参数数量（整数）
    
  ## 返回值

    * 调用图结构
    
  ## 示例

      iex> graph = CodemapEx.build_call_graph!(Enum, :map, 2)
      %CodemapEx.Graph{start: {Enum, :map, 2}, nodes: [{Enum, :map, 2}], edges: []}
  """
  def build_call_graph!(module, function, arity) do
    case build_call_graph(module, function, arity) do
      {:ok, graph} -> graph
      {:error, reason} -> raise "构建调用图失败：#{reason}"
    end
  end

  @doc """
  构建函数调用图并以美观格式打印结果。

  此函数会构建调用图并将结果以易读的格式输出到控制台。

  ## 参数

    * `module` - 起始函数所在的模块（原子）
    * `function` - 起始函数的名称（原子）
    * `arity` - 起始函数的参数数量（整数）
    
  ## 返回值

    * 调用图结构（与 build_call_graph! 相同）
    
  ## 示例

      iex> graph = CodemapEx.build_call_graph!(Enum, :map, 2)
      iex> CodemapEx.pretty_print_call_graph(graph)
      函数调用图 - 起始点: Enum.map/2
      节点数量: 12
      边数量: 15
      
      节点列表:
      - Enum.map/2
      - List.map/2
      - ...
      
      调用关系:
      - Enum.map/2 -> List.map/2
      - ...
      
      %CodemapEx.Graph{start: {Enum, :map, 2}, nodes: [...], edges: [...]}
  """
  def pretty_print_call_graph(graph) do
    Graph.pretty_print(graph)
  end

  @doc """
  将调用图转换为 Mermaid 格式。

  ## 参数

    * `graph` - 调用图结构
  """
  def to_mermaid(graph) do
    Graph.to_mermaid(graph)
  end

  # 递归遍历函数调用
  defp traverse_calls(graph, [], _visited) do
    # 遍历完成，整理结果
    %Graph{
      start: graph.start,
      nodes: graph.nodes,
      edges: graph.edges
    }
  end

  defp traverse_calls(
         graph,
         [{curr_module, curr_function, curr_arity} = curr_node | queue],
         visited
       ) do
    # 获取当前函数的调用
    calls =
      case get_function_calls(curr_module, curr_function, curr_arity) do
        {:ok, calls_list} -> calls_list
        {:error, _} -> []
      end

    # 处理每个调用，添加边和节点
    {new_graph, new_queue, new_visited} = process_calls(calls, curr_node, graph, queue, visited)

    # 继续处理队列中的下一个节点
    traverse_calls(new_graph, new_queue, new_visited)
  end

  # 处理函数调用列表
  defp process_calls(calls, curr_node, graph, queue, visited) do
    Enum.reduce(calls, {graph, queue, visited}, fn call, acc ->
      process_single_call(call, curr_node, acc)
    end)
  end

  # 处理单个函数调用
  defp process_single_call(call, curr_node, {graph, queue, visited}) do
    call_node = {call.module, call.name, call.arity}

    # 检查是否已经访问过该节点
    if MapSet.member?(visited, call_node) do
      # 已访问，只添加边（如果边不存在）
      add_edge_if_needed(curr_node, call_node, graph, queue, visited)
    else
      # 未访问，添加节点、边和队列
      add_node_and_edge(curr_node, call_node, graph, queue, visited)
    end
  end

  # 如果需要则添加边
  defp add_edge_if_needed(curr_node, call_node, graph, queue, visited) do
    if Enum.member?(graph.edges, {curr_node, call_node}) do
      {graph, queue, visited}
    else
      {Graph.add_edge(graph, curr_node, call_node), queue, visited}
    end
  end

  # 添加节点和边
  defp add_node_and_edge(curr_node, call_node, graph, queue, visited) do
    new_graph = Graph.add_edge(graph, curr_node, call_node)
    new_queue = queue ++ [call_node]
    new_visited = MapSet.put(visited, call_node)

    {new_graph, new_queue, new_visited}
  end

  # 获取函数的调用列表
  defp get_function_calls(module, function, arity) do
    case get_block(module) do
      {:ok, mod_block} ->
        # 查找对应函数
        func =
          Enum.find(mod_block.children, fn f ->
            f.name == function && (arity == nil || function_matches_arity?(f, arity))
          end)

        case func do
          nil -> {:error, :function_not_found}
          f -> {:ok, f.calls}
        end

      {:error, reason} ->
        Logger.warning("获取模块 #{inspect(module)} 的 Block 失败：#{reason}")
        {:error, reason}
    end
  end

  # 检查函数是否匹配给定的参数数量
  defp function_matches_arity?(func, arity) do
    cond do
      # 尝试直接从 arity 字段获取（如果存在）
      Map.has_key?(func, :arity) ->
        func.arity == arity

      # 尝试从 args 字段计算（如果存在）
      Map.has_key?(func, :args) && is_list(func.args) ->
        length(func.args) == arity

      # 如果找不到任何参数相关信息，默认匹配（但记录警告）
      true ->
        Logger.warning("无法确定函数 #{func.name} 的参数数量，默认匹配")
        true
    end
  end
end
