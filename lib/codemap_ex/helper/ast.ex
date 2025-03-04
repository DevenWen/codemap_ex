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

    function_blocks =
      functions
      |> Enum.map(&extract_function_block/1)
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

    function_blocks = [extract_function_block(single_function)]

    %Mod{
      name: module_name,
      children: function_blocks
    }
  end

  # 从函数定义AST中提取函数块
  defp extract_function_block({:def, _, [{name, _, _args}, [do: body]]}) do
    calls = extract_calls(body)

    %Func{
      name: name,
      calls: calls
    }
  end

  defp extract_function_block(_), do: :ignore

  defp extract_attrs({:@, _, [{key, _, [value]}]}) do
    %Attr{
      key: key,
      value: value
    }
  end

  defp extract_attrs(_), do: :ignore

  # 从函数体中提取函数调用
  defp extract_calls({{:., _, [{:__aliases__, _, module_parts}, function_name]}, _, args}) do
    module = Module.concat(module_parts)
    [%Call{module: module, name: function_name, arity: length(args)}]
  end

  defp extract_calls({function_name, _, args}) when is_atom(function_name) and is_list(args) do
    [%Call{module: nil, name: function_name, arity: length(args)}]
  end

  defp extract_calls({:__block__, _, expressions}) do
    Enum.flat_map(expressions, &extract_calls/1)
  end

  defp extract_calls(_) do
    []
  end
end
