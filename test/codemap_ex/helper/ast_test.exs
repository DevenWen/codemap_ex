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
      assert length(block.children) == 3

      # 验证 attrs
      assert length(block.attrs) == 1
      assert hd(block.attrs).key == :moduledoc
      assert hd(block.attrs).value =~ "This is a module for math operations."

      # 验证函数信息
      [func1, func2, func3] = Enum.sort_by(block.children, & &1.name)

      assert func1.__struct__ == CodemapEx.Block.Func
      assert func1.name == :add
      assert length(func1.calls) == 1

      assert func2.__struct__ == CodemapEx.Block.Func
      assert func2.name == :add2
      assert length(func2.calls) == 1

      assert func3.__struct__ == CodemapEx.Block.Func
      assert func3.name == :subtract
      assert length(func3.calls) == 1

      # 验证调用信息
      add_call = hd(func1.calls)
      assert add_call.__struct__ == CodemapEx.Block.Call
      assert add_call.module == nil
      assert add_call.name == :+
      assert add_call.arity == 2

      subtract_call = hd(func2.calls)
      assert subtract_call.__struct__ == CodemapEx.Block.Call
      assert subtract_call.module == nil
      assert subtract_call.name == :add
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

    test "处理管道操作" do
      pipe_ast =
        Code.string_to_quoted!("""
        defmodule Test.Pipe do
          def process(data) do
            data
            |> String.upcase()
            |> String.trim()
          end
        end
        """)

      block = Ast.ast_to_block(pipe_ast)

      # 验证基本结构
      assert block.__struct__ == CodemapEx.Block.Mod
      assert block.name == Test.Pipe

      # 验证函数
      func = hd(block.children)
      assert func.name == :process

      # 验证调用 - 管道操作应该识别出两个 String 模块的调用
      calls = func.calls
      assert length(calls) == 2

      # 验证调用顺序（管道顺序）
      [call1, call2] = calls
      assert call1.module == String
      assert call1.name == :upcase
      assert call1.arity == 1

      assert call2.module == String
      assert call2.name == :trim
      assert call2.arity == 1
    end

    test "处理别名调用" do
      alias_ast =
        Code.string_to_quoted!("""
        defmodule Test.AliasCall do
          alias String, as: Str
          alias List
          
          def transform(data) do
            Str.upcase(data)
            List.flatten(["a", ["b"]])
          end
        end
        """)

      block = Ast.ast_to_block(alias_ast)

      # 验证函数
      func = hd(block.children)

      # 验证调用 - 应该正确识别别名
      assert length(func.calls) == 2

      [call1, call2] = func.calls
      # 应解析 Str 别名为实际模块
      assert call1.module == String
      assert call1.name == :upcase

      assert call2.module == List
      assert call2.name == :flatten
    end

    test "处理 with 语句中的调用" do
      with_ast =
        Code.string_to_quoted!("""
        defmodule Test.WithStatement do
          def process(data) do
            with {:ok, a} <- String.upcase(data),
                 {:ok, b} <- String.trim(a) do
              b
            end
          end
        end
        """)

      block = Ast.ast_to_block(with_ast)

      # 验证函数
      func = hd(block.children)

      # 验证 with 语句中的调用
      calls = func.calls
      assert length(calls) == 2

      [call1, call2] = calls
      assert call1.module == String
      assert call1.name == :upcase

      assert call2.module == String
      assert call2.name == :trim
    end

    test "处理递归调用" do
      recursive_ast =
        Code.string_to_quoted!("""
        defmodule Test.Recursive do
          def factorial(0), do: 1
          def factorial(n) do
            n * factorial(n-1)
          end
        end
        """)

      block = Ast.ast_to_block(recursive_ast)

      # 获取第二个函数子句（递归调用在这里）
      func = Enum.at(block.children, 1)

      # 验证递归调用
      assert Enum.any?(func.calls, fn call ->
               call.name == :factorial and call.arity == 1
             end)
    end

    test "处理实际的 Test.Support.Caller 模块" do
      ast = Ast.module_to_ast(Test.Support.Caller)
      block = Ast.ast_to_block(ast)

      # 验证模块结构
      assert block.__struct__ == CodemapEx.Block.Mod
      assert block.name == Test.Support.Caller

      # 找到特定函数并验证其调用
      foo_func = Enum.find(block.children, &(&1.name == :foo))
      assert foo_func
      assert length(foo_func.calls) == 1
      call = hd(foo_func.calls)
      assert call.module == Test.Support.Math
      assert call.name == :add
      assert call.arity == 2

      # 验证 alias_call 函数
      alias_func = Enum.find(block.children, &(&1.name == :alias_call))
      assert alias_func
      assert length(alias_func.calls) >= 2

      # 验证递归函数
      recursive_func = Enum.find(block.children, &(&1.name == :recursive_call))
      assert recursive_func

      recursive_calls =
        Enum.filter(recursive_func.calls, fn call ->
          call.name == :recursive_call
        end)

      assert length(recursive_calls) == 1
    end
  end
end
