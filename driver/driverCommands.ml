(* Copyright 2001, 2002 b8_bavard, b8_fee_carabine, INRIA *)
(*
    This file is part of mldonkey.

    mldonkey is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    mldonkey is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with mldonkey; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*)

open Printf2
open Md4
open CommonMessages
open CommonGlobals
open CommonShared
open CommonSearch
open CommonClient
open CommonServer
open CommonNetwork
open GuiTypes
open CommonTypes
open CommonFile
open CommonComplexOptions
open Options
open BasicSocket
open TcpBufferedSocket
open DriverInteractive
open CommonOptions
open CommonInteractive
open Md4
  
let execute_command arg_list output cmd args =
  let buf = output.conn_buf in
  try
    let rec iter list =
      match list with
        [] -> 
          Gettext.buftext buf no_such_command cmd
      | (command, arg_kind, help) :: tail ->
          if command = cmd then
            Buffer.add_string buf (
              match arg_kind, args with
                Arg_none f, [] -> f output
              | Arg_multiple f, _ -> f args output
              | Arg_one f, [arg] -> f arg  output
              | Arg_two f, [a1;a2] -> f a1 a2 output
              | Arg_three f, [a1;a2;a3] -> f a1 a2 a3 output
              | _ -> !!bad_number_of_args
            )
          else
            iter tail
    in
    iter arg_list
  with Not_found -> ()


let list_options_html o list = 
  let buf = o.conn_buf in
  if o.conn_output = HTML then
    Printf.bprintf  buf "\\<div class=\\\"vo\\\"\\>\\<table class=vo cellspacing=0 cellpadding=0\\>
\\<tr\\>
\\<td onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>Name (Mouseover=Help)\\</td\\>
\\<td onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>Value\\</td\\>
\\<td onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>Default\\</td\\>
\\</tr\\>
";
  
  let counter = ref 0 in
  
  List.iter (fun (name, value, def, help) ->
      incr counter;
      if (!counter mod 2 == 0) then Printf.bprintf buf "\\<tr class=\\\"dl-1\\\"\\>"
      else Printf.bprintf buf "\\<tr class=\\\"dl-2\\\"\\>";
      
      if String.contains value '\n' then 
        Printf.bprintf buf "
                  \\<td title=\\\"%s\\\" class=\\\"sr\\\"\\>%s\\<form action=/submit target=\\\"$S\\\"\\> 
                  \\<input type=hidden name=setoption value=q\\>
                  \\<input type=hidden name=option value=%s\\>\\</td\\>\\<td\\>\\<textarea 
					name=value rows=5 cols=20 wrap=virtual\\> 
                  %s   
                  \\</textarea\\>\\<input type=submit value=Modify\\>
                  \\</td\\>\\<td class=\\\"sr\\\"\\>%s\\</td\\>\\</tr\\>
                  \\</form\\>
                  " help name name value def
      
      else  
        
        begin
          
          Printf.bprintf buf "
              \\<td title=\\\"%s\\\" class=\\\"sr\\\"\\>%s\\</td\\>
		      \\<td class=\\\"sr\\\"\\>\\<form action=/submit target=\\\"$S\\\"\\>\\<input type=hidden 
				name=setoption value=q\\>\\<input type=hidden name=option value=%s\\>"  help name name;
          
          if value = "true" || value = "false" then 
            
            Printf.bprintf buf "\\<select style=\\\"font-family: verdana; font-size: 10px;\\\"
									name=\\\"value\\\" onchange=\\\"this.form.submit()\\\"\\>
									\\<option selected\\>%s\\<option\\>%s\\</select\\>"
              value 
              (if value="true" then "false" else "true")
          else
            
            Printf.bprintf buf "\\<input style=\\\"font-family: verdana; font-size: 10px;\\\" 
				type=text name=value size=20 value=\\\"%s\\\"\\>"
              value;
          
          Printf.bprintf buf "
              \\</td\\>
              \\<td class=\\\"sr\\\"\\>%s\\</td\\>
			  \\</tr\\>\\</form\\>
              " def
        end;
      
      
  )list;
  if o.conn_output = HTML then
    Printf.bprintf  buf "\\</table\\>\\</div\\>"


let list_options o list = 
  let buf = o.conn_buf in
  if o.conn_output = HTML then
    Printf.bprintf  buf "\\<table border=0\\>";
  List.iter (fun (name, value) ->
      if String.contains value '\n' then begin
          if o.conn_output = HTML then
            Printf.bprintf buf "
                  \\<tr\\>\\<td\\>\\<form action=/submit $S\\> 
                  \\<input type=hidden name=setoption value=q\\>
                  \\<input type=hidden name=option value=%s\\> %s \\</td\\>\\<td\\>
                  \\<textarea name=value rows=10 cols=70 wrap=virtual\\> 
                  %s
                  \\</textarea\\>
                  \\<input type=submit value=Modify\\>
                  \\</td\\>\\</tr\\>
                  \\</form\\>
                  " name name value
        end
      else
      if o.conn_output = HTML then
        Printf.bprintf buf "
              \\<tr\\>\\<td\\>\\<form action=/submit $S\\> 
\\<input type=hidden name=setoption value=q\\>
\\<input type=hidden name=option value=%s\\> %s \\</td\\>\\<td\\>
              \\<input type=text name=value size=40 value=\\\"%s\\\"\\>
\\</td\\>\\</tr\\>
\\</form\\>
              " name name value
      else
        Printf.bprintf buf "%s = %s\n" name value)
  list;
  if o.conn_output = HTML then
    Printf.bprintf  buf "\\</table\\>"
  
