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

open CommonShared
open CommonServer
open CommonResult
open CommonClient
open CommonUser
open CommonInteractive
open CommonNetwork
open Gui_proto
open CommonTypes
open CommonComplexOptions
open CommonFile
open DonkeySearch
open Options
open DonkeyMftp
open Mftp_comm
open DonkeyServers
open BasicSocket
open TcpBufferedSocket
open DonkeyOneFile
open DonkeyFiles
open DonkeyComplexOptions
open DonkeyTypes
open DonkeyOptions
open DonkeyGlobals
open DonkeyClient
open CommonGlobals
open CommonOptions
  
let result_name r =
  match r.result_names with
    [] -> None
  | name :: _ -> Some name

      
let reconnect_all file =
  Intmap.iter (fun _ c ->
      connection_must_try c.client_connection_control;
      match c.client_kind with
        Known_location _ ->
          connect_client !!client_ip [file] c
      | _ -> ()) file.file_sources;
  List.iter (fun s ->
      match s.server_sock, server_state s with
      | Some sock, (Connected_idle | Connected_busy) ->
          query_locations file s sock    
      | _ -> ()
  ) (connected_servers())
    
let forget_search num =  
  if !last_xs = num then last_xs := (-1);
  local_searches := List.rev (List.fold_left (fun list s ->
        if s.search_search.search_num = num then list else s :: list) 
    [] !local_searches)

  
  
let save_as file real_name =
(*
Source of bug ...
Unix2.safe_mkdir (Filename.dirname real_name);
*)
  old_files =:= file.file_md4 :: !!old_files;
  file_commit (as_file file.file_file);
  Unix32.close file.file_fd;
  let old_name = file.file_hardname in
  Printf.printf "\nMOVING %s TO %s\n" old_name real_name; 
  print_newline ();
  (try 
      Unix2.rename old_name real_name ;
      change_hardname file real_name;
    with e -> 
        Printf.printf "Error in rename %s (src [%s] dst [%s])"
          (Printexc.to_string e) old_name real_name; 
        print_newline ();
        let new_name = Filename.concat (Filename.dirname old_name)
          (Filename.basename real_name) in
        try 
          Unix2.rename old_name new_name;
          change_hardname file new_name
        with _ -> ()
  )
  ;
  remove_file_clients file;
  file.file_changed <- FileInfoChange;
  !file_change_hook file
  
let save_file file name =
  let real_name = Filename.concat !!incoming_directory name in
  save_as file real_name;
  file_commit (as_file file.file_file)

let load_server_met filename =
  try
    let module S = DonkeyImport.Server in
    let s = File.to_string filename in
    let ss = S.read s in
    List.iter (fun r ->
        let server = add_server r.S.ip r.S.port in
        List.iter (fun tag ->
            match tag with
              { tag_name = "name"; tag_value = String s } -> 
                server.server_name <- s;
            |  { tag_name = "description" ; tag_value = String s } ->
                server.server_description <- s
            | _ -> ()
        ) r.S.tags
    ) ss
  with e ->
      Printf.printf "Exception %s while loading %s" (Printexc.to_string e)
      filename;
      print_newline () 

        
let load_url kind url =
  Printf.printf "QUERY URL %s" url; print_newline ();
  let filename = Filename.temp_file "http_" ".tmp" in
  let file_oc = open_out filename in
  let file_size = ref 0 in
  Http_client.get_page (Url.of_string url) []
    (Http_client.default_headers_handler 
      (fun maxlen sock nread ->
        let buf = TcpBufferedSocket.buf sock in
        
        if nread > 0 then begin
            let left = 
              if maxlen >= 0 then
                mini (maxlen - !file_size) nread
              else nread
            in
            output file_oc buf.buf buf.pos left;
            buf_used sock left;
            file_size := !file_size + left;
            if nread > left then
              TcpBufferedSocket.close sock "end read"
          end
        else
        if nread = 0 then begin
            close_out file_oc;
            try
              begin
                match kind with
                  "server.met" ->
                    load_server_met filename;
                    Printf.printf "SERVERS ADDED"; print_newline ();
                | "comments.met" ->
                    DonkeyIndexer.load_comments filename;
                    Printf.printf "COMMENTS ADDED"; print_newline ();
                | _ -> failwith (Printf.sprintf "Unknown kind [%s]" kind)
              end;
              Sys.remove filename
              with e ->
                  Printf.printf
                    "Exception %s in loading downloaded file %s"
                    (Printexc.to_string e) filename
          
          end
    ))

      
