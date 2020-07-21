defmodule GossipServer do
  use GenServer


  def start_link(msg,node) do
    {:ok,pid}=GenServer.start_link(__MODULE__,[0,[],msg,node]) #counter,list,s,w
    :ets.insert(:processTable, {node,pid})
  end

  def init(values) do
    Process.flag(:trap_exit, true)
    {:ok,values}
  end

  def insertNeighbour(neigh_list,to) do
    x = 0
    GenServer.cast(to, {:updateList,neigh_list,x})
  end


  def setCounter(pid,counter) do
    GenServer.cast(pid,{:updateCounter,counter})
  end

  def updateNeighbour(to,element) do
    x = 1
    GenServer.cast(to,{:updateList,element,x})
  end


  def getvalues(processID) do
    state=GenServer.call(processID,{:getstate})
    state
  end

  def handle_call({:getstate},_from,state) do
    {:reply,state,state}
  end

  def handle_call({:getCounter},_from,state) do
    [counter,_curr_list,_s,_w] = state
    {:reply,counter,state}
  end



  def getRandomNeighbour(curr_list,counter,threshold) do
    if curr_list == [] do
      []
    else
      rand_neigh = Enum.random(curr_list)
      [{_,rand_pid}] = :ets.lookup(:processTable, rand_neigh)
      if(counter==threshold) do
        updated_list = curr_list -- [rand_neigh]
        updateNeighbour(rand_pid,rand_neigh)
        getRandomNeighbour(updated_list,counter,threshold)
      else
        rand_neigh
      end
    end
  end



  def handle_cast({:updateList,elements,x},state) do
    [counter,curr_list,s,w] = state
    if x == 1 do
      #update list
      {:noreply,[counter,curr_list--[elements],s,w]}
    else
      {:noreply,[counter,curr_list++elements,s,w]}
    end

  end


  def handle_cast({:sendMessage,message,stime},state) do
    [counter,curr_list,s,w] = state
    counter = counter+1
    [{_,count}]=:ets.lookup(:counterTable, "counter")
    [{_,topology}]=:ets.lookup(:numTable,"topology")


    #NOTE: Change/Reduce the p value if convergence takes more than 30000 ms to run on a n<1000
    p = cond do
      topology=="rand2D" ->0.8
      topology=="line"->0.3 # may also converge at 0.5 for higher order
      topology=="honeycomb"->0.8
      true->0.9
    end

    #IO.puts(count)
    [{_,status}] = :ets.lookup(:trackTable, "check")
    [{_,num}] = :ets.lookup(:numTable, "num")
    if count >=num*p and status == 0 do
      :ets.insert(:trackTable, {"check",1})
      endTime = System.os_time(:millisecond)
      conTime = endTime - stime
      IO.puts("Converged at #{conTime} ms")
      System.halt(1)
    end
    if counter==10 and count<num do
      [{_,count}]=:ets.lookup(:counterTable, "counter")
      :ets.insert(:counterTable, {"counter",count+1})
    end
    [{_,count}]=:ets.lookup(:counterTable, "counter")
    if counter <10 and count <num do
      rand_neigh = getRandomNeighbour(curr_list,counter,10)
      if(rand_neigh != []) do
        [{_,pid}] = :ets.lookup(:processTable, rand_neigh)
        spawn fn->GenServer.cast(pid, {:sendMessage,message,stime}) end
        Process.sleep(100)
        GenServer.cast(self(),{:sendMessage,message,stime})
      end
    end
    {:noreply,[counter,curr_list,s,w]}
  end

  def sendGossip(new_msg,processID,stime) do
    GenServer.cast(processID,{:sendMessage,new_msg,stime})
    loop()
  end


  def loop() do
    loop()
  end


  def converge(startTime) do
    [{_,currentCount}]=:ets.lookup(:counterTable,"counter")
    t = currentCount + 1
    :ets.insert(:counterTable,{"counter",t})
    [{_,num}] = :ets.lookup(:numTable, "num")
    if(t>=trunc(num) and num >0) do
      endTime = System.os_time(:millisecond)
      conTime = endTime - startTime
      :ets.insert(:numTable,{"num",-999})
      IO.puts("Convergence time is #{conTime} ms")
      System.halt(1)
    else

    end
  end
end
