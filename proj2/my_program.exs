defmodule Topology do
  def start() do
    [temp,topology,algorithm] = System.argv()
    num_Nodes = String.to_integer(temp)
    numNodes = cond do
      topology == "honeycomb" -> round(:math.pow(round(:math.sqrt(num_Nodes)),2))
      topology == "randhoneycomb" -> round(:math.pow(round(:math.sqrt(num_Nodes)),2))
      topology == "3Dtorus" -> round(:math.pow(round(:math.pow(num_Nodes,1/3)),3))
      true ->num_Nodes
    end
    #IO.puts(numNodes)
    :ets.new(:numTable,[:set, :public, :named_table])
    :ets.new(:processTable, [:set, :public, :named_table])
    :ets.new(:counterTable, [:set, :public, :named_table])
    :ets.new(:trackTable,[:set, :public, :named_table])
    :ets.insert(:numTable,{"num",numNodes})
    :ets.insert(:numTable,{"topology",topology})

    Enum.each(1..numNodes, fn(x)->
      if algorithm == "push-sum" do
        Server.start_link(x)
      else
        GossipServer.start_link("",x)
      end
      :ets.insert(:trackTable, {"check",0})
      :ets.insert(:counterTable,{"counter",0})
    end)

    IO.puts("Building Topology...")
    _list=case topology do
      "full"->full(numNodes,algorithm)
      "line"->line(numNodes,algorithm)
      "rand2D"->rand_2d(numNodes,algorithm)
      "3Dtorus"->torus_3d(numNodes,algorithm)
      "honeycomb"->honeycomb(numNodes,algorithm)
      "randhoneycomb"->rand_honeycomb(numNodes,algorithm)
   end

    case algorithm do
       "gossip"-> execute(numNodes)
       "push-sum"->pushSum(numNodes)
        _->IO.puts("Invalid Input")
    end
  end

  def execute(numNodes) do
    IO.puts("Gossip started...")
    rand_node = Enum.random(1..numNodes)
    [{_,pid}] = :ets.lookup(:processTable, rand_node)
    message = "gossip"
    stime = System.os_time(:millisecond)

    GossipServer.sendGossip(message,pid,stime)

  end



  def pushSum(numNodes) do
    IO.puts("Push Sum started...")
    stime = System.monotonic_time(:millisecond)
    Enum.each(1..numNodes, fn(x)->
      [{_,pid}] = :ets.lookup(:processTable, x)
      Server.sendPushSum(0,0,pid,stime)
    end)
  end

  def full(numNodes,algorithm) do
    Enum.each(1..numNodes, fn(x)->
      list= Enum.filter(1..numNodes, fn(i) -> i !=x end)
      [{_,pid}] = :ets.lookup(:processTable, x)
      if algorithm == "push-sum" do
        Server.insertNeighbour(list,pid)
      else
        GossipServer.insertNeighbour(list,pid)
      end
    end)
  end

  def line(numNodes,algorithm) do
    Enum.each(1..numNodes, fn(x)->
      list = cond do
        x==1->[x+1]
        x==numNodes->[x-1]
        true->[x-1,x+1]
     end
      [{_,pid}] = :ets.lookup(:processTable, x)
      if algorithm == "push-sum" do
        Server.insertNeighbour(list,pid)
      else
        GossipServer.insertNeighbour(list,pid)
      end

    end)
  

  end

  def rand_2d(numNodes,algorithm) do
    x=Enum.reduce(1..numNodes, [], fn(_x,list) -> list ++ [:rand.uniform] end)
    y=Enum.reduce(1..numNodes, [], fn(_y,list) -> list ++ [:rand.uniform] end)
    Enum.each(1..numNodes, fn(i) ->
        list = Enum.filter(1..numNodes, fn(j) -> j == distance(i,j,x,y) end)
        [{_,pid}] = :ets.lookup(:processTable, i)
        if algorithm == "push-sum" do
          Server.insertNeighbour(list,pid)
        else
          GossipServer.insertNeighbour(list,pid)
        end

      end)
  end

  def torus_3d(numNodes,algorithm) do
    # add the nearest cube formula here
     #n = 10
     n = round(:math.pow(numNodes,1/3))
     #IO.puts(n)
     s = round(:math.pow(n,2))
     #IO.puts(s)
     layers= n-1
    for k<-0..layers do

     for i <- (k*s)+1..(k+1)*s do
      #IO.puts(i)
       list = cond do
         rem(i-1,s)==0 ->[i+1,i+(n-1),i+n,i+n*(n-1)] #1
         rem(i,s)==0 ->[i-1,i-n,i-(n-1),i-n*(n-1)] #2
         rem(i-n,s)==0 ->[i-1,i+n,i-(n-1),i+n*(n-1)] #3
         rem(i-n*(n-1)-1,s)==0 ->[i+1,i-n,i+(n-1),i-n*(n-1)] #4
         ((k*s + 1) < i) and i <(k*s)+n ->[i-1,i+1,i+n*(n-1),i+n] #5
         (((k*s)+1) <i) and i<(((k+1)*s)-(n-1)) and rem(i-1,n)==0->[i+1,i+n,i-n,i+(n-1)] #6
         (((k+1)*s) - (n-1) <i)and i<((k+1)*s) ->[i+1,i-1,i-(n)*(n-1),i-n] #7
         ((k*s)+n <i)and i<((k+1)*s) and rem(i,n)==0 ->[i-1,i-n,i+n,i-(n-1)] #8
         true -> [i+1,i-1,i-n,i+n] #9
       end



      list = cond do
         k==0 ->list++[i+layers*s,i+s]
          k==layers->list++[i-layers*s,i-s]
            true->list++[i+s,i-s]
       end

       [{_,pid}] = :ets.lookup(:processTable, i)
       #IO.puts(i)
       if algorithm == "push-sum" do
        Server.insertNeighbour(list,pid)
      else
        GossipServer.insertNeighbour(list,pid)
      end
       #IO.inspect(list)
     end
   end
   end
 #end

  def honeycomb(num_Nodes,algorithm) do
    numNodes = round(:math.pow(round(:math.sqrt(num_Nodes)),2))
    rowcnt = round(:math.sqrt(numNodes))
    for i <- 1..numNodes do
      list = cond do
        rem(rowcnt,2) == 0 -> even_hex(i,numNodes,rowcnt)
        rem(rowcnt,2) != 0 -> odd_hex(i,numNodes,rowcnt)
      end
      [{_,pid}] = :ets.lookup(:processTable, i)
      if algorithm == "push-sum" do
        #IO.puts(length(list))
        Server.insertNeighbour(list,pid)
      else
        GossipServer.insertNeighbour(list,pid)
      end
    end
  end





  def rand_honeycomb(num_Nodes,algorithm) do
    numNodes = round(:math.pow(round(:math.sqrt(num_Nodes)),2))
    rowcnt = round(:math.sqrt(numNodes))
    for i <- 1..numNodes do
      list = cond do
        rem(rowcnt,2) == 0 -> even_hex(i,numNodes,rowcnt) ++ [:rand.uniform(numNodes)]
        rem(rowcnt,2) != 0 -> odd_hex(i,numNodes,rowcnt) ++ [:rand.uniform(numNodes)]
      end
      [{_,pid}] = :ets.lookup(:processTable, i)
      if algorithm == "push-sum" do
        Server.insertNeighbour(list,pid)
      else

        GossipServer.insertNeighbour(list,pid)
      end
    end
  end

  def odd_hex(i,numNodes,rowcnt) do
    _list =  cond do
      i == 1 -> [i+1,i+rowcnt]
      i == rowcnt -> [i-1,i+rowcnt]
      i == numNodes - rowcnt + 1 -> [i+1,i-rowcnt]
      i == numNodes -> [i-rowcnt]
      i < rowcnt and rem(i,2) == 0 -> [i-1,i+rowcnt]     #1st row odd
      i < rowcnt and rem(i,2) != 0 -> [i+1,i+rowcnt]     #1st row odd
      i > numNodes - rowcnt + 1 and rem(rowcnt,2) != 0 and rem(i,2) == 0 -> [i-1,i-rowcnt]  #last row odd
      i > numNodes - rowcnt + 1 and rem(rowcnt,2) != 0 and rem(i,2) != 0 -> [i+1,i-rowcnt]  #last row odd
      rem(i-1,rowcnt) == 0 and rem(i,2) == 0 -> [i-rowcnt,i+rowcnt]             #1st col odd
      rem(i-1,rowcnt) == 0 and rem(i,2) != 0 -> [i+1,i-rowcnt,i+rowcnt]         #1st col odd
      rem(i,rowcnt) == 0 and rem(i,2) == 0 -> [i-1,i-rowcnt,i+rowcnt]           #last col odd
      rem(i,rowcnt) == 0 and rem(i,2) != 0 -> [i-rowcnt,i+rowcnt]               #last col odd
      rem(rowcnt,2) != 0 and rem(i,2) == 0 -> [i-1,i+rowcnt,i-rowcnt]           #odd
      rem(rowcnt,2) != 0 and rem(i,2) != 0 -> [i+1,i+rowcnt,i-rowcnt]           #odd
    end
  end