let really_query_download filenames size md4 location old_file absents =
  begin
    try
      let file = Hashtbl.find files_by_md4 md4 in
      if file_state file = FileDownloaded then 
        raise Already_done;
    with Not_found -> ()
  end;
  
  List.iter (fun file -> 
      if file.file_md4 = md4 then raise Already_done) 
  !current_files;

  let temp_file = Filename.concat !!temp_directory (Md4.to_string md4) in
  begin
    match old_file with
      None -> ()
    | Some filename ->
        if Sys.file_exists filename && not (
            Sys.file_exists temp_file) then
          (try 
              Printf.printf "Renaming from %s to %s" filename
                temp_file; print_newline ();
              Unix2.rename filename temp_file with e -> 
                Printf.printf "Could not rename %s to %s: exception %s"
                  filename temp_file (Printexc.to_string e);
                print_newline () );        
  end;
  
  let file = new_file FileDownloading temp_file md4 size true in
  begin
    match absents with
      None -> ()
    | Some absents -> 
        let absents = Sort.list (fun (p1,_) (p2,_) -> p1 <= p2) absents in
        file.file_absent_chunks <- absents;
  end;
  
  let other_names = DonkeyIndexer.find_names md4 in
  let filenames = List.fold_left (fun names name ->
        if List.mem name names then names else name :: names
    ) filenames other_names in 
  file.file_filenames <- filenames @ file.file_filenames;

  current_files := file :: !current_files;
  !file_change_hook file;
  set_file_size file file.file_size;
  List.iter (fun s ->
      match s.server_sock with
        None -> () (* assert false !!! *)
      | Some sock ->
          query_locations file s sock
  ) (connected_servers());

  (try
      let servers = Hashtbl.find_all udp_servers_replies file.file_md4 in
      List.iter (fun s ->
          Printf.printf "ASKING EXTENDED SEARCH RESULT SENDER"; 
          print_newline ();
          udp_server_send s (Mftp_server.QueryLocationUdpReq file.file_md4)
      ) servers
    with _ -> ());
  
  (match location with
      None -> ()
    | Some num ->
        let c = client_find num in
        client_connect c
        (*
        try 
          let c = find_client num in
          (match c.client_kind with
              Indirect_location -> 
                if not (Intmap.mem c.client_num file.file_indirect_locations) then
                  file.file_indirect_locations <- Intmap.add c.client_num c
                    file.file_indirect_locations
            
            | _ -> 
                if not (Intmap.mem c.client_num file.file_known_locations) then
                  new_known_location file c
          );
          if not (List.memq file c.client_files) then
            c.client_files <- file :: c.client_files;
          match client_state c with
            NotConnected -> 
              connect_client !!client_ip [file] c
          | Connected_busy | Connected_idle | Connected_queued ->
              begin
                match c.client_sock with
                  None -> ()
                | Some sock -> 
                    DonkeyClient.query_files c sock [file]
              end
          | _ -> ()
with _ -> ()
*)
  )


let aborted_download = ref None
        
let query_download filenames size md4 location old_file absents =
  
  List.iter (fun m -> 
      if m = md4 then begin
          aborted_download := Some (
            filenames,size,md4,location,old_file,absents);
          raise Already_done
        end) 
  !!old_files;
  really_query_download filenames size md4 location old_file absents
  
let load_prefs filename = 
  try
    let module P = DonkeyImport.Pref in
    let s = File.to_string filename in
    let t = P.read s in
    t.P.client_tags, t.P.option_tags
  with e ->
      Printf.printf "Exception %s while loading %s" (Printexc.to_string e)
      filename;
      print_newline ();
      [], []
      
  
let import_config dirname =
  load_server_met (Filename.concat dirname "server.met");
  let ct, ot = load_prefs (Filename.concat dirname "pref.met") in
  let temp_dir = ref (Filename.concat dirname "temp") in

  List.iter (fun tag ->
      match tag with
      | { tag_name = "name"; tag_value = String s } ->
          client_name =:=  s
      | { tag_name = "port"; tag_value = Uint32 v } ->
          port =:=  Int32.to_int v
      | _ -> ()
  ) ct;

  List.iter (fun tag ->
      match tag with
      | { tag_name = "temp"; tag_value = String s } ->
          if Sys.file_exists s then (* be careful on that *)
            temp_dir := s
          else (Printf.printf "Bad temp directory, using default";
              print_newline ();)
      | _ -> ()
  ) ot;
  
  let list = Unix2.list_directory !temp_dir in
  let module P = DonkeyImport.Part in
  List.iter (fun filename ->
      try
        if Filename2.last_extension filename = ".part" then
          let filename = Filename.concat !temp_dir filename in
          let met = filename ^ ".met" in
          if Sys.file_exists met then
            let s = File.to_string met in
            let f = P.read s in
            let filenames = ref [] in
            let size = ref Int32.zero in
            List.iter (fun tag ->
                match tag with
                  { tag_name = "filename"; tag_value = String s } ->
                    Printf.printf "Import Donkey %s" s; 
                    print_newline ();
                    
                    filenames := s :: !filenames;
                | { tag_name = "size"; tag_value = Uint32 v } ->
                    size := v
                | _ -> ()
            ) f.P.tags;
            query_download !filenames !size f.P.md4 None 
              (Some filename) (Some (List.rev f.P.absents));
      
      with _ -> ()
  ) list
  
