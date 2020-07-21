defmodule Server do
  def main() do
    numNodes = 10
    :ets.new(:processTable, [:set, :public, :named_table])
    Enum.each(1..numNodes, fn(x)->
      :ets.insert(:processTable, {x,0})
    end)
    check()
  end

  def check() do
    Enum.each(1..10, fn(x)->
      IO.inspect(:ets.lookup(:processTable, x))
    end)

  end

end
