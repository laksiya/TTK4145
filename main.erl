-module(main).

-export([start/1, start/2, read_sensor/2, connect/0, connect/1, check_ip_v4/1, get_local_ip/0]).
-export([broadcast_for_connection/2, listen_for_connection/1]).

-define(BROADCAST_PORT, 20013).
-define(LISTEN_PORT, 20014).
%-define(BROADCAST_PORT_A, 20015).
%-define(LISTEN_PORT_A, 20016).

start(Port) ->
  %Make node and broadcast
  ListenSocket = connect(),
  %Initialize Elevator
  {ok, ControlServerPid} = control_server:start(),
  register(control_server_pid, ControlServerPid),
  {ok, DriverPid} = elevator_interface:start({127,0,0,1}, Port),
  register(driver_pid, DriverPid),
  {ok, FSMElevatorPid} = fsm_elevator:start(),
  register(fsm_elevator_pid, FSMElevatorPid),
  spawn(main, read_sensor, [ready, self()]),
  buttons:buttons_init(),
  %Listening for other nodes
  listen_for_connection(ListenSocket).

start(Port, first) ->
  %Initialize Elevator
  {ok, ControlServerPid} = control_server:start(),
  register(control_server_pid, ControlServerPid),
  {ok, DriverPid} = elevator_interface:start({127,0,0,1}, Port),
  register(driver_pid, DriverPid),
  {ok, FSMElevatorPid} = fsm_elevator:start(),
  register(fsm_elevator_pid, FSMElevatorPid),
  spawn(main, read_sensor, [ready, self()]),
  buttons:buttons_init(),
  %Make node and listen
  connect(first).

connect()->
  %Initializes node
  os:cmd("epmd -daemon"),
  IPaddr = inet:ntoa(get_local_ip()),
  NodeName = list_to_atom("elevator@" ++ IPaddr),
  net_kernel:start([NodeName,longnames]),
  erlang:set_cookie(node(), test),
  %Open sockets for listening and broadcasting
  {ok, ListenSocket} = gen_udp:open(?LISTEN_PORT,[list,{active,false}]),
  {ok, SendSocket} = gen_udp:open(?BROADCAST_PORT, [list, {active,true}, {broadcast, true}]),
  broadcast_for_connection(SendSocket, ListenSocket).

connect(first)->
  io:format("1)In CONNECT FIRST"),
  os:cmd("epmd -daemon"),
  IPaddr = inet:ntoa(get_local_ip()),
  NodeName = list_to_atom("elevator@" ++ IPaddr),
  {NodePid,_Reason} = net_kernel:start([NodeName,longnames]),
  %Error handling fro first node initialization
  case NodePid of
    ok ->
      io:format("2) Net Kernel prop init :))"),
      erlang:set_cookie(node(), test),
      {ok, ListenSocket} = gen_udp:open(?LISTEN_PORT,[list,{active,false}]),
      %{ok, SendSocket} = gen_udp:open(?BROADCAST_PORT, [list, {active,true}, {broadcast, true}]),
      io:format("3) Listen for connection"),
      listen_for_connection(ListenSocket);
    _ ->
      io:format("2) Net Kernel INIT FAIL:(())")
    end.

%Gets private IP address
get_local_ip() ->
  {ok, Addrs} = inet:getifaddrs(),
  hd([Addr || {_, Opts} <- Addrs, {addr, Addr} <- Opts, size(Addr) == 4, check_ip_v4(Addr), Addr =/= {127,0,0,1}]).

%Checks its the IPV4 address which starts at 10
check_ip_v4({First, _, _, _})->
  case First of
    10 ->
      true;
    _ ->
      false
  end.

listen_for_connection(ListenSocket)->
  io:format("Im LISTENING \n"),
  {ok,{_NewNodeIP,_Sender,Node_name}} = gen_udp:recv(ListenSocket,0),
  io:format("New node noticed ~p from ~p ~n", [Node_name, node()]),
  NewNode = list_to_atom(Node_name),
  case node() of
    NewNode->
      listen_for_connection(ListenSocket);
    _->
    %%  NodeIPString = inet:ntoa(NewNodeIP),
    %%  NewNode = list_to_atom("elevator@" ++ NodeIPString),
    %%  io:format("New node ~p noticed from ~p~n", [NewNode, node()]),
      case net_kernel:connect_node(NewNode) of
        true->
          io:format("Done listening, NEW NODE IN CLUSTER\n");
        false->
          io:format("Done listening, ERROR\n");
        _->
          io:format("Node not alive!!! Ignored!\n")
        end
end.
  %monitor this IP

broadcast_for_connection(SendSocket, ListenSocket)->
  %io:format("Im BROADCASTING \n"),
   gen_udp:send(SendSocket,{255,255,255,255},?LISTEN_PORT,atom_to_list(node())),
   case nodes() of
     []->
       broadcast_for_connection(SendSocket, ListenSocket);
     _ ->
       ListenSocket
     end.

read_sensor(ready, Pid) ->
  timer:sleep(20),
  case elevator_interface:get_floor_sensor_state(whereis(driver_pid)) of
    between_floors ->
      read_sensor(ready, Pid);
    NewFloor ->
      fsm_elevator:set_current(NewFloor),
      %Pid ! NewFloor,
      %io:format("~p~n", [NewFloor]),
      read_sensor(wait, Pid)
  end;
read_sensor(wait, Pid) ->
  timer:sleep(20),
  case elevator_interface:get_floor_sensor_state(whereis(driver_pid)) of
    between_floors ->
      read_sensor(ready, Pid);
    _CurrFloor ->
      read_sensor(wait, Pid)
end.
