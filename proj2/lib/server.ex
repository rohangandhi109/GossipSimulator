defmodule Server do
  use GenServer

  def start_link(node) do
    {:ok,pid}=GenServer.start_link(__MODULE__,[0,[],node,1]) #counter,list,s,w
    :ets.insert(:processTable, {node,pid})
  end

  def init(values) do
    #IO.inspect(values)
    {:ok,values}
  end




  #-----------------PushSum----------------------

  def startPushSum(to) do
    GenServer.cast(to,:executePushSum)
  end



  def setCounter(pid,counter) do
    x = 3
    GenServer.cast(pid,{:updateList,counter,x})
  end


  def insertNeighbour(neigh_list,to) do
    x = 0
    GenServer.cast(to, {:updateList,neigh_list,x})
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

  def sendPushSum(sn,wn,processID,stime) do
    [count,curr_list,s,w] = GenServer.call(processID,{:getstate})
      old_avg = s/w
      new_avg = (s+sn)/(w+wn)
      rand_neigh = getRandomNeighbour(curr_list,3)
      if count !=3 do
        diffAvg = abs(old_avg-new_avg)
        threshold = :math.pow(10,-10)
        #IO.puts(new_avg)
        if (diffAvg < threshold) do
          count = count + 1
          if count == 3 do
            #IO.puts(new_avg)
            converge(stime)
          end
          setCounter(processID,count)
        else
          #since we are looking at the consecutive round so we again set counter to 0
          count = 0
          setCounter(processID,count)
        end
        updateState(processID,(s+sn)/2,(w+wn)/2)
      end
      if rand_neigh != [] do
        [{_,rand_pid}] = :ets.lookup(:processTable, rand_neigh)
        sendToNeighbour(sn,wn,s,w,rand_pid,count,stime)
      else
        converge(stime)
      end
  end

  def sendToNeighbour(sn,wn,s,w,pid,countStatus,stime) do
    # if count == 3 send old value..means it is already terminated but can send if it has neighbour
    if countStatus == 3 do
     spawn (fn->sendPushSum(s/2,w/2,pid,stime) end)
     #Process.sleep(100)
    else
      sendPushSum((s+sn)/2,(w+wn)/2,pid,stime)
    end
  end

  def getRandomNeighbour(curr_list,threshold) do
    if curr_list == [] do
      []
    else
      rand_neigh = Enum.random(curr_list)
      [{_,rand_pid}] = :ets.lookup(:processTable, rand_neigh)
      counter = GenServer.call(rand_pid,{:getCounter})

      if(counter==threshold) do
        updated_list = curr_list -- [rand_neigh]
        updateNeighbour(rand_pid,rand_neigh)
        getRandomNeighbour(updated_list,threshold)
      else
        rand_neigh
      end
    end
  end

  def pushMessage(to, message) do
    GenServer.cast(to, {:sendMessage,message})
  end


  def updateState(pid,sn,wn) do
    pairs = [sn,wn]
    GenServer.cast(pid,{:updateList,pairs,2})
  end

  def handle_cast({:updateList,elements,x},state) do
    [counter,curr_list,s,w] = state
    if x == 1 do
      #update list
      {:noreply,[counter,curr_list--[elements],s,w]}
    else if x == 0 do
      {:noreply,[counter,curr_list++elements,s,w]}
    else if x==2 do
      [a,b] = elements
      {:noreply,[counter,curr_list,a,b]}
    else if x==3 do
      {:noreply,[elements,curr_list,s,w]}
    end
    end

  end
end
end

#---------------------------Converge----------------------
  def converge(startTime) do
    [{_,currentCount}]=:ets.lookup(:counterTable,"counter")
    t = currentCount + 1
    :ets.insert(:counterTable,{"counter",t})
    [{_,num}] = :ets.lookup(:numTable, "num")
    [{_,topology}]=:ets.lookup(:numTable,"topology")

    #NOTE: Change/Reduce the p value if convergence takes more than 30000 ms to run on a n<1000
    p = cond do
      topology=="rand2D" ->0.8
      topology=="line"->0.3 # may also converge at 0.5 for higher order
      topology=="honeycomb"->0.8
      true->0.9
    end
    if(t>=trunc(num*p)) do
      endTime = System.monotonic_time(:millisecond)
      conTime = endTime - startTime
      IO.puts("Converged at #{conTime} ms")
      System.halt(1)
    end
  end

end