let broadcast msg =
  let s = msg ^ "\n" in
  let len = String.length s in
  List.iter (fun sock ->
      TcpBufferedSocket.write sock s 0 len
  ) !user_socks

let longest_name file =
  let max = ref "" in
  let maxl = ref 0 in
  List.iter (fun name ->
      if String.length name > !maxl then begin
          maxl := String.length name;
          max := name
        end
  ) file.file_filenames;
  !max

let saved_name file =
  let name = longest_name file in
(*  if !!use_mp3_tags then
    match file.file_format with
      Mp3 tags ->
        let module T = Mp3tag in
        let name = match name.[0] with
            '0' .. '9' -> name
          | _ -> Printf.sprintf "%02d-%s" tags.T.tracknum name
        in
        let name = if tags.T.album <> "" then
            Printf.sprintf "%s/%s" tags.T.album name
          else name in
        let name = if tags.T.artist <> "" then
            Printf.sprintf "%s/%s" tags.T.artist name
          else name in
        name          
    | _ -> name
else *)
  name
      
let print_file buf file =
  Printf.bprintf buf "[%-5d] %s %10s %32s %s" 
    (file_num file)
    (first_name file)
  (Int32.to_string file.file_size)
  (Md4.to_string file.file_md4)
  (if file_state file = FileDownloaded then
      "done" else
      Int32.to_string file.file_downloaded);
  Buffer.add_char buf '\n';
  Printf.bprintf buf "Connected clients:\n";
  let f _ c =
    match c.client_kind with
      Known_location (ip, port) ->
        Printf.bprintf  buf "[%-5d] %12s %-5d    %s\n"
          (client_num c)
          (Ip.to_string ip)
        port
          (match c.client_sock with
            None -> Date.to_string (connection_last_conn
                  c.client_connection_control)
          | Some _ -> "Connected")
    | _ ->
        Printf.bprintf  buf "[%-5d] %12s            %s\n"
          (client_num c)
          "indirect"
          (match c.client_sock with
            None -> Date.to_string (connection_last_conn
                  c.client_connection_control)
          | Some _ -> "Connected")
  in
  Intmap.iter f file.file_sources;
  Printf.bprintf buf "\nChunks: \n";
  Array.iteri (fun i c ->
      Buffer.add_char buf (
        match c with
          PresentVerified -> 'V'
        | PresentTemp -> 'p'
        | AbsentVerified -> '_'
        | AbsentTemp -> '.'
        | PartialTemp _ -> '?'
        | PartialVerified _ -> '!'
      )
  ) file.file_chunks
  

  (*
  
let simple_print_file buf name_len done_len size_len format file =
  Printf.bprintf buf "[%-5d] "
      (file_num file);
  if format.conn_output = HTML && file.file_state <> FileDownloaded then 
    Printf.bprintf buf "[\<a href=/submit\?q\=cancel\+%d $S\>CANCEL\</a\>] " 
    (file_num file);
  let s = short_name file in
  Printf.bprintf buf "%s%s " s
    (String.make (name_len - (String.length s)) ' ');

  if file.file_state <> FileDownloaded then begin
      let s = Int32.to_string file.file_downloaded in
      Printf.bprintf buf "%s%s " s (String.make (
          done_len - (String.length s)) ' ');
    end;

  let s = Int32.to_string file.file_size in
  Printf.bprintf buf "%s%s " s (String.make (
      size_len - (String.length s)) ' ');

  if file.file_state = FileDownloaded then
    Buffer.add_string buf (Md4.to_string file.file_md4)
  else
  if file.file_state = FilePaused then
    Buffer.add_string buf "Paused"
  else
  if file.file_last_rate < 10.24 then
    Buffer.add_string buf "-"
  else
    Printf.bprintf buf "%5.1f" (file.file_last_rate /. 1024.);
  Buffer.add_char buf '\n'
*)


    
  (*
  Printf.bprintf buf "\<TABLE\>\<TR\>
  \<TD\> [ Num ] \</TD\> 
  \<TD\> \<a href=/submit\?q\=vd\&sortby\=name\> File \</a\> \</TD\>";
  
  if not finished then
    Printf.bprintf buf 
    "\<TD ALIGN\=RIGHT\> \<a href=/submit\?q\=vd\&sortby\=percent\> Percent \</a\> \</TD\> 
\<TD ALIGN\=RIGHT\> \<a href=/submit\?q\=vd\&sortby\=done\> Downloaded \</a\> \</TD\> ";
  
  Printf.bprintf buf 
    "\<TD ALIGN=RIGHT\> \<a href=/submit\?q\=vd\&sortby\=size\> Size \</a\> \</TD\> ";
  
  Printf.bprintf buf "\<TD\> \<a href=/submit\?q\=vd\&sortby\=rate\> %s \</a\> \</TD\> " (if finished then "MD4" else "Rate");
  Printf.bprintf  buf "\</TR\>\n";
  
  List.iter (fun file ->
      Printf.bprintf buf "\<TR\> \<TD ALIGN\=RIGHT\> [%-5d]"
        (file_num file);
      if file.file_state <> FileDownloaded then 
        Printf.bprintf buf "[\<a href=/submit\?q\=cancel\+%d $S\>CANCEL\</a\>] " 
          (file_num file);
      Printf.bprintf  buf "\</TD\>";
      Printf.bprintf buf " \<TD\> %s \</TD\> " (short_name file);

      if file.file_state <> FileDownloaded then 
        Printf.bprintf buf "\<TD ALIGN\=RIGHT\> %5.1f \</TD\> \<TD ALIGN\=RIGHT\> %s \</TD\> " (percent file) (Int32.to_string file.file_downloaded);

      Printf.bprintf buf "\<TD ALIGN=RIGHT\> %s \</TD\> " (Int32.to_string file.file_size);

      Printf.bprintf buf "\<TD ALIGN=RIGHT\> %s \</TD\>"
        (if file.file_state = FileDownloaded then
          Md4.to_string file.file_md4
        else
        if file.file_state = FilePaused then
          "Paused"
        else
        if file.file_last_rate < 10.24 then
          "-"
        else
          Printf.sprintf "%5.1f" (file.file_last_rate /. 1024.));
      Buffer.add_string buf "\</TR\>"
      
  ) files;
  
  Printf.bprintf  buf "\</TABLE\>\n"
*)
(*  
let simple_print_file_list finished buf files format =
(*  if format.conn_output = HTML then *)
  simple_print_file_list_html finished buf files format
(*  else
  let size_len = ref 10 in
  let done_len = ref 10 in
  let name_len = ref 1 in
  List.iter 
    (fun f ->
      name_len := max !name_len (String.length (short_name f));
      size_len := max !size_len (String.length (Int32.to_string f.file_size));
      done_len := max !done_len (String.length (Int32.to_string f.file_downloaded));
  )
  files;
  Printf.bprintf buf "[ Num ] ";
  if format.conn_output = HTML then Printf.bprintf buf "         ";

  let make_spaces len s =
    String.make (max 0 (len - (String.length s))) ' '
  in
  let s = "File" in
  if format.conn_output = HTML then
    Printf.bprintf buf "\<a href=/submit\?q\=vd\&sortby\=name\>%s\</a\>%s "
    s (make_spaces  !name_len s)
  else
    Printf.bprintf buf "%s%s " s (make_spaces  !name_len s);
  
  if not finished then
    begin
      let s = "Downloaded" in
      if format.conn_output = HTML then
        Printf.bprintf buf "\<a href=/submit\?q\=vd\&sortby\=done\>%s\</a\>%s "
          s (make_spaces !done_len s)
      else
        Printf.bprintf buf "%s%s " s (make_spaces !done_len s);
    end;
  
  let s = "Size" in
  if format.conn_output = HTML then
    Printf.bprintf buf "\<a href=/submit\?q\=vd\&sortby\=size\>%s\</a\>%s "
      s (make_spaces !size_len s)
  else
    Printf.bprintf buf "%s%s " s (make_spaces !size_len s);
  
  let s = if finished then "MD4" else
    if format.conn_output = HTML then
      "\<a href=/submit\?q\=vd\&sortby\=rate\>Rate\</a\>"
    else "Rate"
  in
  Printf.bprintf buf "%s\n" s;
  
  List.iter (simple_print_file buf !name_len !done_len !size_len format) files
*)
    *)  

