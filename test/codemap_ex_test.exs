defmodule CodemapExTest do
  use ExUnit.Case

  alias CodemapEx.Block.{Mod, Func, Call}
  alias CodemapEx.Graph
  use Patch

  setup do
    # 使用测试模块
    test_module = Test.Support.Math
    test_function = :add
    test_arity = 2

    # 模拟模块块结构
    mock_mod_block = %Mod{
      name: test_module,
      children: [
        %Func{
          name: test_function,
          calls: [
            %Call{module: Kernel, name: :+, arity: 2}
          ]
        },
        %Func{
          name: :subtract,
          calls: [
            %Call{module: Kernel, name: :-, arity: 2}
          ]
        },
        %Func{
          name: :add2,
          calls: [
            %Call{module: Test.Support.Math, name: :add, arity: 2}
          ]
        }
      ],
      attrs: []
    }

    {:ok,
     %{
       test_module: test_module,
       test_function: test_function,
       test_arity: test_arity,
       mock_mod_block: mock_mod_block
     }}
  end

  describe "get_block/1" do
    test "成功获取模块块结构", %{test_module: test_module, mock_mod_block: mock_mod_block} do
      # 模拟 Parser.get_block 函数
      patch(CodemapEx.Parser, :get_block, fn ^test_module ->
        {:ok, mock_mod_block}
      end)

      # 测试获取块结构
      assert {:ok, block} = CodemapEx.get_block(test_module)
      assert block.name == test_module
      assert length(block.children) == 3
    end

    test "处理模块不存在的情况" do
      # 模拟模块不存在
      patch(CodemapEx.Parser, :get_block, fn _ ->
        {:error, :not_found}
      end)

      # 测试错误处理
      assert {:error, :not_found} = CodemapEx.get_block(NonExistingModule)
    end
  end

  describe "get_block!/1" do
    test "成功获取模块块结构", %{test_module: test_module, mock_mod_block: mock_mod_block} do
      # 模拟 Parser.get_block 函数
      patch(CodemapEx.Parser, :get_block, fn ^test_module ->
        {:ok, mock_mod_block}
      end)

      # 测试获取块结构
      block = CodemapEx.get_block!(test_module)
      assert block.name == test_module
      assert length(block.children) == 3
    end

    test "模块不存在时抛出异常" do
      # 模拟模块不存在
      patch(CodemapEx.Parser, :get_block, fn _ ->
        {:error, :not_found}
      end)

      # 测试异常抛出
      assert_raise RuntimeError, ~r/无法获取模块/, fn ->
        CodemapEx.get_block!(NonExistingModule)
      end
    end
  end

  describe "list_modules/0" do
    test "返回模块列表" do
      # 模拟模块列表
      modules = [Enum, String, List]
      patch(CodemapEx.Parser, :list_modules, fn -> modules end)

      # 测试列表获取
      assert CodemapEx.list_modules() == modules
    end
  end

  describe "rescan/0" do
    test "调用 Parser.scan_modules 函数" do
      # 创建一个标志变量
      flag = :ets.new(:test_flag, [:set, :public])
      :ets.insert(flag, {:called, false})

      # 使用标志变量跟踪调用
      patch(CodemapEx.Parser, :scan_modules, fn ->
        :ets.insert(flag, {:called, true})
      end)

      # 测试调用
      CodemapEx.rescan()
      assert :ets.lookup(flag, :called) == [{:called, true}]
    end
  end

  describe "build_call_graph/3" do
    test "成功构建调用图", %{
      test_module: test_module,
      test_function: test_function,
      test_arity: test_arity,
      mock_mod_block: mock_mod_block
    } do
      # 模拟函数调用图构建所需的依赖
      patch(CodemapEx.Parser, :get_block, fn
        ^test_module -> {:ok, mock_mod_block}
        # Kernel 模块不存在于测试中
        Kernel -> {:error, :not_found}
      end)

      # 测试调用图构建
      {:ok, graph} = CodemapEx.build_call_graph(test_module, test_function, test_arity)

      # 验证图结构
      assert graph.start == {test_module, test_function, test_arity}
      assert length(graph.nodes) >= 1

      # 验证边关系（至少应该有一条到 Kernel.:+ 的边）
      assert Enum.any?(graph.edges, fn {from, to} ->
               from == {test_module, test_function, test_arity} && to == {Kernel, :+, 2}
             end)
    end

    test "处理模块不存在情况", %{
      test_module: test_module,
      test_function: test_function,
      test_arity: test_arity
    } do
      # 模拟模块不存在
      patch(CodemapEx.Parser, :get_block, fn _ -> raise "模块不存在" end)

      # 测试错误处理
      {:error, reason} = CodemapEx.build_call_graph(test_module, test_function, test_arity)
      assert reason =~ "模块不存在"
    end
  end

  describe "build_call_graph!/3" do
    test "成功构建调用图", %{
      test_module: test_module,
      test_function: test_function,
      test_arity: test_arity,
      mock_mod_block: mock_mod_block
    } do
      # 模拟函数调用图构建所需的依赖
      patch(CodemapEx.Parser, :get_block, fn
        ^test_module -> {:ok, mock_mod_block}
        # Kernel 模块不存在于测试中
        Kernel -> {:error, :not_found}
      end)

      # 测试调用图构建
      graph = CodemapEx.build_call_graph!(test_module, test_function, test_arity)

      # 验证图结构
      assert graph.start == {test_module, test_function, test_arity}
      assert length(graph.nodes) >= 1
    end

    test "模块不存在时抛出异常", %{
      test_module: test_module,
      test_function: test_function,
      test_arity: test_arity
    } do
      # 模拟模块不存在
      patch(CodemapEx.Parser, :get_block, fn _ -> raise "fire!!" end)

      # 测试异常抛出
      assert_raise RuntimeError, ~r/构建调用图失败/, fn ->
        CodemapEx.build_call_graph!(test_module, test_function, test_arity)
      end
    end
  end

  describe "pretty_print_call_graph/1" do
    test "格式化打印调用图", %{
      test_module: test_module,
      test_function: test_function,
      test_arity: test_arity
    } do
      # 准备测试数据
      graph = %Graph{
        start: {test_module, test_function, test_arity},
        nodes: [{test_module, test_function, test_arity}, {Kernel, :+, 2}],
        edges: [{{test_module, test_function, test_arity}, {Kernel, :+, 2}}]
      }

      # 捕获输出
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          CodemapEx.pretty_print_call_graph(graph)
        end)

      # 验证输出包含预期内容
      assert output =~ "函数调用图 - 起始点"
      assert output =~ "Math.add/2"
      assert output =~ "节点数量: 2"
      assert output =~ "边数量: 1"
      assert output =~ "节点列表:"
      assert output =~ "调用关系:"
      assert output =~ "-> Kernel.+/2"
    end
  end

  # 测试内部功能的辅助函数
  describe "内部功能" do
    test "复杂的调用图递归追踪", %{test_module: test_module, mock_mod_block: mock_mod_block} do
      # 模拟递归调用场景
      recursive_mock = %Mod{
        name: Test.Support.Caller,
        children: [
          %Func{
            name: :recursive_call,
            calls: [
              %Call{module: Test.Support.Caller, name: :recursive_call, arity: 0}
            ]
          },
          %Func{
            name: :foo,
            calls: [
              %Call{module: test_module, name: :add, arity: 2}
            ]
          }
        ],
        attrs: []
      }

      # 模拟获取块
      patch(CodemapEx.Parser, :get_block, fn
        Test.Support.Caller -> {:ok, recursive_mock}
        ^test_module -> {:ok, mock_mod_block}
        _ -> {:error, :not_found}
      end)

      # 测试递归调用图
      {:ok, graph} = CodemapEx.build_call_graph(Test.Support.Caller, :recursive_call, 0)

      # 验证图包含递归调用但不会无限循环
      assert Enum.any?(graph.edges, fn {from, to} ->
               from == {Test.Support.Caller, :recursive_call, 0} &&
                 to == {Test.Support.Caller, :recursive_call, 0}
             end)

      # 验证节点数量是有限的
      assert length(graph.nodes) < 10
    end
  end

  test "to_mermaid 函数生成正确的 Mermaid 图表代码" do
    # 创建一个简单的调用图
    graph = %Graph{
      start: {ModuleA, :func_a, 1},
      nodes: [
        {ModuleA, :func_a, 1},
        {ModuleB, :func_b, 2},
        {ModuleC, :func_c, 0}
      ],
      edges: [
        {{ModuleA, :func_a, 1}, {ModuleB, :func_b, 2}},
        {{ModuleB, :func_b, 2}, {ModuleC, :func_c, 0}}
      ]
    }

    # 调用 to_mermaid 函数
    mermaid_code = CodemapEx.to_mermaid(graph)

    # 验证生成的 Mermaid 代码
    assert is_binary(mermaid_code)
    assert mermaid_code =~ "graph TD"
    assert mermaid_code =~ "ModuleA.func_a/1"
    assert mermaid_code =~ "ModuleB.func_b/2"
    assert mermaid_code =~ "ModuleC.func_c/0"
    # 检查是否存在节点连接，但不依赖具体的节点 ID 格式
    assert mermaid_code =~ " --> "
    # 检查是否包含节点定义
    assert mermaid_code =~ "[\""
    assert mermaid_code =~ "\"]"
  end
end
