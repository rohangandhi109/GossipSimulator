defmodule Server do
  use GenServer
  def init(values) do
    {:ok,values}
  end

  def insertNeighbour(neigh_list,to) do
    GenServer.cast(to, {:putNeighbour,neigh_list})
  end

  def pushMessage(to, message,stime,numNodes) do
    GenServer.cast(to, {:sendMessage,message,stime,numNodes})
  end

  def handle_cast({:putNeighbour,neighbour},state) do
    [counter,curr_list] = state
    {:noreply,[counter,curr_list++neighbour]}
  end

  def handle_cast({:sendMessage,message,stime,numNodes},state) do
    [counter,curr_list] = state
    counter = counter+1
    IO.puts(counter)
    [{_,count}]=:ets.lookup(:counterTable, "counter")
    [{_,status}] = :ets.lookup(:trackTable, "check")
    if count >=numNodes  and status == 0 do
      :ets.insert(:trackTable, {"check",1})
      converge(stime)
    end
    if counter==10 and count<numNodes do
      [{_,count}]=:ets.lookup(:counterTable, "counter")
      :ets.insert(:counterTable, {"counter",count+1})
    end
    [{_,count}]=:ets.lookup(:counterTable, "counter")
    if counter <10 and count <numNodes do
      rand_neigh = getRandomNeighbour(curr_list)
      [{_,pid}] = :ets.lookup(:processTable, rand_neigh)
      Task.async(fn->Server.pushMessage(pid,message,stime,numNodes)end)
      #Server.pushMessage(self(),message,stime,numNodes)

      #GenServer.cast(pid, {:sendMessage,message,stime,numNodes})
      #Process.sleep(100)
      #GenServer.cast(self(),{:sendMessage,message,stime,numNodes})
    end
    {:noreply,[counter,curr_list]}
  end


  def converge(stime) do
  endTime = System.monotonic_time(:millisecond)
  contime = endTime - stime
    IO.puts("Converged at #{contime}")
  end

  def getRandomNeighbour(curr_list) do
    Enum.random(curr_list)
  end

end





defmodule Topology do
  def main(numNodes,topology,algorithm) do
    :ets.new(:processTable, [:set, :public, :named_table])
    :ets.new(:counterTable, [:set, :public, :named_table])
    :ets.new(:trackTable,[:set, :public, :named_table])
    Enum.each(1..numNodes, fn(x)->
      {:ok,pid}=GenServer.start_link(Server, [0,[]]) #counter,list
      :ets.insert(:processTable, {x,pid})
      :ets.insert(:trackTable, {"check",0})
      :ets.insert(:counterTable,{"counter",0})
    end)
    case algorithm do
       "gossip"-> IO.puts("Gossip")
       "push-sum"->IO.puts("Push Sum")

        _->IO.puts("Invalid Input")
    end

    case topology do
       "full"->full(numNodes)
       "line"->line(numNodes)
       "rand2D"->rand_2d(numNodes)
       "3Dtorus"->torus_3d(numNodes)
       "honeycomb"->honeycomb(numNodes)
       "randhoneycomb"->rand_honeycomb(numNodes)
    end
  end

  def execute(numNodes) do
    stime = System.monotonic_time(:millisecond)
    rand_node = Enum.random(1..numNodes)
    [{_,pid}] = :ets.lookup(:processTable, rand_node)
    message = "gossip"
    Server.pushMessage(pid,message,stime,numNodes)
  end

  def pushSum(numNodes) do

  end

  def full(_numNodes) do

  end

  def line(numNodes) do
    Enum.each(1..numNodes, fn(x)->
      list = cond do
        x==1->[x+1]
        x==numNodes->[x-1]
        true->[x-1,x+1]
     end
      [{_,pid}] = :ets.lookup(:processTable, x)
      Server.insertNeighbour(list,pid)
    end)
    execute(numNodes)
    #pushSum(numNodes)

  end

  def rand_2d(_numNodes) do

  end

  def torus_3d(_numNodes) do

  end

  def honeycomb(_numNodes) do

  end

  def rand_honeycomb(_numNodes) do

  end

end
Topology.main(100,"line","gossip")