(*
        *)

let print_search _ _ _ = 
  Printf.printf "print_search not implemented"; print_newline ();
  ()

  (*
let print_connected_servers buf =
  Printf.bprintf  buf "Connected to %d eDonkey servers\n"
    (List.length !connected_server_list);
  List.iter (fun s ->
      Printf.bprintf buf "[%-5d] %s:%-5d  "
        s.server_num
        (Ip.to_string s.server_ip) s.server_port;
      List.iter (fun t ->
          Printf.bprintf buf "%-3s "
            (match t.tag_value with
              String s -> s
            | Uint32 i -> Int32.to_string i
            | Fint32 i -> Int32.to_string i
            | _ -> "???"
          )
      ) s.server_tags;
      Printf.bprintf buf " %6d %7d" s.server_nusers s.server_nfiles;
      Buffer.add_char buf '\n'
  ) !connected_server_list
    *)

let commands = [
    "n", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
        let ip, port =
          match args with
            [ip ; port] -> ip, port
          | [ip] -> ip, "4661"
          | _ -> failwith "n <ip> [<port>]: bad argument number"
        in
        let ip = Ip.of_string ip in
        let port = int_of_string port in
        
        let s = add_server ip port in
        Printf.bprintf buf "New server %s:%d\n" 
          (Ip.to_string s.server_ip) 
        s.server_port;
        ""
    ), " <ip> [<port>]: add a server";
        
    "vu", Arg_none (fun o ->
        let buf = o.conn_buf in
        Printf.sprintf "Upload credits : %d minutes\nUpload disabled for %d minutes" !upload_credit !has_upload;
    
    ), " : view upload credits";
            
    "mem_stats", Arg_none (fun o -> 
        let buf = o.conn_buf in
        DonkeyGlobals.mem_stats buf;
        ""
    ), " : print memory stats";

        
    "comments", Arg_one (fun filename o ->
        let buf = o.conn_buf in
        DonkeyIndexer.load_comments filename;
        DonkeyIndexer.save_comments ();
        "comments loaded and saved"
    ), " <filename> : load comments from file";
    
    "comment", Arg_two (fun md4 comment o ->
        let buf = o.conn_buf in
        let md4 = Md4.of_string md4 in
        DonkeyIndexer.add_comment md4 comment;
        "Comment added"
    ), " <md4> \"<comment>\" : add comment on an md4";
    
    "nu", Arg_one (fun num o ->
        let buf = o.conn_buf in
        let num = int_of_string num in
        let num = maxi 0 num in
        if num <= !upload_credit then
          begin
            upload_credit := !upload_credit - num;
            has_upload := !has_upload + num;
            Printf.sprintf "upload disabled for %d minutes" num
          end
        else 
          "not enough upload credits"
    
    
    ), " <m> : disable upload during <m> minutes (multiple of 5)";
    
    "import", Arg_one (fun dirname o ->
        let buf = o.conn_buf in
        try
          import_config dirname;
          "config loaded"
        with e ->
            Printf.sprintf "error %s while loading config" (
              Printexc.to_string e)
    ), " <dirname> : import the config from dirname";
    
    "load_old_history", Arg_none (fun o ->
        let buf = o.conn_buf in
        DonkeyIndexer.load_old_history ();
        "Old history loaded"
    ), " : load history.dat file";
    
    "servers", Arg_one (fun filename o ->
        let buf = o.conn_buf in
        try
          load_server_met filename;
          "file loaded"
        with e -> 
            Printf.sprintf "error %s while loading file" (Printexc.to_string e)
    ), " <filename> : add the servers from a server.met file";

    
    "id", Arg_none (fun o ->
        let buf = o.conn_buf in
        List.iter (fun s ->
            Printf.bprintf buf "For %s:%d  --->   %s\n"
              (Ip.to_string s.server_ip) s.server_port
              (if Ip.valid s.server_cid then
                Ip.to_string s.server_cid
              else
                Int32.to_string (Ip.to_int32 s.server_cid))
        ) (connected_servers());
        ""
    ), " : print ID on connected servers";
    
    "add_url", Arg_two (fun kind url o ->
        let buf = o.conn_buf in
        let v = (kind, 1, url) in
        if not (List.mem v !!web_infos) then
          web_infos =:=  v :: !!web_infos;
        load_url kind url;
        "url added to web_infos. downloading now"
    ), " <kind> <url> : load this file from the web. 
    kind is either server.met (if the downloaded file is a server.met)";
    
    "recover_temp", Arg_none (fun o ->
        let buf = o.conn_buf in
        let files = Unix2.list_directory !!temp_directory in
        List.iter (fun filename ->
            if String.length filename = 32 then
              try
                let md4 = Md4.of_string filename in
                try
                  ignore (Hashtbl.find files_by_md4 md4)
                with Not_found ->
                    let size = Unix32.getsize32 (Filename.concat 
                          !!temp_directory filename) in
                    query_download [] size md4 None None None
              with e ->
                  Printf.printf "exception %s in recover_temp"
                    (Printexc.to_string e); print_newline ();
        ) files;
        "done"
    ), " : recover lost files from temp directory";
    
    "upstats", Arg_none (fun o ->
        let buf = o.conn_buf in
        Printf.bprintf buf "Upload statistics:\n";
        Printf.bprintf buf "Total: %d blocks uploaded\n" !upload_counter;
        let list = ref [] in
        Hashtbl.iter (fun _ file ->
            if file.file_shared then 
              list := file :: !list
        ) files_by_md4;
        let list = Sort.list (fun f1 f2 ->
              f1.file_upload_requests >= f2.file_upload_requests)
          
          !list in
        List.iter (fun file ->
            Printf.bprintf buf "%-50s requests: %8d blocs: %8d\n"
              (first_name file) file.file_upload_requests
              file.file_upload_kbs;
        ) list;
        "done"
    ), " : statistics on upload";
    
    "xs", Arg_none (fun o ->
        let buf = o.conn_buf in
        if !last_xs >= 0 then begin
            try
              let ss = DonkeyFiles.find_search !last_xs in
              make_xs ss;
              "extended search done"
            with e -> Printf.sprintf "Error %s" (Printexc.to_string e)
          end else "No previous extended search"),
    ": extended search";
    
    "clh", Arg_none (fun o ->
        let buf = o.conn_buf in
        DonkeyIndexer.clear ();
        "local history cleared"
    ), " : clear local history";
    
    "scan_temp", Arg_none (fun o ->
        let buf = o.conn_buf in
        let list = Unix2.list_directory !!temp_directory in
        List.iter (fun filename ->
            try
              let md4 = Md4.of_string filename in
              try
                let file = find_file md4 in
                Printf.bprintf buf "%s is %s %s\n" filename
                  (first_name file)
                "(downloading)" 
              with _ ->
                  Printf.bprintf buf "%s %s %s\n"
                  filename
                    (if List.mem md4 !!old_files then
                      "is an old file" else "is unknown")
                  (try
                      let names = DonkeyIndexer.find_names md4 in
                      List.hd names
                    with _ -> "and never seen")
                    
            with _ -> 
                Printf.bprintf buf "%s unknown\n" filename
        
        ) list;
        "done";
    ), " : print temp directory content";
    
    "dllink", Arg_multiple (fun args o ->        
        let buf = o.conn_buf in
        let url = String2.unsplit args ' ' in
        match String2.split (String.escaped url) '|' with
          "ed2k://" :: "file" :: name :: size :: md4 :: _
        |              "file" :: name :: size :: md4 :: _ ->
            query_download [name] (Int32.of_string size)
            (Md4.of_string md4) None None None;
            "download started"
        | _ -> "bad syntax"    
    ), " <ed2klink> : download ed2k:// link";
    
    "force_download", Arg_none (fun o ->
        let buf = o.conn_buf in
        match !aborted_download with
          None -> "No download to force"
        | Some (filenames,size,md4,location,old_file,absents) ->
            really_query_download filenames
            size md4 location old_file absents;
            "download started"
    ), " : force download of an already downloaded file";

        
    "forget", Arg_one (fun num o ->
        let buf = o.conn_buf in
        let num = int_of_string num in
        forget_search num;
        ""  
    ), " <num> : forget search <num>";

    (*
    "ls", Arg_multiple (fun args o ->
        let query = CommonSearch.search_of_args args in
        let search = CommonSearch.new_search query in
        local_searches := search :: !local_searches;
        DonkeyIndexer.find search;
        "local search started"
    ), " <query> : local search";
*)
    
    "remove_old_servers", Arg_none (fun o ->
        let buf = o.conn_buf in
        DonkeyServers.remove_old_servers ();
        "clean done"
    ), ": remove servers that have not been connected for several days";

  ]

