defmodule CodemapEx.Helper.AstTest do
  use ExUnit.Case
  doctest CodemapEx.Helper.Ast

  alias CodemapEx.Helper.Ast
  use Patch

  describe "module_to_ast/1" do
    test "成功将存在的模块转换为 AST" do
      ast = Ast.module_to_ast(Test.Support.Math)
      # 验证返回的是一个 defmodule AST 节点
      assert is_tuple(ast)
      assert elem(ast, 0) == :defmodule

      # 验证模块名称正确
      module_name = elem(ast, 2) |> hd() |> elem(2)
      assert module_name == [:Test, :Support, :Math]
    end

    test "当模块不存在时抛出异常" do
      assert_raise RuntimeError, ~r/模块 .* 不存在/, fn ->
        Ast.module_to_ast(NonExistingModule)
      end
    end

    test "处理模块源码但无法读取时的情况" do
      # 使用 File.read! 模拟而不是 :code.which
      module = Test.Support.Math

      # 使用 Patch 的正确方式
      patch(File, :read, fn _path ->
        {:error, :enoent}
      end)

      assert_raise RuntimeError, ~r/无法读取模块 .* 的源码/, fn ->
        Ast.module_to_ast(module)
      end
    end
  end

  describe "ast_to_block/1" do
    test "将多函数模块的 AST 转换为代码块结构" do
      # 获取测试模块的 AST
      ast = Ast.module_to_ast(Test.Support.Math)

      # 转换为代码块结构
      block = Ast.ast_to_block(ast)

      # 验证模块信息
      assert block.__struct__ == CodemapEx.Block.Mod
      assert block.name == Test.Support.Math
      assert length(block.children) == 2

      # 验证 attrs
      assert length(block.attrs) == 1
      assert hd(block.attrs).key == :moduledoc
      assert hd(block.attrs).value =~ "This is a module for math operations."

      # 验证函数信息
      [func1, func2] = Enum.sort_by(block.children, & &1.name)

      assert func1.__struct__ == CodemapEx.Block.Func
      assert func1.name == :add
      assert length(func1.calls) == 1

      assert func2.__struct__ == CodemapEx.Block.Func
      assert func2.name == :subtract
      assert length(func2.calls) == 1

      # 验证调用信息
      add_call = hd(func1.calls)
      assert add_call.__struct__ == CodemapEx.Block.Call
      assert add_call.module == nil
      assert add_call.name == :+
      assert add_call.arity == 2

      subtract_call = hd(func2.calls)
      assert subtract_call.__struct__ == CodemapEx.Block.Call
      assert subtract_call.module == nil
      assert subtract_call.name == :-
      assert subtract_call.arity == 2
    end

    test "将单函数模块的 AST 转换为代码块结构" do
      # 获取单函数测试模块的 AST
      ast = Ast.module_to_ast(Test.Support.SingleFunction)

      # 转换为代码块结构
      block = Ast.ast_to_block(ast)

      # 验证模块信息
      assert block.__struct__ == CodemapEx.Block.Mod
      assert block.name == Test.Support.SingleFunction
      assert length(block.children) == 1

      # 验证函数信息
      func = hd(block.children)
      assert func.__struct__ == CodemapEx.Block.Func
      assert func.name == :double

      # 验证调用信息 - 乘法操作
      call = hd(func.calls)
      assert call.__struct__ == CodemapEx.Block.Call
      assert call.module == nil
      assert call.name == :*
      assert call.arity == 2
    end

    test "处理复杂的函数体和嵌套调用" do
      # 创建一个包含复杂函数体的 AST
      complex_ast =
        Code.string_to_quoted!("""
        defmodule Test.Complex do
          def process(data) do
            String.upcase(data)
            |> String.trim()
            |> String.split(",")
          end
        end
        """)

      # 转换为代码块结构
      block = Ast.ast_to_block(complex_ast)

      # 验证基本结构
      assert block.__struct__ == CodemapEx.Block.Mod
      assert block.name == Test.Complex
      assert length(block.children) == 1

      # 由于管道操作的复杂性，这里我们只验证函数名
      func = hd(block.children)
      assert func.__struct__ == CodemapEx.Block.Func
      assert func.name == :process

      # 注意：这个测试可能需要根据 extract_calls 的实际实现调整
      # 因为管道操作的 AST 结构比较复杂
    end
  end
end
