-module(csp_reversible).

-export([run/1, run/2]).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Main interface
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

run(File) -> 
	run(File,'MAIN').

run(File, FirstProcess) -> 
	io:format("~s\n", [File]),
	OutputFile = 
		File ++ "_temp",
	csp_tracker:rewrite_renamings(File, OutputFile),
	AbsOutputFile = 
		filename:absname(OutputFile),
	OutputConversion = 
		os:cmd("cd csp_tracker;./createoutput.sh " ++ AbsOutputFile),
	io:format("~s\n",[OutputConversion]),
	csp_tracker:preprocess_variables("csp_tracker/"),
	case file:consult("csp_tracker/output_rewritten.txt") of
		{error,{_,_,InfoError}} ->
			io:format(
				"Error reading Erlang translation:\n~s\n",
				[lists:flatten(erl_parse:format_error(InfoError))]),
			io:format("Correct the syntax error before to proceed\n"),
			ok;
		{ok, ProcessList} ->
			case ProcessList of
			     [[]|_] -> 
			     	io:format("Correct the syntax error before to proceed\n"),
			     	ok;
			     [_|_] -> 
					file:write_file("track.dot", list_to_binary("digraph csp_track {\n}")),
					Processes = ets:new(processes,[bag]),
					csp_tracker:insert_processes(hd(ProcessList),Processes),
					ChannelInfo_ = csp_tracker:read_channels_info("csp_tracker/"),
					ChannelInfo = 
						[{Channel, csp_parsing:extract_type(Type)} 
						 || {Channel, Type} <- ChannelInfo_],
					csp_tracker:insert_processes(ChannelInfo, Processes),
					case lists:member(codeserver,registered()) of
					     true -> ok;
					     false -> 
					     	register(codeserver, spawn(codeserver,loop,[Processes]))
					end,
					case lists:member(printer,registered()) of
					     true -> ok;
					     false -> 
					     	register(printer, 
					         spawn(printer,loop,
					            [all, false]))
					end,					
					{{{N,E,S,_},_G,Trace}, DigraphContent} = 
						csp_process_interactive:start(FirstProcess),
					{NodesDigraph, EdgesDigraph} = DigraphContent,
					Digraph = csp_tracker:build_digraph(NodesDigraph, EdgesDigraph),
					csp_tracker:print_from_digraph(Digraph, "track", [], false),
					io:format("\n*********** Trace ************\n\n~s\n******************************\n",[Trace]),
					TrackStr = 
						io_lib:format("~p.\n~p.\n", [NodesDigraph, EdgesDigraph]),
					file:write_file("track.txt", list_to_binary(TrackStr)),
					% read_from_track(FirstProcess, Digraph),
					csp_process:send_message2regprocess(codeserver, stop),
					ok
			end
	end.


% read_from_track(FirstProcess, Track) ->
% 	case lists:member(printer,registered()) of
% 	     true -> ok;
% 	     false -> 
% 	     	register(printer, 
% 	        spawn(printer,loop,
% 	            [all, false]))
% 	end,
% 	{{_,_,Trace}, DigraphContent} = 
% 		csp_process_interactive:start_from_track(FirstProcess, Track),
% 	{NodesDigraph, EdgesDigraph} = 
% 		DigraphContent,
% 	Digraph = 
% 		csp_tracker:build_digraph(NodesDigraph, EdgesDigraph),
% 	csp_tracker:print_from_digraph(Digraph, "track_from_track", [], false),
% 	io:format("\n*********** Trace from track ************\n\n~s\n******************************\n",[Trace]),
% 	ReverseOptions = csp_process_interactive:reverse_options(Digraph),
% 	io:format("Reverse options: ~p\n", [ReverseOptions]),
% 	io:get_line(standard_io, "PRESS INTRO TO CONTINUE..."),
% 	case ReverseOptions of 
% 		[] ->
% 			ok;
% 		[H|_] ->
% 			csp_process_interactive:remove_from_track(H, Digraph),
% 			read_from_track(
% 				FirstProcess, 
% 				Digraph)
% 	end.


