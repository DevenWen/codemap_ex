defmodule CodemapEx.Helper.Ast do
  @moduledoc false

  alias CodemapEx.Block.{Attr, Call, Func, Mod}

  @doc """
  读取某个模块的源码，并编译成AST代码。

  ## 参数

    * `module` - 要处理的模块名称

  ## 返回值

  返回模块源码对应的AST（抽象语法树）

  ## 示例

      iex> ast = CodemapEx.Helper.Ast.module_to_ast(Test.Support.Math)
      iex> is_tuple(ast) and elem(ast, 0) == :defmodule
      true

  """
  def module_to_ast(module) when is_atom(module) do
    # 获取模块的源文件路径
    case :code.which(module) do
      :non_existing ->
        raise "模块 #{inspect(module)} 不存在"

      _ ->
        with source_path when is_list(source_path) <- module.module_info(:compile)[:source] do
          source_path = List.to_string(source_path)

          case File.read(source_path) do
            {:ok, source} ->
              # mutli module in a file
              source
              |> Code.string_to_quoted!()
              |> select_module_in_ast(module)

            {:error, reason} ->
              raise "无法读取模块 #{inspect(module)} 的源码: reason:#{inspect(reason)}, source_path: #{inspect(source_path)}"
          end
        end
    end
  end

  defp select_module_in_ast(ast, module) do
    Macro.prewalk(ast, nil, fn
      {:defmodule, _, [{:__aliases__, _, module_parts}, _]} = ast, nil ->
        if Module.concat(module_parts) == module do
          {ast, ast}
        else
          {ast, nil}
        end

      ast, acc ->
        {ast, acc}
    end)
    |> elem(1)
  end

  @doc """
  将AST转换为代码块结构。

  此函数接收一个Elixir AST，并将其转换为更易于处理的代码块结构，
  包括模块、函数和函数调用的信息。

  ## 参数

    * `ast` - Elixir AST（通常是从`module_to_ast/1`获得的）

  ## 返回值

  返回一个`ModuleBlock`结构，包含模块的名称和其中的函数块。

  ## 示例

      iex> ast = CodemapEx.Helper.Ast.module_to_ast(Test.Support.Math)
      iex> block = CodemapEx.Helper.Ast.ast_to_block(ast)
      iex> block.name == Test.Support.Math
      true
  """
  def ast_to_block(
        {:defmodule, _, [{:__aliases__, _, module_parts}, [do: {:__block__, _, functions}]]}
      ) do
    module_name = Module.concat(module_parts)

    # 收集模块中的所有别名定义
    aliases = extract_aliases(functions)

    function_blocks =
      functions
      |> Enum.map(&extract_function_block(&1, aliases))
      |> Enum.filter(&(&1 != :ignore))

    attrs_blocks =
      functions
      |> Enum.map(&extract_attrs/1)
      |> Enum.filter(&(&1 != :ignore))

    %Mod{
      name: module_name,
      children: function_blocks,
      attrs: attrs_blocks
    }
  end

  def ast_to_block({:defmodule, _, [{:__aliases__, _, module_parts}, [do: single_function]]}) do
    module_name = Module.concat(module_parts)

    # 单个函数模式下的别名
    aliases = extract_aliases([single_function])

    function_blocks =
      case extract_function_block(single_function, aliases) do
        :ignore -> []
        func -> [func]
      end

    attrs_blocks =
      case extract_attrs(single_function) do
        :ignore -> []
        attr -> [attr]
      end

    %Mod{
      name: module_name,
      children: function_blocks,
      attrs: attrs_blocks
    }
  end

  # 提取模块中的别名定义
  defp extract_aliases(functions) do
    Enum.reduce(functions, %{}, fn
      # 处理简单别名: alias String
      {:alias, _, [{:__aliases__, _, module_parts}]}, acc ->
        module = Module.concat(module_parts)
        last_part = List.last(module_parts)
        Map.put(acc, last_part, module)

      # 处理带 as 的别名: alias String, as: Str
      {:alias, _, [{:__aliases__, _, module_parts}, [as: {:__aliases__, _, [as_name]}]]}, acc ->
        module = Module.concat(module_parts)
        Map.put(acc, as_name, module)

      # 处理多别名: alias Test.Support.{Math, SingleFunction}
      {:alias, _, [{:__block__, _, [{{:., _, [{:__aliases__, _, prefix}, :{}]}, _, parts}]}]}, acc ->
        prefix_mod = Module.concat(prefix)

        Enum.reduce(parts, acc, fn {:__aliases__, _, [name]}, inner_acc ->
          full_module = Module.concat([prefix_mod, name])
          Map.put(inner_acc, name, full_module)
        end)

      _, acc ->
        acc
    end)
  end

  # 从函数定义AST中提取函数块
  defp extract_function_block(
         {:def, _, [{name, _, _}, [do: _body, defaults: _defaults]]},
         _aliases
       ) do
    %Func{
      name: name,
      # 在后续版本中处理默认参数的调用
      calls: []
    }
  end

  # 支持函数特定格式 def func(), do: expr
  defp extract_function_block({:def, _, [{name, _, _args}, [do: body]]}, aliases)
       when is_atom(name) do
    calls = extract_calls(body, aliases)

    %Func{
      name: name,
      calls: calls
    }
  end

  defp extract_function_block(_, _), do: :ignore

  defp extract_attrs({:@, _, [{key, _, [value]}]}) do
    %Attr{
      key: key,
      value: value
    }
  end

  defp extract_attrs(_), do: :ignore

  # 从函数体中提取函数调用，使用别名映射

  # 处理模块函数调用 (Module.function(...)) 
  defp extract_calls(
         {{:., _, [{:__aliases__, _, module_parts}, function_name]}, _, args},
         aliases
       ) do
    # 检查是否是别名
    module =
      case module_parts do
        [part] ->
          # 可能是别名
          Map.get(aliases, part, Module.concat(module_parts))

        _ ->
          # 完整模块路径
          Module.concat(module_parts)
      end

    calls_in_args = Enum.flat_map(args, &extract_calls(&1, aliases))
    [%Call{module: module, name: function_name, arity: length(args)} | calls_in_args]
  end

  # 处理 |> 管道操作符
  defp extract_calls({:|>, _, [left, right]}, aliases) do
    left_calls = extract_calls(left, aliases)

    # 管道右侧通常是函数调用
    right_calls =
      case right do
        # 处理标准形式：expr |> Mod.func()
        {{:., _, [{:__aliases__, _, module_parts}, function_name]}, _, args} ->
          # 解析可能的别名
          module =
            case module_parts do
              [part] -> Map.get(aliases, part, Module.concat(module_parts))
              _ -> Module.concat(module_parts)
            end

          [%Call{module: module, name: function_name, arity: length(args) + 1}]

        # 处理无参数形式：expr |> func
        {function_name, _, nil} when is_atom(function_name) ->
          [%Call{module: nil, name: function_name, arity: 1}]

        # 处理其他形式
        _ ->
          extract_calls(right, aliases)
      end

    left_calls ++ right_calls
  end

  # 处理 with 表达式
  defp extract_calls({:with, _, clauses}, aliases) do
    Enum.flat_map(clauses, fn
      # <- 操作符左侧的模式，右侧的表达式
      {:<-, _, [_pattern, expr]} -> extract_calls(expr, aliases)
      # do 块
      {:do, block} -> extract_calls(block, aliases)
      # else 块
      {:else, block} -> extract_calls(block, aliases)
      # 其他表达式
      expr -> extract_calls(expr, aliases)
    end)
  end

  # 处理元组
  defp extract_calls({left, right}, aliases) do
    extract_calls(left, aliases) ++ extract_calls(right, aliases)
  end

  # 处理元组的另一种形式
  defp extract_calls({:{}, _, elements}, aliases) do
    Enum.flat_map(elements, &extract_calls(&1, aliases))
  end

  # 处理列表
  defp extract_calls(list, aliases) when is_list(list) do
    Enum.flat_map(list, &extract_calls(&1, aliases))
  end

  # 处理代码块
  defp extract_calls({:__block__, _, expressions}, aliases) do
    Enum.flat_map(expressions, &extract_calls(&1, aliases))
  end

  # 处理普通函数调用 (function(...))
  defp extract_calls({function_name, _, args}, aliases)
       when is_atom(function_name) and is_list(args) do
    call = %Call{module: nil, name: function_name, arity: length(args)}

    # 收集参数中的调用
    arg_calls = Enum.flat_map(args, &extract_calls(&1, aliases))

    [call | arg_calls]
  end

  # 处理基本类型和无法识别的模式
  defp extract_calls(expr, _) when is_number(expr) or is_binary(expr) or is_atom(expr), do: []
  defp extract_calls(_, _), do: []
end
