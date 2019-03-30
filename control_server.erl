-module(control_server).

-behaviour(gen_server).

-export([start/0, start_link/0, send_order/1, send_order/2, order_finished/1, order_finished/2, kill/0]).
-export([init/1, handle_cast/2, terminate/2]).
-export([print_list/1, extract_tuple/1]).

%% API

start() ->
    gen_server:start(?MODULE, [], []).

start_link() ->
    gen_server:start_link([]).

send_order(Floor, Type) ->
    gen_server:cast(whereis(control_server_pid), {add_local_order, Floor, Type}).
send_order(Order) ->
    gen_server:cast(whereis(control_server_pid), {add_remote_order, Order}).

order_finished(Ref) ->
    gen_server:cast(whereis(control_server_pid), {order_finished, Ref}).
order_finished(remote, Ref) ->
    gen_server:cast(whereis(control_server_pid), {order_finished_remote, Ref}).

kill() ->
    gen_server:cast(whereis(control_server_pid), terminate).

%& Callback functions

init([]) ->
    {ok, []}.


handle_cast({add_local_order, Floor, cab}, GQueue) ->
  case cab_already_ordered(Floor, GQueue) of
    true ->
      {noreply, GQueue};
    false ->
      Ref=make_ref(),
      broadcast:call_global_order({node(), Ref, {Floor, cab}}, nodes()),
      fsm_elevator:set_goal({Ref, {Floor, cab}}),
      elevator_interface:set_order_button_light(whereis(driver_pid), cab, Floor, on),
      {noreply, [{node(), Ref, {Floor, cab}}|GQueue]}
  end;

handle_cast({add_local_order, Floor, Type}, GQueue) ->
    case lists:keymember({Floor, Type}, 3, GQueue) of
      true ->
        {noreply, GQueue};
      false ->
        Ref=make_ref(),

      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%      {NodesAvailabe, RemoteStates} = broadcast:get_all_states(),
%      AllStates=[fsm_elevator:get_state()|RemoteStates],
%      SelectedElevator = select_elevator(AllStates, Floor, Type),
%      io:format("Elevator: ~p~n", SelectedElevator),
%      broadcast:call_global_order({SelectedElevator, Ref, {Floor, Type}}, NodesAvailabe),
%      case broadcast:call_global_order({SelectedElevator, Ref, {Floor, Type}}, NodesAvailabe) of
%        true ->
%          send_order_until_success(Ref, Floor, Type);
%        false ->
%          SelectedElevator
%      end.
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        SelectedElevator = send_order_until_success(Ref, Floor, Type),
        io:format("Assigned elevator ~p to order ~p~n",[SelectedElevator, Ref]),
        if SelectedElevator =:= node() ->
            fsm_elevator:set_goal({Ref, {Floor, Type}})
        end,
        elevator_interface:set_order_button_light(whereis(driver_pid), Type, Floor, on),
        {noreply, [{SelectedElevator, Ref, {Floor, Type}}|GQueue]}
    end;

handle_cast({add_remote_order, {Elevator, Ref, {Floor, Type}}}, GQueue) ->
    case lists:keymember(Ref, 2, GQueue) of
      true ->
        lists:delete({Elevator, Ref, {Floor, Type}}, GQueue),
        if Elevator =:= node() ->
          fsm_elevator:set_goal({Ref, {Floor, Type}})
        end,
        {noreply, [{Elevator, Ref, {Floor, Type}}|GQueue]};
      _ ->
        case Type of
            cab ->
                {noreply, [{Elevator, Ref, {Floor, Type}}|GQueue]};
            _ ->
                elevator_interface:set_order_button_light(whereis(driver_pid), Type, Floor, on),
                {noreply, [{Elevator, Ref, {Floor, Type}}|GQueue]}
        end
    end;
%  elevator_interface:set_order_button_light(whereis(driver_pid), Type, Floor, on),
%  {noreply, [{Elevator, Ref, {Floor, Type}}|GQueue]};

handle_cast({order_finished, RefDone}, GQueue) ->
    {value, {_Elevator, Ref, {Floor, Type}}} = lists:keysearch(RefDone, 2, GQueue),
    broadcast:delete_global_order(Ref),
    elevator_interface:set_order_button_light(whereis(driver_pid), Type, Floor, off),
    {noreply, lists:keydelete(Ref, 2, GQueue)};
handle_cast({order_finished_remote, RefDone}, GQueue) ->
    {value, {_Elevator, Ref, {Floor, Type}}} = lists:keysearch(RefDone, 2, GQueue),
    elevator_interface:set_order_button_light(whereis(driver_pid), Type, Floor, off),
    {noreply, lists:keydelete(Ref, 2, GQueue)};

handle_cast(terminate, GQueue) ->
    {stop, normal, GQueue}.

terminate(normal, GQueue) ->
    io:format("Could not finish~n"),
    %Send orders from local FSM??
    print_list(GQueue),
    ok.


%% Private functions

print_list([]) -> ok;
print_list([{Ref, {_Type, _Floor}}|T]) ->
    io:format("Order : ~p~n", [Ref]),
    print_list(T).

cab_already_ordered(Floor, GQueue) ->
  case lists:keyfind({Floor, cab}, 3, GQueue) of
    {Node, NRef, {NFloor, NType}} ->
      if Node =:= node() ->
        true;
      true ->
        cab_already_ordered(Floor, lists:delete({Node, NRef, {NFloor, NType}}, GQueue))
      end;
    false ->
      false
  end.

extract_tuple({Node,{State,Floor,Type}})->
{Node, State,Floor,Type}.

select_elevator([H|T], _Floor, Type) ->
  case Type of
    cab ->
      node();
    _ ->
      case lists:keysearch(idle, 2, [H|T]) of
        {value, {Node, _NState, _NFloor, _NDirection}} ->
          Node;
        false->
          node()
      end
  end.


send_order_until_success(Ref, Floor, Type) ->
  {NodesAvailabe, RemoteStates} = broadcast:get_all_states(),
  AllStates=[fsm_elevator:get_state()|RemoteStates],
  SelectedElevator = select_elevator(AllStates, Floor, Type),
  %io:format("Elevator: ~p~n", SelectedElevator),
  case broadcast:call_global_order({SelectedElevator, Ref, {Floor, Type}}, NodesAvailabe) of
    true ->
      send_order_until_success(Ref, Floor, Type);
    false ->
      SelectedElevator
  end.
