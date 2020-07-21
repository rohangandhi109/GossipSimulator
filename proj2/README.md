
##1. Team Members 

 Rohan Nitin Gandhi  1791-0958
 Deep Chetan Gosalia 5697-9299
 
##2. How to run the program:
mix run my_program.exs Numnodes topology algorithm

##3. What is Working

1. Full
2. Line
3. Random 2D
4. 3D torus
5. Honeycomb
6. Honeycomb with a random neighbor 

 All of these topologies are working for both Gossip and Push Sum algorithm.



##4. What is the largest network you managed to deal with for each type of topology and algorithm 

__________________| Gossip     | Push-Sum|   
Full              | 7000       |  6000   |
line              | 1000       |  300    |
Random2D          | 7000       |  2000   |
3Dtorus           | 10000      |  10000  |
Honeycomb         | 2000       |  600    |
Honeycomb         | 10000      |  10000  |
(random neighbor) |            |         |

If the code is executed for the higher range from the above mentioned then it run out of memory 
and it depends on the system.


