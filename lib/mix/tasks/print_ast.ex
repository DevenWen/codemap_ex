defmodule Mix.Tasks.PrintAst do
  @moduledoc """
  打印指定模块的 AST 结构

  ## 使用方式

      mix print_ast Module.Name [--indent 2]

  ## 选项

    * `--indent` - 缩进空格数量，默认为 2

  ## 示例

      mix print_ast Enum
      mix print_ast Enum.Map --indent 4
  """

  use Mix.Task
  alias CodemapEx.Helper.Ast

  @shortdoc "打印指定模块的 AST 结构"
  def run(args) do
    {opts, module_names, _} =
      OptionParser.parse(args,
        strict: [indent: :integer],
        aliases: [i: :indent]
      )

    indent_size = Keyword.get(opts, :indent, 2)

    case module_names do
      [] ->
        Mix.raise("请提供一个模块名称，例如：mix print_ast Enum")

      [module_name | _] ->
        module =
          try do
            String.to_existing_atom("Elixir." <> module_name)
          rescue
            ArgumentError ->
              parts = String.split(module_name, ".")

              try do
                Module.concat(parts)
              rescue
                ArgumentError ->
                  Mix.raise("模块 #{module_name} 不存在或无法解析")
              end
          end

        try do
          ast = Ast.module_to_ast(module)
          print_ast(ast, indent_size)
        rescue
          error ->
            Mix.raise("无法获取模块 #{module_name} 的 AST: #{inspect(error)}")
        end
    end
  end

  # 直接打印 AST，保持原始格式
  defp print_ast(ast, indent_size) do
    opts = [pretty: true, width: 80, indent: indent_size]
    IO.puts(inspect(ast, opts))
  end
end