def even_hex(i,numNodes,rowcnt) do
  j = div(i,rowcnt)
  _list =  cond do
    i == 1 -> [i+1,i+rowcnt]
    i == rowcnt -> [i-1,i+rowcnt]
    i == numNodes - rowcnt + 1 -> [i-rowcnt]
    i == numNodes -> [i-rowcnt]
    i < rowcnt and rem(i,2) == 0 -> [i-1,i+rowcnt]     #1st row
    i < rowcnt and rem(i,2) != 0 -> [i+1,i+rowcnt]     #1st row
    i > numNodes - rowcnt + 1 and rem(i,2) == 0 -> [i+1,i-rowcnt]            #last row
    i > numNodes - rowcnt + 1 and rem(i,2) == 1 -> [i-1,i-rowcnt]            #last row
    rem(i-1,rowcnt) == 0 and rem(div(i-1,rowcnt),2) == 1 -> [i-rowcnt,i+rowcnt]             #1st col
    rem(i-1,rowcnt) == 0 and rem(div(i-1,rowcnt),2) == 0 -> [i+1,i-rowcnt,i+rowcnt]         #1st col
    rem(i,rowcnt) == 0 and rem(div(i,rowcnt),2) == 1  -> [i-1,i-rowcnt,i+rowcnt]           #last col odd
    rem(i,rowcnt) == 0 and rem(div(i,rowcnt),2) == 0  -> [i-rowcnt,i+rowcnt]               #last col odd
    rem(i-(i-(rowcnt * j)),rowcnt) == 0 and rem(i,2) == 0-> [i-1,i-rowcnt,i+rowcnt]        # if last row has a even multiple
    rem(i-(i-(rowcnt * j)),rowcnt) == 0 and rem(i,2) == 1-> [i+1,i-rowcnt,i+rowcnt]
    rem(i-(i-(rowcnt * j)),rowcnt) == 1 and rem(i,2) == 0-> [i+1,i-rowcnt,i+rowcnt]        #if last row has odd
    rem(i-(i-(rowcnt * j)),rowcnt) == 1 and rem(i,2) == 1-> [i-1,i-rowcnt,i+rowcnt]
  end
end
  def distance(i,j,x,y) do
    if i != j do
      x1=Enum.at(x,i-1)
      y1=Enum.at(y,i-1)
      x2=Enum.at(x,j-1)
      y2=Enum.at(y,j-1)
      d = :math.sqrt(((x2 - x1) * (x2 - x1)) + ((y2 - y1) * (y2 - y1)))
      if d < 0.1 do
          j
      end
  end
  end

end
Topology.start()

