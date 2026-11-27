%% SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
%%
%% SPDX-License-Identifier: MIT
%%
%% Wings 3D plugin: quad cage by decimation. Body mode > "Quad Cage": the selected objects go to an external tool
%% (default: WSL cagefit), which returns an all-quad cage whose Catmull-Clark limit surface stays within the hair's error
%% of the original. The cage comes back as a new object. Smooth (Catmull-Clark) in Wings shows the limit surface.
-module(wpc_cagefit).
-export([init/0, menu/2, command/2]).
-include_lib("wings/src/wings.hrl").
-include_lib("wings/e3d/e3d.hrl").

init() -> true.

menu({body}, Menu) -> Menu ++ [separator, {"Quad Cage", cagefit, "Replace by an all-quad cage within the hair's error"}];
menu(_, Menu) -> Menu.

command({body, cagefit}, St) -> run(St);
command(_, _) -> next.

%% Tool command: <tool> <in.obj> <out.obj> <hair mm>. Edit the preference "cagefit_tool" to change it.
run(St) ->
    Tool = wpa:pref_get(wpc_cagefit, tool, "wsl.exe -e /mnt/fire/3-interactor/wings-cage/bin/cagefit"),
    Tmp = filename:basename(os:cmd("echo %TEMP%") -- "\r\n"),
    In = filename:join(os:getenv("TEMP", "."), "cagefit_in.obj"),
    Out = filename:join(os:getenv("TEMP", "."), "cagefit_out.obj"),
    _ = Tmp,
    Exporter = fun(_Props, #e3d_file{}=E3d) -> e3d_obj:export(E3d, In, []) end,
    wpa:export_selected([{filename, In}], Exporter, St),
    Cmd = Tool ++ " " ++ q(In) ++ " " ++ q(Out) ++ " 0.1",
    Res = os:cmd(Cmd),
    case e3d_obj:import(Out) of
        {ok, E3dOut} -> wpa:import(E3dOut, St);
        {error, Why} -> wpa:error_msg("Quad Cage failed: ~p~n~s", [Why, Res])
    end.

q(S) -> [$"] ++ S ++ [$"].