let _ =
  register_commands commands;
  file_ops.op_file_resume <- (fun file ->
      reconnect_all file;
      file.file_changed <- FileInfoChange;
      !file_change_hook file
  );
  file_ops.op_file_pause <- (fun file ->
      file.file_changed <- FileInfoChange;
      !file_change_hook file
  );
  network.op_network_private_message <- (fun iddest s ->      
      try
        let c = DonkeyGlobals.find_client_by_name iddest in
        match c.client_sock with
          None -> 
            (
(* A VOIR  : est-ce que c'est bien de fait comme �a ? *)
              DonkeyClient.connect_client !!CommonOptions.client_ip [] c;
              match c.client_sock with
                None ->
                  CommonChat.send_text !!CommonOptions.chat_console_id None 
                    (Printf.sprintf "client %s : could not connect (client_sock=None)" iddest)
              | Some sock ->
                  direct_client_send sock (Mftp_client.SayReq s)
            )
        | Some sock ->
            direct_client_send sock (Mftp_client.SayReq s)
      with
        Not_found ->
          CommonChat.send_text !!CommonOptions.chat_console_id None 
            (Printf.sprintf "client %s unknown" iddest)
  )

let _ =
  result_ops.op_result_info <- (fun rs ->
      Store.get store rs.result_index
  )

module P = Gui_proto

let rec last file = function
    [x] -> x
  | _ :: l -> last file l
  | _ -> (Int32.zero, file.file_last_time)

let _ =
  file_ops.op_file_info <- (fun file ->
      
      let (last_downloaded, file_last_time) = last file file.file_last_downloaded in
      let time = last_time () -. file_last_time in
      let diff = Int32.sub file.file_downloaded last_downloaded in
      file.file_last_time <- last_time ();
      let rate = if time > 0.0 && diff > Int32.zero then begin
            (Int32.to_float diff) /. time;
          end else 0.0
      in
      file.file_last_rate <- rate;
      {
        P.file_num = (file_num file);
        P.file_network = network.network_num;
        P.file_names = file.file_filenames;
        P.file_md4 = file.file_md4;
        P.file_size = file.file_size;
        P.file_downloaded = file.file_downloaded;
        P.file_nlocations = 0;
        P.file_nclients = 0;
        P.file_state = file_state file;
        P.file_sources = None;
        P.file_download_rate = file.file_last_rate;
        P.file_chunks = file.file_all_chunks;
        P.file_availability = String2.init file.file_nchunks (fun i ->
            if file.file_available_chunks.(i) > 1 then '2' else
            if file.file_available_chunks.(i) > 0 then '1' else
              '0');
        P.file_format = file.file_format;
        P.file_chunks_age = file.file_chunks_age;
        P.file_age = file.file_age;
      }
  )

let _ =
  server_ops.op_server_info <- (fun s ->
      {
        P.server_num = (server_num s);
        P.server_network = network.network_num;
        P.server_ip = s.server_ip;
        P.server_port = s.server_port;
        P.server_score = s.server_score;
        P.server_tags = s.server_tags;
        P.server_nusers = s.server_nusers;
        P.server_nfiles = s.server_nfiles;
        P.server_state = server_state s;
        P.server_name = s.server_name;
        P.server_description = s.server_description;
        P.server_users = None;
      }
  )


let _ =
  user_ops.op_user_info <- (fun u ->
      {
        P.user_num = u.user_user.impl_user_num;
        P.user_md4 = u.user_md4;
        P.user_ip = u.user_ip;
        P.user_port = u.user_port;
        P.user_tags = u.user_tags;
        P.user_name = u.user_name;
        P.user_server = u.user_server.server_server.impl_server_num;
        P.user_state = u.user_user.impl_user_state;
      }
  )

let _ =
  client_ops.op_client_info <- (fun c ->
      {
        P.client_network = network.network_num;
        P.client_kind = c.client_kind;
        P.client_state = client_state c;
        P.client_type = client_type (as_client c.client_client);
        P.client_tags = c.client_tags;
        P.client_name = c.client_name;
        P.client_files = None;
        P.client_num = (client_num c);
        P.client_rating = c.client_rating;
        P.client_chat_port = c.client_chat_port ;
      }
  )

let _ =
  result_ops.op_result_download <- (fun rs filenames ->
      let r = Store.get store rs.result_index in
      query_download filenames r.result_size r.result_md4 None None None;
  )

let _ =
  network.op_network_connect_servers <- (fun _ ->
      force_check_server_connections true
  );
  network.op_network_add_server_id <- (fun ip port ->
      let s = add_server ip port in
      server_must_update s
  )

let _ =
  server_ops.op_server_remove <- (fun s ->
      DonkeyComplexOptions.remove_server s.server_ip s.server_port
  );
  server_ops.op_server_connect <- (fun s ->
      connect_server s);
  server_ops.op_server_disconnect <- (fun s ->
      match s.server_sock with
        None -> ()
      | Some sock ->
          TcpBufferedSocket.shutdown sock "user disconnect");
  server_ops.op_server_query_users <- (fun s ->
      match s.server_sock, server_state s with
        Some sock, (Connected_idle | Connected_busy) ->
          direct_server_send sock (Mftp_server.QueryUsersReq "");
          Fifo.put s.server_users_queries false
      | _ -> ()
  );
  server_ops.op_server_find_user <- (fun s user ->
      match s.server_sock, server_state s with
        Some sock, (Connected_idle | Connected_busy) ->
          direct_server_send sock (Mftp_server.QueryUsersReq user);
          Fifo.put s.server_users_queries true
      | _ -> ()      
  );
  server_ops.op_server_users <- (fun s ->
      List2.tail_map (fun u -> as_user u.user_user) s.server_users)    ;

  server_ops.op_server_print <- (fun s o ->
      let buf = o.conn_buf in
      Printf.bprintf buf "[Donkey %-5d] %s:%-5d  "
        (server_num s)
      (Ip.to_string s.server_ip) s.server_port;
      List.iter (fun t ->
          Printf.bprintf buf "%-3s "
            (match t.tag_value with
              String s -> s
            | Uint32 i -> Int32.to_string i
            | Fint32 i -> Int32.to_string i
            | _ -> "???"
          )
      ) s.server_tags;
      (match s.server_sock with
          None -> ()
        | Some _ ->
            Printf.bprintf buf " %6d %7d" s.server_nusers s.server_nfiles);
      Buffer.add_char buf '\n'
  )
  
let _ =
  file_ops.op_file_save_as <- (fun file name ->
      file.file_filenames <- [name]
  );
  file_ops.op_file_disk_name <- (fun file -> file.file_hardname);
  file_ops.op_file_best_name <- (fun file -> first_name file);
  file_ops.op_file_set_format <- (fun file format ->
      file.file_format <- format);
  file_ops.op_file_check <- (fun file ->
      DonkeyOneFile.verify_chunks file);  
  file_ops.op_file_recover <- (fun file ->
      if file_state file = FileDownloading then 
        reconnect_all file);
  file_ops.op_file_print <- (fun f o ->
      let buf = o.conn_buf in
      Printf.bprintf buf "[Donkey %5d] %-50s %10s %10s\n" 
        (file_num f) (first_name f) 
        (Int32.to_string f.file_size)
      (Int32.to_string f.file_downloaded)      
  );
  file_ops.op_file_sources <- (fun file ->
      let list = ref [] in
      Intmap.iter (fun _ c -> 
          list := (as_client c.client_client) :: !list) file.file_sources;
      !list)
  
let _ =
  network.op_network_extend_search <- (fun _ ->
      if !last_xs >= 0 then begin
          try
            let ss = DonkeyFiles.find_search !last_xs in
            make_xs ss;
          with _ -> ()
        end
  );
  
  network.op_network_clean_servers <- (fun _ ->
      DonkeyServers.remove_old_servers ());
  
  network.op_network_add_friend_id <- (fun ip port ->
      let c = new_client (Known_location (ip,port)) in
      new_friend c);

  network.op_network_connect_servers <- (fun _ ->
      force_check_server_connections true)

let _ =
  client_ops.op_client_say <- (fun c s ->
      match c.client_sock with
        None -> ()
      | Some sock ->
          direct_client_send sock (Mftp_client.SayReq s)
  );  
  client_ops.op_client_files <- (fun c ->
      match c.client_all_files with
        None -> []
      | Some files -> List2.tail_map (fun r -> as_result r.result_result) files
  );
  client_ops.op_client_remove_friend <- (fun c ->
      friend_remove c);
  client_ops.op_client_set_friend <- (fun c ->
      friend_add c);  
  client_ops.op_client_connect <- (fun c ->
      connection_must_try c.client_connection_control;
      connect_client !!client_ip [] c
  );    
  client_ops.op_client_print <- (fun c output ->
      let buf = output.conn_buf in      
      (match c.client_kind with
          Indirect_location _ -> 
            Printf.bprintf buf "Client [%5d] Indirect client\n" 
            (client_num c)
        | Known_location (ip, port) ->
            Printf.bprintf buf "Client [%5d] %s:%d\n" 
            (client_num c)
              (Ip.to_string ip) port);
      Printf.bprintf buf "Name: %s\n" c.client_name;
      (match c.client_all_files with
          None -> ()
        | Some results ->
            Printf.bprintf buf "Files:\n";
            List.iter (fun rs ->
                let doc = rs.result_index in
                let r = Store.get store doc in
                if output.conn_output = HTML then 
                  Printf.bprintf buf "\<A HREF=/submit\?q=download\&md4=%s\&size=%s\>"
                    (Md4.to_string r.result_md4) (Int32.to_string r.result_size);
                begin
                  match r.result_names with
                    [] -> ()
                  | name :: names ->
                      Printf.bprintf buf "%s\n" name;
                      List.iter (fun s -> Printf.bprintf buf "       %s\n" s) names;
                end;
                begin
                  match r.result_comment with
                    None -> ()
                  | Some comment ->
                      Printf.bprintf buf "COMMENT: %s\n" comment;
                end;
                if output.conn_output = HTML then 
                  Printf.bprintf buf "\</A HREF\>";
                Printf.bprintf  buf "          %10s %10s " 
                  (Int32.to_string r.result_size)
                (Md4.to_string r.result_md4);
                List.iter (fun t ->
                    Buffer.add_string buf (Printf.sprintf "%-3s "
                        (match t.tag_value with
                          String s -> s
                        | Uint32 i -> Int32.to_string i
                        | Fint32 i -> Int32.to_string i
                        | _ -> "???"
                      ))
                ) r.result_tags;
                Buffer.add_char buf '\n';
            ) results
      )
  )  

let _ =
  user_ops.op_user_set_friend <- (fun u ->
      let s = u.user_server in
(*      let s = find_server key.P.key_ip key.P.key_port in *)
      add_user_friend s u
  )

  
let _ =
  shared_ops.op_shared_unshare <- (fun s file ->
      file.file_shared <- false;
      decr nshared_files;
      Unix32.close  file.file_fd;
      file.file_hardname <- "";
      try Hashtbl.remove files_by_md4 file.file_md4 with _ -> ()
  )
