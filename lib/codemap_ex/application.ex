defmodule CodemapEx.Application do
  @moduledoc """
  CodemapEx 应用程序模块。

  负责启动和管理应用程序的所有组件，包括 Parser 服务。
  """
  use Application
  require Logger

  @impl Application
  def start(_type, _args) do
    Logger.info("启动 CodemapEx 应用程序...")

    children = [
      # 启动 Parser 服务
      CodemapEx.Parser
    ]

    # 使用 one_for_one 监督策略启动监督树
    opts = [strategy: :one_for_one, name: CodemapEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
