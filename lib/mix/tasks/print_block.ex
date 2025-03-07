defmodule Mix.Tasks.PrintBlock do
  @moduledoc """
  打印指定模块转换为 Block 结构的结果

  ## 使用方式

      mix print_block Module.Name [--indent 2]

  ## 选项

    * `--indent` - 缩进空格数量，默认为 2

  ## 示例

      mix print_block Enum
      mix print_block Test.Support.Math --indent 4
  """

  use Mix.Task
  alias CodemapEx.Helper.Ast

  @shortdoc "打印指定模块的 Block 结构"
  def run(args) do
    {opts, module_names, _} =
      OptionParser.parse(args,
        strict: [indent: :integer],
        aliases: [i: :indent]
      )

    indent_size = Keyword.get(opts, :indent, 2)

    case module_names do
      [] ->
        Mix.raise("请提供一个模块名称，例如：mix print_block Enum")

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
          # 将模块转换为 AST
          ast = Ast.module_to_ast(module)

          # 将 AST 转换为 Block 结构
          block = Ast.ast_to_block(ast)

          # 打印 Block 结构
          print_block(block, indent_size)
        rescue
          error ->
            Mix.raise("无法处理模块 #{module_name}: #{inspect(error)}")
        end
    end
  end

  # 打印 Block 结构
  defp print_block(block, indent_size) do
    opts = [pretty: true, width: 80, indent: indent_size, structs: false]
    IO.puts(inspect(block, opts))
  end
end
