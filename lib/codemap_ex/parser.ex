defmodule CodemapEx.Parser do
  @moduledoc """
  代码解析服务，负责扫描和解析项目中的 Elixir 模块。

  此服务会将项目中所有模块转换为 Block 结构并存储在 ETS 表中，便于快速查询。
  """
  use GenServer
  alias CodemapEx.Helper.Ast
  require Logger

  @table_name :codemap_blocks

  # 客户端 API

  @doc """
  启动解析服务
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  扫描项目并解析所有模块
  """
  def scan_modules do
    GenServer.cast(__MODULE__, :scan_modules)
  end

  @doc """
  获取指定模块的 Block 结构
  """
  def get_block(module) when is_atom(module) do
    case :ets.lookup(@table_name, module) do
      [{^module, block}] -> {:ok, block}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  列出已解析的所有模块
  """
  def list_modules do
    :ets.tab2list(@table_name)
    |> Enum.map(fn {module, _} -> module end)
  end

  # 服务器回调

  @impl GenServer
  def init(_opts) do
    # 创建 ETS 表用于存储 Block 结构
    table = :ets.new(@table_name, [:set, :named_table, :public, read_concurrency: true])

    # 初始状态
    {:ok, %{table: table}, {:continue, :scan_modules}}
  end

  @impl GenServer
  def handle_continue(:scan_modules, state) do
    scan_project_modules()
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:scan_modules, state) do
    scan_project_modules()
    {:noreply, state}
  end

  # 辅助函数

  # 扫描和解析项目模块
  defp scan_project_modules do
    Logger.info("开始扫描项目模块...")

    # 获取项目的lib目录
    lib_path =
      Application.app_dir(Mix.Project.config()[:app], "ebin")
      |> Path.dirname()

    Logger.info("lib_path: #{lib_path}")

    # 扫描所有 beam 文件并提取模块
    beam_files = Path.wildcard(Path.join(lib_path, "**/*.beam"))

    modules =
      beam_files
      |> Enum.map(fn path ->
        path
        |> Path.basename(".beam")
        |> String.to_atom()
      end)

    Logger.info("发现 #{length(modules)} 个模块")

    # 加载和解析模块
    Enum.each(modules, &process_module/1)

    Logger.info("模块扫描完成，共解析 #{:ets.info(@table_name, :size)} 个模块")
  end

  # 处理单个模块，转换为 Block 并存储
  defp process_module(module) do
    try do
      # 获取模块的 AST
      ast = Ast.module_to_ast(module)

      # 转换为 Block
      block = Ast.ast_to_block(ast)

      # 存储到 ETS 表
      :ets.insert(@table_name, {module, block})

      Logger.debug("成功解析模块：#{inspect(module)}")
    rescue
      e ->
        Logger.warning("解析模块 #{inspect(module)} 失败：#{inspect(e)}")
    end
  end
end