let commands = [

(*
    "dump_heap", Arg_none (fun o ->
        Heap.print_memstats ();
        "heap dumped"
    ), ":\t\t\t\tdump heap for debug";
    
    "dump_usage", Arg_none (fun o ->
        Heap.dump_usage ();
        "usage dumped"
    ), ":\t\t\t\tdump main structures for debug";
*)
    
    "close_fds", Arg_none (fun o ->
        Unix32.close_all ();
        "All files closed"
    ), ":\t\t\t\tclose all files (use to free space on disk after remove)";
    
    "commit", Arg_none (fun o ->
        List.iter (fun file ->
            file_commit file
        ) !!done_files;
        "Commited"
    ) , ":\t\t\t\tmove downloaded files to incoming directory";
    
    "vd", Arg_multiple (fun args o -> 
        let buf = o.conn_buf in
        match args with
          [arg] ->
            let num = int_of_string arg in
            if o.conn_output = HTML then
              begin
                Printf.bprintf  buf "\\<a href=/files\\>Display all files\\</a\\>  ";
                Printf.bprintf  buf "\\<a href=/submit?q=verify_chunks+%d\\>Verify Chunks\\</a\\>  " num;
                if !!html_mods then
                  Printf.bprintf  buf "\\<a href=\\\"javascript:window.location.reload()\\\"\\>Reload\\</a\\>\\<br\\>\n";
              end;
            List.iter 
              (fun file -> if (as_file_impl file).impl_file_num = num then 
                  CommonFile.file_print file o)
            !!files;
            List.iter
              (fun file -> if (as_file_impl file).impl_file_num = num then 
                  CommonFile.file_print file o)
            !!done_files;
            ""
        | _ ->
            DriverInteractive.display_file_list buf o;
            ""    
    ), "<num> :\t\t\t\tview file info";
    
    "downloaders", Arg_none (fun o ->
        let buf = o.conn_buf in
        
        if o.conn_output = HTML && !!html_mods then 
          Printf.bprintf buf "\\<div class=\\\"downloaders\\\"\\>\\<table id=\\\"downloaders\\\" name=\\\"downloaders\\\" 
							class=\\\"downloaders\\\" cellspacing=0 cellpadding=0\\>\\<tr\\>
\\<td title=\\\"Client Number (Click to Add as Friend)\\\" onClick=\\\"_tabSort(this,1);\\\" class=\\\"srh ac\\\"\\>Num\\</td\\>
\\<td title=\\\"Client state\\\" onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>CS\\</td\\>
\\<td title=\\\"Client name\\\" onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>Name\\</td\\>
\\<td title=\\\"Client brand\\\" onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>CB\\</td\\>
\\<td title=\\\"Overnet [T]rue, [F]alse\\\"onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>O\\</td\\>
\\<td title=\\\"Connected time (minutes)\\\"onClick=\\\"_tabSort(this,1);\\\" class=\\\"srh ar\\\"\\>CT\\</td\\>
\\<td title=\\\"Connection [I]nDirect, [D]irect\\\" onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>C\\</td\\>
\\<td title=\\\"IP Address\\\" onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>IP\\</td\\>
\\<td title=\\\"Total UL Kbytes to this client for all files\\\" onClick=\\\"_tabSort(this,1);\\\" class=\\\"srh ar\\\"\\>UL\\</td\\>
\\<td title=\\\"Total DL Kbytes from this client for all files\\\" onClick=\\\"_tabSort(this,1);\\\" class=\\\"srh ar\\\"\\>DL\\</td\\>
\\<td title=\\\"Filename\\\" onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>Filename\\</td\\>
\\</tr\\>";
        
        let counter = ref 0 in
        
        List.iter 
          (fun file -> 
            if (CommonFile.file_downloaders file o !counter) then counter := 0 else counter := 1;
        ) !!files;
        
        if o.conn_output = HTML && !!html_mods then Printf.bprintf buf "\\</table\\>\\</div\\>";
        
        ""
    ) , ":\t\t\t\tdisplay downloaders list";
    
    "verify_chunks", Arg_multiple (fun args o -> 
        let buf = o.conn_buf in
        match args with
          [arg] ->
            let num = int_of_string arg in
            if o.conn_output = HTML then
              List.iter 
                (fun file -> if (as_file_impl file).impl_file_num = num then 
                    begin
                      Printf.bprintf  buf "Verifying Chunks of file %d" num;
                      file_check file; 
                    end
              )
              !!files;
            ""
        | _ -> ();
            "done"    
    ), "<num> :\t\t\tverify chunks of file <num>";
    
    
    "vm", Arg_none (fun o ->
        CommonInteractive.print_connected_servers o;
        ""), ":\t\t\t\t\tlist connected servers";
    
    "q", Arg_none (fun o ->
        raise CommonTypes.CommandCloseSocket
    ), ":\t\t\t\t\tclose telnet";
    
    "debug_socks", Arg_none (fun o ->
        BasicSocket.print_sockets o.conn_buf;
        "done"), ":\t\t\t\tfor debugging only";
    
    "kill", Arg_none (fun o ->
        CommonGlobals.exit_properly 0;
        "exit"), ":\t\t\t\t\tsave and kill the server";
    
    "save", Arg_none (fun o ->
        DriverInteractive.save_config ();
        "saved"), ":\t\t\t\t\tsave";
    
    "vo", Arg_none (fun o ->
        let buf = o.conn_buf in
        if o.conn_output = HTML && !!html_mods then 
          list_options_html o  (
            [
              strings_of_option_html  max_hard_upload_rate; 
              strings_of_option_html max_hard_download_rate;
              strings_of_option_html telnet_port; 
              strings_of_option_html gui_port; 
              strings_of_option_html http_port;
              strings_of_option_html client_name;
              strings_of_option_html allowed_ips;
              strings_of_option_html set_client_ip; 
              strings_of_option_html force_client_ip; 
            ] )
        else
          list_options o  (
            [
              strings_of_option  max_hard_upload_rate; 
              strings_of_option max_hard_download_rate;
              strings_of_option telnet_port; 
              strings_of_option gui_port; 
              strings_of_option http_port;
              strings_of_option client_name;
              strings_of_option allowed_ips;
              strings_of_option set_client_ip; 
              strings_of_option force_client_ip; 
            ]
          );        
        
        if o.conn_output = HTML then 
          Printf.bprintf buf "\\<br\\>\\<a href=\\\"javascript:window.location.href='/submit?q=html_mods'\\\"\\>[ Toggle html_mods ]\\</a\\>\n\n";
        
        
        if o.conn_output = HTML && !!html_mods then 
          Printf.bprintf buf "\\<br\\>\\<a href=\\\"javascript:window.location.href='/submit?q=voo'\\\"\\>[ Edit Full Options ]\\</a\\>\n\n";
        
        "\nUse 'voo' for all options"    
    ), ":\t\t\t\t\tdisplay options";
    
    "html_mods", Arg_none (fun o ->
        let buf = o.conn_buf in
        
        if !!html_mods then 
          begin
            Options.set_simple_option downloads_ini "html_mods" "false";
            Options.set_simple_option downloads_ini "commands_frame_height" "140"
          end
        else
          begin 
            Options.set_simple_option downloads_ini "html_mods" "true";
            Options.set_simple_option downloads_ini "commands_frame_height" "80";
            Options.set_simple_option downloads_ini "use_html_frames" "true"
          
          end;
        
        "\\<script language=Javascript\\>top.window.location.reload();\\</script\\>"
    ), ":\t\t\t\ttoggle html_mods";
    
    "voo", Arg_none (fun o ->
        let buf = o.conn_buf in
        if !!html_mods && o.conn_output = HTML then list_options_html o (CommonInteractive.all_simple_options_html ())
        else list_options o  (CommonInteractive.all_simple_options ());
        
        ""
    ), ":\t\t\t\t\tprint options";
    
    "options", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
        match args with
          [] ->
            let sections = ref [] in
            Printf.bprintf buf "Available sections for options: \n";
            List.iter (fun  (section, message, option, optype) ->
                if not (List.mem section !sections) then begin
                    Printf.bprintf buf "  %s\n" section;
                    sections := section :: !sections
                  end
            ) !! gui_options_panel;
            
            List.iter (fun (section, list) ->
                if not (List.mem section !sections) then begin
                    Printf.bprintf buf "  %s\n" section;
                    sections := section :: !sections
                  end)
            ! CommonInteractive.gui_options_panels;
            "\n\nUse 'options section' to see options in this section"
        
        | sections -> 
            List.iter (fun s ->
                Printf.bprintf buf "Options in section %s:\n" s;
                List.iter (fun (section, message, option, optype) ->
                    if s = section then
                      Printf.bprintf buf "  %s [%s]= %s\n" 
                        message option 
                        (get_fully_qualified_options option)
                ) !! gui_options_panel;
                
                List.iter (fun (section, list) ->
                    if s = section then                    
                      List.iter (fun (message, option, optype) ->
                          Printf.bprintf buf "  %s [%s]= %s\n" 
                            message option 
                            (get_fully_qualified_options option)
                      ) !!list)
                ! CommonInteractive.gui_options_panels;
            
            ) sections;
            "\nUse 'set option \"value\"' to change a value where options is
the name between []"
    ), " :\t\t\tprint options values by section";
    
    "upstats", Arg_none (fun o ->
        let buf = o.conn_buf in
        
        if o.conn_output = HTML && !!html_mods then Printf.bprintf buf "\\<div class=\\\"upstats\\\"\\>"
        else Printf.bprintf buf "Upload statistics:\n";
        Printf.bprintf buf "Total: %s uploaded\n" 
          (size_of_int64 !upload_counter);
        
        let list = ref [] in
        shared_iter (fun s ->
            let impl = as_shared_impl s in
            list := impl :: !list
        );
        
        
        if o.conn_output = HTML && !!html_mods then 
          Printf.bprintf buf "\\<table class=\\\"upstats\\\" cellspacing=0 cellpadding=0\\>\\<tr\\>
\\<td onClick=\\\"_tabSort(this,1);\\\" class=\\\"srh\\\"\\>Reqs\\</td\\>
\\<td onClick=\\\"_tabSort(this,1);\\\" class=\\\"srh\\\"\\>Total\\</td\\>
\\<td onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>File\\</td\\>
\\</tr\\>";
        
        let counter = ref 0 in 
        
        
        let list = Sort.list (fun f1 f2 ->
              (f1.impl_shared_requests = f2.impl_shared_requests &&
                f1.impl_shared_uploaded > f2.impl_shared_uploaded) ||
              (f1.impl_shared_requests > f2.impl_shared_requests )
          ) !list in
        
        
        
        List.iter (fun impl ->
            if use_html_mods o then
              begin
                incr counter;
                
                let ed2k = Printf.sprintf "ed2k://|file|%s|%s|%s|/" 
                    impl.impl_shared_codedname 
                    (Int64.to_string impl.impl_shared_size)
                  (Md4.to_string impl.impl_shared_id) in
                
                Printf.bprintf buf "\\<tr class=\\\"%s\\\"\\>"
                  (if (!counter mod 2 == 0) then "dl-1" else "dl-2";);
                
                Printf.bprintf buf "\\<td class=\\\"sr ar\\\"\\>%d\\</td\\>\\<td
             	class=\\\"sr ar\\\"\\>%s\\</td\\>\\<td class=\\\"sr\\\"\\>\\<A HREF=\\\"%s\\\"\\>%s\\</A\\>
 				\\</td\\>\\</tr\\>\n"
                  impl.impl_shared_requests
                  (size_of_int64 impl.impl_shared_uploaded)
                ed2k
                  impl.impl_shared_codedname;
              
              end
            else
(*
        List.iter (fun impl ->
            if use_html_mods o then
              begin
                let info = impl_shared_info impl in
                incr counter;
                if (!counter mod 2 == 0) then Printf.bprintf buf "\\<tr class=\\\"dl-1\\\"\\>"
                else Printf.bprintf buf "\\<tr class=\\\"dl-2\\\"\\>";
                
                Printf.bprintf buf "\\<td class=\\\"sr ar\\\"\\>%d\\</td\\>\\<td
            class=\\\"sr ar\\\"\\>%s\\</td\\>\\<td class=\\\"sr\\\"\\>\\<a href=\\\"ed2k://|file|%s|%s|%s|/\\\"\\>%s\\</a\\>\\</td\\>\\</tr\\>\n"
                  impl.impl_shared_requests
                  (size_of_int64 impl.impl_shared_uploaded)
                (impl.impl_shared_codedname)
                (Int64.to_string impl.impl_shared_size)
                (Md4.to_string info.shared_id)
                impl.impl_shared_codedname ;
              
              end 
              else *)
              Printf.bprintf buf "%-50s requests: %8d bytes: %10s\n"
                impl.impl_shared_codedname impl.impl_shared_requests
                (Int64.to_string impl.impl_shared_uploaded);
        ) list;
        
        if o.conn_output = HTML && !!html_mods then Printf.bprintf buf "\\</table\\>\\</div\\>";
        
        
        "done"
    ), ":\t\t\t\tstatistics on upload";
    
    "set", Arg_two (fun name value o ->
        try
          try
            let buf = o.conn_buf in
            CommonInteractive.set_fully_qualified_options name value;
            Printf.sprintf "option %s value changed" name

(*
            let pos = String.index name '-' in
            let prefix = String.sub name 0 pos in
            let name = String.sub name (pos+1) (String.length name - pos-1) in
            networks_iter (fun n ->
                match n.network_config_file with
                  None -> ()
                | Some opfile ->
                    List.iter (fun p ->
                        if p = prefix then begin
                            set_simple_option opfile name value;
                            Printf.bprintf buf "option %s :: %s value changed" 
                            n.network_name name
                            
                          end)
                    n.network_prefixes      
);
  *)
          with _ -> 
              Options.set_simple_option downloads_ini name value;
              Printf.sprintf "option %s value changed" name
        with e ->
            Printf.sprintf "Error %s" (Printexc2.to_string e)
    ), "<option_name> <option_value> :\tchange option value";
    
    "vr", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
        match args with
          num :: _ -> 
            List.iter (fun num ->
                let num = int_of_string num in
                let s = search_find num in
                DriverInteractive.print_search buf s o) args;
            ""
        | [] ->   
            begin
              match !searches with
                [] -> "No search to print"
              | s :: _ ->
                  DriverInteractive.print_search buf s o;
                  ""
            end;
    ), "[<num>] :\t\t\t\tview results of a search";
    
    "vr", Arg_none (fun o ->
        "done"
    ), ":\t\t\t\t\tprint last Common search results";
    
    "s", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
        let query = CommonSearch.search_of_args args in
        ignore (CommonInteractive.start_search 
            (let module G = GuiTypes in
            { G.search_num = 0;
              G.search_query = query;
              G.search_max_hits = 10000;
              G.search_type = RemoteSearch;
            }) buf);
        ""
    ), "<query> :\t\t\t\tsearch for files on all networks\n
\tWith special args:
\t-minsize <size>
\t-maxsize <size>
\t-media <Video|Audio|...>
\t-Video
\t-Audio
\t-format <format>
\t-title <word in title>
\t-album <word in album>
\t-artist <word in artist>
\t-field <field> <fieldvalue>
\t-not <word>
\t-and <word> 
\t-or <word>

";
    
    "ls", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
        let query = CommonSearch.search_of_args args in
        ignore (CommonInteractive.start_search 
            (let module G = GuiTypes in
            { G.search_num = 0;
              G.search_query = query;
              G.search_max_hits = 10000;
              G.search_type = LocalSearch;
            }) buf);
        ""
    ), "<query> :\t\t\t\tsearch for files on all networks\n
\tWith special args:
\t-minsize <size>
\t-maxsize <size>
\t-media <Video|Audio|...>
\t-Video
\t-Audio
\t-format <format>
\t-title <word in title>
\t-album <word in album>
\t-artist <word in artist>
\t-field <field> <fieldvalue>
\t-not <word>
\t-and <word> 
\t-or <word>

";
    
    "d", Arg_multiple (fun args o ->
        List.iter (fun arg ->
            CommonInteractive.download_file o.conn_buf arg) args;
        ""),
    "<num> :\t\t\t\tfile to download";
    
    "force_download", Arg_none (fun o ->
        let buf = o.conn_buf in
        match !CommonGlobals.aborted_download with
          None -> "No download to force"
        | Some r ->
            CommonResult.result_download (CommonResult.result_find r) [] true;
            "download forced"
    ), ":\t\t\tforce download of an already downloaded file";
    
    "vs", Arg_none (fun o ->
        let buf = o.conn_buf in
        Printf.bprintf  buf "Searching %d queries\n" (
          List.length !searches);
        List.iter (fun s ->
            Printf.bprintf buf "%s[%-5d]%s %s %s\n" 
              (if o.conn_output = HTML then 
                Printf.sprintf "\\<a href=/submit\\?q=vr\\+%d\\>" s.search_num
              else "")
            s.search_num 
              (if o.conn_output = HTML then "\\</a\\>" else "")
            s.search_string
              (if s.search_waiting = 0 then "done" else
                string_of_int s.search_waiting)
        ) !searches; ""), ":\t\t\t\t\tview all queries";
    
    "view_custom_queries", Arg_none (fun o ->
        let buf = o.conn_buf in
        if o.conn_output <> HTML then
          Printf.bprintf buf "%d custom queries defined\n" 
            (List.length !!customized_queries);
        List.iter (fun (name, q) ->
            if o.conn_output = HTML then
              begin        
                
                if o.conn_output = HTML && !!html_mods then  
                  Printf.bprintf buf 
                    "\\<a href=/submit\\?custom=%s target=\\\"$O\\\"\\> %s \\</a\\>  " 
                    (Url.encode name) name
                
                else
                  Printf.bprintf buf 
                    "\\<a href=/submit\\?custom=%s $O\\> %s \\</a\\>\n" 
                    (Url.encode name) name;
              end
            else
              
              Printf.bprintf buf "[%s]\n" name
        ) !! customized_queries; 
        
        if o.conn_output = HTML && !!html_mods then  
          Printf.bprintf buf 
            "\\<a href=\\\"http://www.jigle.com\\\" target=\\\"$O\\\"\\>Jigle\\</a\\>  \\<a 
					href=\\\"http://www.sharereactor.com/search.php\\\" target=\\\"$O\\\"\\>ShareReactor\\</a\\>  \\<a 
					href=\\\"http://www.filedonkey.com\\\" target=\\\"$O\\\"\\>File Donkey\\</a\\>  ";
        
        ""
    ), ":\t\t\tview custom queries";
    
    "cancel", Arg_multiple (fun args o ->
        if args = ["all"] then
          List.iter (fun file ->
              file_cancel file
          ) !!files
        else
          List.iter (fun num ->
              let num = int_of_string num in
              List.iter (fun file ->
                  if (as_file_impl file).impl_file_num = num then begin
                      lprintf "TRY TO CANCEL FILE"; lprint_newline ();
                      file_cancel file
                    end
              ) !!files) args; 
        ""
    ), "<num> :\t\t\t\tcancel download (use arg 'all' for all files)";
    
    "shares", Arg_none (fun o ->
        
        let buf = o.conn_buf in
        Printf.bprintf buf "Shared directories:\n";
        Printf.bprintf buf "  %s\n" !!incoming_directory;
        List.iter (fun dir -> Printf.bprintf buf "  %s\n" dir)
        !!shared_directories;
        ""
    ), ":\t\t\t\tprint shared directories";
    
    "share", Arg_one (fun arg o ->
        
        if Unix2.is_directory arg then
          if not (List.mem arg !!shared_directories) then begin
              shared_directories =:= arg :: !!shared_directories;
              shared_add_directory arg;
              "directory added"
            end else
            "directory already shared"
        else
          "no such directory"
    ), "<dir> :\t\t\t\tshare directory <dir>";
    
    "unshare", Arg_one (fun arg o ->
        if List.mem arg !!shared_directories then begin
            shared_directories =:= List2.remove arg !!shared_directories;
            CommonShared.shared_check_files ();
            "directory removed"
          end else
          "directory already unshared"
    
    ), "<dir> :\t\t\t\tshare directory <dir>";
    
    "pause", Arg_multiple (fun args o ->
        if args = ["all"] then
          List.iter (fun file ->
              file_pause file;
          ) !!files
        else
          List.iter (fun num ->
              let num = int_of_string num in
              List.iter (fun file ->
                  if (as_file_impl file).impl_file_num = num then begin
                      file_pause file
                    end
              ) !!files) args; ""
    ), "<num> :\t\t\t\tpause a download (use arg 'all' for all files)";
    
    "resume", Arg_multiple (fun args o ->
        if args = ["all"] then
          List.iter (fun file ->
              file_resume file
          ) !!files
        else
          List.iter (fun num ->
              let num = int_of_string num in
              List.iter (fun file ->
                  if (as_file_impl file).impl_file_num = num then begin
                      file_resume file
                    end
              ) !!files) args; ""
    ), "<num> :\t\t\t\tresume a paused download (use arg 'all' for all files)";
    
    "c", Arg_multiple (fun args o ->
        match args with
          [] ->
            networks_iter network_connect_servers;
            "connecting more servers"
        | _ ->
            List.iter (fun num ->
                let num = int_of_string num in
                let s = server_find num in
                server_connect s
            ) args;
            "connecting server"
    ),
    "[<num>] :\t\t\t\tconnect to more servers (or to server <num>)";
    
    "vc", Arg_one (fun num o ->
        let num = int_of_string num in
        let c = client_find num in
        client_print c o;
        ""
    ), "<num> :\t\t\t\tview client";
    
    "vfr", Arg_none (fun o ->
        List.iter (fun c ->
            client_print c o) !!friends;
        ""
    ), ":\t\t\t\t\tview friends";
    
    "gfr", Arg_one (fun num o ->
        let num = int_of_string num in
        let c = client_find num in
        client_browse c true;        
        "client browse"
    ), "<num> : \t\t\t\task friend files";
    
    "x", Arg_one (fun num o ->
        let num = int_of_string num in
        let s = server_find num in
        (match server_state s with
            NotConnected _ -> ()
          | _ ->   server_disconnect s);
        ""
    ), "<num> :\t\t\t\tdisconnect from server";
    
    "use_poll", Arg_one (fun arg o ->
        let b = bool_of_string arg in
        BasicSocket.use_poll b;
        Printf.sprintf "poll: %s" (string_of_bool b)
    ), "<bool> :\t\t\tuse poll instead of select";
    
    "vma", Arg_none (fun o ->
        let buf = o.conn_buf in       
        let nb_servers = ref 0 in
        
        if o.conn_output = HTML && !!html_mods then 
          Printf.bprintf buf "\\<table class=\\\"servers\\\" cellspacing=0 cellpadding=0\\>\\<tr\\>
\\<td title=\\\"Server Number\\\" onClick=\\\"_tabSort(this,1);\\\" class=\\\"srh\\\"\\>#\\</td\\>
\\<td title=\\\"Button\\\" onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>Button\\</td\\>
\\<td title=\\\"High or Low ID\\\" onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>ID\\</td\\>
\\<td title=\\\"Network Name\\\" onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>Network\\</td\\>
\\<td title=\\\"Connection Status\\\" onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>Status\\</td\\>
\\<td title=\\\"IP Address\\\" onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh br\\\"\\>IP\\</td\\>
\\<td title=\\\"Number of Users\\\" onClick=\\\"_tabSort(this,1);\\\" class=\\\"srh ar\\\"\\>Users\\</td\\>
\\<td title=\\\"Number of Files\\\" onClick=\\\"_tabSort(this,1);\\\" class=\\\"srh ar br\\\"\\>Files\\</td\\>
\\<td title=\\\"Server Name\\\" onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>Name\\</td\\>
\\<td title=\\\"Server Details\\\" onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>Details\\</td\\>
";
        
        Intmap.iter (fun _ s ->
            try
              incr nb_servers;
              if o.conn_output = HTML && !!html_mods then 
                begin
                  if (!nb_servers mod 2 == 0) then Printf.bprintf buf "\\<tr class=\\\"dl-1\\\"\\>"
                  else Printf.bprintf buf "\\<tr class=\\\"dl-2\\\"\\>";
                end;
              
              server_print s o
            with e ->
                lprintf "Exception %s in server_print"
                  (Printexc2.to_string e); lprint_newline ();
        ) !!servers;
        
        if use_html_mods o then Printf.bprintf buf "\\</table\\>";
        
        
        Printf.sprintf "Servers: %d known\n" !nb_servers
    ), ":\t\t\t\t\tlist all known servers";
    
    "reshare", Arg_none (fun o ->
        let buf = o.conn_buf in
        shared_check_files ();
        "check done"
    ), ":\t\t\t\tcheck shared files for removal";
    
    "priority", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
        match args with
          p :: files ->
            let p = int_of_string p in
            let p = if p < 0 then 0 else p in
            List.iter (fun arg ->
                try
                  let file = file_find (int_of_string arg) in
                  file_set_priority file p;
                  Printf.bprintf buf "Setting priority of %s to %d\n"
                    (file_best_name file) (file_priority file);
                with _ -> failwith (Printf.sprintf "No file number %s" arg)
            ) files;
            "Done"
        | [] -> "Bad number of args"
    
    ), "<priority> <files numbers> :\tchange file priorities";
    
    "version", Arg_none (fun o ->
        if o.conn_output = HTML && !!html_mods then Printf.sprintf "\\<P\\>" ^ 
            CommonGlobals.version () else CommonGlobals.version ()
    ), ":\t\t\t\tprint mldonkey version";
    
    "forget", Arg_one (fun num o ->
        let buf = o.conn_buf in
        let num = int_of_string num in
        CommonSearch.search_forget (CommonSearch.search_find num);
        ""  
    ), "<num> :\t\t\t\tforget search <num>";
    
    "close_all_sockets", Arg_none (fun o ->
        BasicSocket.close_all ();
        "All sockets closed"
    ), ":\t\t\tclose all opened sockets";
    
    "friend_add", Arg_one (fun num o ->
        let num = int_of_string num in
        let c = client_find num in
        friend_add c;
        "Added friend"
    ), "<num> :\t\t\tadd friend <num>";
    
    "friend_remove", Arg_multiple (fun args o ->
        if args = ["all"] then begin
            List.iter (fun c ->
                friend_remove c
            ) !!friends;
            "Removed all friends"
          end else begin
            List.iter (fun num ->
                let num = int_of_string num in
                let c = client_find num in
                friend_remove c;
            ) args; "Removed friend"
          end
    ), "<client numbers> :\tremove friend (use arg 'all' for all friends)";    
    
    "friends", Arg_none (fun o ->
        let buf = o.conn_buf in
        
        if o.conn_output = HTML && !!html_mods then 
          Printf.bprintf buf "\\<div class=\\\"friends\\\"\\>
\\<a href=\\\"javascript:window.location.reload()\\\"\\>Refresh\\</a\\>
\\<table class=\\\"friends\\\" cellspacing=0 cellpadding=0\\>
\\<td title=\\\"Remove\\\" onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>Remove\\</td\\>
\\<td title=\\\"Network\\\" onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>Network\\</td\\>
\\<td title=\\\"Name\\\" onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>Name\\</td\\>
\\<td title=\\\"Files\\\" onClick=\\\"_tabSort(this,0);\\\" class=\\\"srh\\\"\\>State\\</td\\>
\\</tr\\>";
        
        let counter = ref 0 in
        List.iter (fun c ->
            let i = client_info c in
            let n = network_find_by_num i.client_network in
            if o.conn_output = HTML && !!html_mods then 
              begin
                
                if (!counter mod 2 == 0) then Printf.bprintf buf "\\<tr class=\\\"dl-1\\\"\\>"
                else Printf.bprintf buf "\\<tr class=\\\"dl-2\\\"\\>";
                
                incr counter;
                Printf.bprintf buf "
			\\<td title=\\\"Remove friend\\\"
			onMouseOver=\\\"mOvr(this,'#94AE94');\\\" 
			onMouseOut=\\\"mOut(this,this.bgColor);\\\" 
			onClick=\\\"parent.fstatus.location.href='/submit?q=friend_remove+%d'\\\" 
			class=\\\"srb\\\"\\>Remove\\</td\\>            
			\\<td title=\\\"Network\\\" class=\\\"sr\\\"\\>%s\\</td\\>            
			\\<td title=\\\"Name (click to view files)\\\"
			onMouseOver=\\\"mOvr(this,'#94AE94');\\\" 
			onMouseOut=\\\"mOut(this,this.bgColor);\\\" 
			onClick=\\\"location.href='/submit?q=files+%d'\\\" 
			class=\\\"sr\\\"\\>%s\\</td\\>            
	 		\\<td title=\\\"Click to view files\\\"
            onMouseOver=\\\"mOvr(this,'#94AE94');\\\" 
            onMouseOut=\\\"mOut(this,this.bgColor);\\\" 
            onClick=\\\"location.href='/submit?q=files+%d'\\\" 
            class=\\\"sr\\\"\\>%s\\</td\\>
			\\</tr\\>"
                  i.client_num
                  n.network_name
                  i.client_num
                  i.client_name
                  i.client_num
                  
                  (let rs = client_files c in
                  
                  if (List.length rs) > 0 then Printf.sprintf "%d Files Listed" (List.length rs)
                  else 
                    string_of_connection_state (client_state c) 
                
                )
              
              end
            
            else 
              Printf.bprintf buf "[%s %d] %s" n.network_name
                i.client_num i.client_name
        ) !!friends;
        
        if o.conn_output = HTML && !!html_mods then 
          Printf.bprintf buf "\\</tr\\>\\</table\\>\\<a onclick=\\\"javascript:parent.fstatus.location.href='/submit?q=friend_remove+all';\\\"\\>Remove All Friends\\</a\\>\\</div\\>";
        
        ""
    ), ":\t\t\t\tdisplay all friends";
    
    "files", Arg_one (fun arg o ->
        let buf = o.conn_buf in
        let n = int_of_string arg in
        List.iter (fun c ->
            if client_num c = n then begin
                let rs = client_files c in
                
                let rs = List2.tail_map (fun (s, r) ->
                      r, CommonResult.result_info r, 1
                  ) rs in
                CommonInteractive.last_results := [];
                Printf.bprintf buf "Reinitialising download selectors\n";
                DriverInteractive.print_results buf o rs;
                
                ()
              end
        ) !!friends;
        ""), "<friend_num> :\t\t\tprint friend files";
    
    
    "bw_stats", Arg_none (fun o -> 
        let buf = o.conn_buf in
        if o.conn_output = HTML && !!html_mods then 
          begin
            
            let dlkbs = 
              (( (float_of_int !saved_download_udp_rate) +. (float_of_int !saved_download_tcp_rate)) /. 1024.0) in
            let ulkbs =
              (( (float_of_int !saved_upload_udp_rate) +. (float_of_int !saved_upload_tcp_rate)) /. 1024.0) in
            
            
            Printf.bprintf buf "\\<meta http-equiv=\\\"refresh\\\" content=\\\"11\\\"\\>";
            Printf.bprintf buf "\\<div class=\\\"bw_stats\\\"\\>";
            Printf.bprintf buf "\\<table class=\\\"bw_stats\\\" cellspacing=0 cellpadding=0\\>\\<tr\\>";
            Printf.bprintf buf "\\<td\\>\\<table border=0 cellspacing=0 cellpadding=0\\>\\<tr\\>
\\<td title=\\\"Download KB/s (UDP|TCP)\\\" class=\\\"bu bbig bbig1 bb4\\\"\\>Down: %.1f KB/s (%d|%d)\\</td\\>
\\<td title=\\\"Upload KB/s (UDP|TCP)\\\" class=\\\"bu bbig bbig1 bb4\\\"\\>Up: %.1f KB/s (%d|%d)\\</td\\>
\\<td title=\\\"Total Shared Files/Bytes\\\" class=\\\"bu bbig bbig1 bb3\\\"\\>Shared: %d/%s\\</td\\>"
              
              dlkbs
              !saved_download_udp_rate
              !saved_download_tcp_rate
              ulkbs
              !saved_upload_udp_rate
              !saved_upload_tcp_rate
              !nshared_files
              (size_of_int64 !upload_counter);
            
            Printf.bprintf buf "\\</tr\\>\\</table\\>\\</td\\>\\</tr\\>\\</table\\>\\</div\\>";
            
            Printf.bprintf buf "\\<script language=\\\"JavaScript\\\"\\>window.parent.document.title='(D:%.1f) (U:%.1f) | MLDonkey %s'\\</script\\>"
              dlkbs ulkbs Autoconf.current_version
          
          
          end
        
        else 
          Printf.bprintf buf "Down: %.1f KB/s ( %d + %d ) | Up: %.1f KB/s ( %d + %d ) | Shared: %d/%s"
            (( (float_of_int !saved_download_udp_rate) +. (float_of_int !saved_download_tcp_rate)) /. 1024.0)
          !saved_download_udp_rate
            !saved_download_tcp_rate
            (( (float_of_int !saved_upload_udp_rate) +. (float_of_int !saved_upload_tcp_rate)) /. 1024.0)
          !saved_upload_udp_rate
            !saved_upload_tcp_rate
            !nshared_files
            (size_of_int64 !upload_counter);
        ""
    ), ":\t\t\t\tprint current bandwidth stats";
    
    "mem_stats", Arg_none (fun o -> 
        let buf = o.conn_buf in
        Heap.print_memstats buf;
        ""
    ), ":\t\t\t\tprint memory stats";
    
    "rem", Arg_multiple (fun args o ->
        List.iter (fun servnum ->
            let num = int_of_string servnum in
            server_remove (server_find num)
        ) args;
        Printf.sprintf "%d servers removed" (List.length args)
    ), "<serv1> ... <servx> :\t\tremove servers";
    
    "server_banner", Arg_one (fun num o ->
        let buf = o.conn_buf in
        let num = int_of_string num in
        let s = server_find num in
        (match server_state s with
            NotConnected _ -> ()
          | _ ->   server_banner s o);
        ""
    ), "<num> :\t\t\tprint connected server banner <server num>";
    
    "log", Arg_none (fun o ->
        let buf = o.conn_buf in
        (try
            while true do
              let s = Fifo.take lprintf_fifo in
              decr lprintf_size;
              Buffer.add_string buf s
            done
          with _ -> ());
        "------------- End of log"
    ), " :\t\t\tdump current log state to console";
    
    "stdout", Arg_one (fun arg o ->
        let buf = o.conn_buf in
        let b = bool_of_string arg in
        lprintf_to_stdout := b;
        Printf.sprintf "log to stdout %s" 
          (if b then "enabled" else "disabled")
    ), " :\t\t\treactivate log to stdout";
    
    
    ]

let _ =
  CommonNetwork.register_commands commands
