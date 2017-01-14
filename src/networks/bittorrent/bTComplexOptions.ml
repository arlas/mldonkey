(* Copyright 2001, 2002 b52_simon :), b8_bavard, b8_fee_carabine, INRIA *)
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

open Int64ops
open Printf2
open BasicSocket
open Md4
open Options

open CommonGlobals
open CommonDownloads
open CommonInteractive (* file_add *)
open CommonTypes
open CommonFile

open BTTypes
open BTOptions
open BTGlobals

let bt_dht_ini = create_options_file "bt_dht.ini"
let bt_dht_section = file_section bt_dht_ini [] ""

let dht_routing_table = define_option bt_dht_section ["dht_routing_table"] ""
    Kademlia.RoutingTableOption.t (Kademlia.create ())

let bt_stats_ini = create_options_file "stats_bt.ini"
let bt_stats_section = file_section bt_stats_ini [] ""

module StatsOption = struct

    let value_to_stat v =
      match v with
        Options.Module assocs ->
          {
            brand_seen = value_to_int (List.assoc "seen" assocs);
            brand_banned = value_to_int (List.assoc "banned" assocs);
            brand_filerequest = value_to_int (List.assoc "filereqs" assocs);
            brand_download = value_to_int64 (List.assoc "download" assocs);
            brand_upload = value_to_int64 (List.assoc "upload" assocs);
          }

      | _ -> failwith "Options: not a stat option"

    let stat_to_value b =
      Options.Module [
        "seen", int_to_value b.brand_seen;
        "banned", int_to_value b.brand_banned;
        "filereqs", int_to_value b.brand_filerequest;
        "download", int64_to_value b.brand_download;
        "upload", int64_to_value b.brand_upload;
      ]


    let t = define_option_class "Stat" value_to_stat stat_to_value
  end

module ClientOption = struct

    let value_to_client file v =
      match v with
      | Module assocs ->

          let get_value name conv = conv (List.assoc name assocs) in
          let client_ip = get_value "client_ip" (from_value Ip.option)
          in
          let client_port = get_value "client_port" value_to_int in
          let client_uid = get_value "client_uid" (from_value Sha1.option) in
          let c = new_client file client_uid (client_ip, client_port) None in

          c
      | _ -> failwith "Options: Not a client"


    let client_to_value c =
      let (ip,port) = c.client_host in
          Options.Module [
            "client_uid", to_value Sha1.option c.client_uid;
            "client_ip", to_value Ip.option ip;
            "client_port", int_to_value port;
          ]

    let to_value = client_to_value
    let of_value = value_to_client

  end

(* insert in network.op_network_file_of_option <- value_to_file;
* value_to_file should decode file from files.ini?
* values are in bTTypes.ml
*)
let value_to_file file_size file_state user group assocs =
	(* loading options: *)
	let get_value name conv = conv (List.assoc name assocs) in
	let file_size = get_value "file_size" value_to_int64 in
	(* file_fd file *)
	(* file_file *)
	let file_piece_size = try value_to_int64 (List.assoc "file_piece_size" assocs) with _ -> failwith "Bad file size" in
	let file_id = try Sha1.of_string (get_value "file_id" value_to_string) with _ -> failwith "Bad file_id" in
	let file_temp = try get_value "file_temp" value_to_string
	with Not_found -> Filename.concat !!DO.temp_directory (Printf.sprintf "BT-%s" (Sha1.to_string file_id))
	in
	let file_name = get_value "file_name" value_to_string in
	let file_comment = try get_value "file_comment" value_to_string with Not_found -> "" in
	let file_created_by = try get_value "file_created_by" value_to_string with Not_found -> "" in
	let file_creation_date = try get_value "file_creation_date" value_to_int64 with Not_found -> Int64.zero in
	let file_modified_by = try get_value "file_modified_by" value_to_string with Not_found -> "" in
	let file_encoding = try get_value "file_encoding" value_to_string with Not_found -> "" in
	(* file_swarmer *)
	(* file_clients *)
	(* file_clients_num *)
	let file_chunks = get_value "file_hashes" (value_to_array (from_value Sha1.option)) in
	let file_files =
		try
			get_value "file_files"
				(value_to_list (fun v ->
					match v with
					| SmallList [name; p1]
					| List [name; p1] -> value_to_string name, value_to_int64 p1
					| _ -> assert false
				))
		with _ -> []
	in
	(* file_blocks_downloaded *)
	let file_uploaded = try get_value "file_uploaded" value_to_int64 with _ -> Int64.zero in
	(* file_torrent_diskname *)
	let file_torrent_diskname =
		try
			get_value "file_torrent_name" value_to_string
		with Not_found -> Filename.concat downloads_directory
            (file_name ^ ".torrent")
	in
	(* we can use here !!auto_tracker_list *)
	let file_trackers = try get_value "file_trackers" (value_to_list value_to_string) with _ -> [""] in
	(* useless old file support? or missing final 's'? *)
	(*with _ ->
		try
			[get_value "file_tracker"  value_to_string]
		with _ -> failwith "Bad file_tracker"
	in*)
	(* file_tracker_connected *)
	(* file_completed_hook *)
	(* file_shared *)
	(* file_session_uploaded *)
	(* file_session_downloaded *)
	(* file_last_dht_announce *)
	let file_metadata_size = try get_value "file_metadata_size" value_to_int64 with _ -> Int64.zero in
	let file_metadata_piece = try get_value "file_metadata_piece" value_to_int64 with _ -> Int64.zero in
	let file_metadata_downloading = try get_value "file_metadata_downloading" value_to_bool with _ -> false in
	let file_metadata_chunks = try get_value "file_metadata_chunks" (value_to_array value_to_string) with _ -> Array.make 20 "" in
	let file_private = try get_value "file_private" value_to_bool with _ -> false in
	(* useless old file support? *)
	(*	| Not_found -> false
		| _ -> try get_value "file_private" value_to_int64 <> 0L with _ -> false
	in*)
	(* end loading options *)

	(* if we saved to files.ini we should take that and not .torrent data *)
	(*let file_id, torrent, torrent_diskname =
	try
		let torrent_diskname = get_value "file_torrent_name" value_to_string in
		let s = File.to_string torrent_diskname in
		let file_id, torrent = BTTorrent.decode_torrent s in
		file_id, torrent, torrent_diskname
	with _ ->
        let torrent = {
            torrent_name = file_name;
            torrent_filename = "";
            torrent_name_utf8 = file_name;
            torrent_comment = file_comment;
            torrent_pieces = file_chunks;
            torrent_piece_size = file_piece_size;
            torrent_files = file_files;
            torrent_length = file_size;
            torrent_created_by = file_created_by;
            torrent_creation_date = file_creation_date;
            torrent_modified_by = file_modified_by;
            torrent_encoding = file_encoding;
            torrent_private = file_private;
			(*torrent_nodes = file_nodes; *)
            torrent_announce = (match file_trackers with
              | h::q -> h
              | [] -> "");
            torrent_announce_list = file_trackers;
          } in
        let torrent_diskname = Filename.concat downloads_directory
            (file_name ^ ".torrent") in
        file_id, torrent, torrent_diskname
	in*)

	(* bTGlobals change here: new_file is not good. *)
	(*let file = new_file file_id torrent torrent_diskname
               file_temp file_state user group in*)
	(*let file_uploaded = try
      value_to_int64 (List.assoc "file_uploaded" assocs)
    with _ -> zero
	in*)
	(*file.file_uploaded <- file_uploaded;*)
	(* new new_file here *)
	let file =
	try
		Hashtbl.find files_by_uid file_id
		(* if we find it already, should we update it? *)
	with Not_found -> begin
		let file_fd = create_temp_file file_temp file_files file_state in
		let rec file = {
			file_file = file_impl;
			file_piece_size = file_piece_size;
			file_id = file_id;
			file_name = file_name;
			file_comment = file_comment;
			file_created_by = file_created_by;
			file_creation_date = file_creation_date;
			file_modified_by = file_modified_by;
			file_encoding = file_encoding;
			file_swarmer = None;  (* not saved *)
			file_clients = Hashtbl.create 113;  (* not saved *)
			file_clients_num = 0;  (* not saved *)
			file_chunks = file_chunks;
			file_files = (List.map (fun (file,size) -> (file,size,None)) file_files);
			file_blocks_downloaded = []; (* not saved *)
			file_uploaded = file_uploaded;
			file_torrent_diskname = file_torrent_diskname;
			file_trackers = []; (* will set trackers later, from list *)
			file_tracker_connected = false; (* not saved *)
			file_completed_hook = (fun _ -> ()); (* not saved *)
			file_shared = None; (* not saved *)
			file_session_uploaded = Int64.zero; (* not saved *)
			file_session_downloaded = Int64.zero; (* not saved *)
			file_last_dht_announce = 0;  (* not saved, we should? *)
			file_metadata_size = file_metadata_size;
			file_metadata_piece = file_metadata_piece;
			file_metadata_downloading = file_metadata_downloading;
			file_metadata_chunks = file_metadata_chunks;
			file_private = file_private;
		} and file_impl =  {
			(dummy_file_impl ()) with
			impl_file_owner = user;
			impl_file_group = group;
			impl_file_fd = Some file_fd;
			impl_file_size = file_size;
			impl_file_downloaded = Int64.zero; (* should be updated later *)
			impl_file_val = file;
			impl_file_ops = file_ops;
			impl_file_age = last_time (); (* should we load age? *)
			impl_file_best_name = file_name;
		}
		in
		if file_trackers <> [] then
			set_trackers file file_trackers
		else
			set_trackers file [""]; (* in this case torrent announce is head, null *)
		if file_state <> FileShared then begin
			let kernel = CommonSwarming.create_swarmer file_temp (file.file_file.impl_file_size) in
			let swarmer = CommonSwarming.create kernel (as_file file) file.file_piece_size in
			file.file_swarmer <- Some swarmer;
			CommonSwarming.set_verified swarmer (fun _ num ->
				file.file_blocks_downloaded <- (num) :: file.file_blocks_downloaded;
				file_must_update file;
				(*Automatically send Have to ALL clients once a piece is verified:
				* useful in determining which piece is rare
				* whe should not check if client can be interested (?)*)
				Hashtbl.iter (fun _ c ->
					if c.client_registered_bitfield then
						begin
							match c.client_bitmap with
							| None -> ()
							| Some bitmap ->
								if not (Bitv.get bitmap num) then
									send_client c (Have (Int64.of_int num));
							check_if_interesting file c
						end
				) file.file_clients
			);
			CommonSwarming.set_verifier swarmer (Verification
				(Array.map (fun sha1 -> Sha1 sha1) file.file_chunks));
		end;
		current_files := file :: !current_files;
		Hashtbl.add files_by_uid file_id file;
		file_add file_impl file_state;
		must_share_file file;
		file (* todo: check rec *)
	end;
	in
	(* end of new_file function *)
	
	lprintf_nl "value_to_file call for: %s" file.file_name;
	(match file.file_swarmer with
		| None -> ()
		| Some swarmer -> CommonSwarming.value_to_frontend swarmer assocs;
	);
(*
  (try
      ignore
        (get_value  "file_sources" (
          value_to_list (ClientOption.of_value file)))
    with e ->
        lprintf_nl "Exception %s while loading sources"
          (Printexc2.to_string e);
  );
*)
	as_file file

(* file_to_value saves files in files.ini?
*  associated to frontend_to_value (commonSwarmer.ml) and file_to_option (commonFile.ml)
* lista di associazioni, nome -> valore
* called two times on mldonkey start, why?
*)
let file_to_value file =
	let () = lprintf_nl "file_to_value call for: %s" file.file_name; in
	try
	let assocs =
	[
		"file_temp", string_to_value (Unix32.filename (file_fd file));
		"file_piece_size", int64_to_value (file.file_piece_size);
		"file_id", string_to_value (Sha1.to_string file.file_id);
        "file_name", string_to_value file.file_name;
		"file_comment", string_to_value file.file_comment;
		"file_created_by", string_to_value file.file_created_by;
		"file_creation_date", int64_to_value (file.file_creation_date);
		"file_modified_by", string_to_value file.file_modified_by;
		"file_encoding", string_to_value file.file_encoding;
		(* file_swarmer *)
		(* file_clients: we save client id.
		* we should put some limit?
		*)
		"file_clients", (list_to_value string_to_value)
		(Hashtbl.fold (fun k v acc -> (Sha1.to_string v.client_uid) :: acc) file.file_clients []);
		(* file_clients_num *)
		"file_hashes", array_to_value (to_value Sha1.option) file.file_chunks;
		"file_files", list_to_value (fun (name, p1, _) ->
            SmallList [string_to_value name; int64_to_value p1])
        file.file_files;
		(* file_blocks_downloaded *)
        "file_uploaded", int64_to_value (file.file_uploaded);
		"file_torrent_name", string_to_value (file.file_torrent_diskname);
        "file_trackers", (list_to_value string_to_value)
        (List.map (fun t -> show_tracker_url t.tracker_url) file.file_trackers);
		(* file_tracker_connected = false *)
		(* file_completed_hook *)
		(* file_shared *)
		(* file_session_uploaded *)
		(* file_session_downloaded *)
		(* file_last_dht_announce = 0L? *)
		(* saving metadata is useful for magnet links,
		in the case we shutdown client before full metadata received *)
		"file_metadata_size", int64_to_value (file.file_metadata_size);
		"file_metadata_piece", int64_to_value (file.file_metadata_piece);
		"file_metadata_downloading", bool_to_value (file.file_metadata_downloading);
		"file_metadata_chunks", (array_to_value string_to_value) (file.file_metadata_chunks);
		"file_private", bool_to_value (file.file_private);
(* OK, but I still don't like the idea of forgetting all the clients.
We should have a better strategy, ie rating the clients and connecting
to them depending on the results of our last connections. And then,
if we could not download enough in the last interval, ask the tracker to
send us more clients.

    "file_sources",
    list_to_value "BT Sources" (fun c ->
        ClientOption.to_value c) sources
;
  *)
	]
    in
    match file.file_swarmer with
    | None -> assocs
    | Some swarmer -> CommonSwarming.frontend_to_value swarmer assocs
  with
    e -> lprintf_file_nl (as_file file) "exception %s in file_to_value"
        (Printexc2.to_string e); raise e


let save_config () =
  Options.save_with_help bittorrent_ini

let config_files_loaded = ref false

let load _ =
  begin try Options.load bt_stats_ini with Sys_error _ -> () end;
  begin try Options.load bt_dht_ini with Sys_error _ -> () end;
  check_client_uid ();
  config_files_loaded := true

let guptime = define_option bt_stats_section ["guptime"] "" int_option 0

let new_stats_array () =
  Array.init brand_count (fun _ ->
      { dummy_stats with brand_seen = 0 })

let gstats_array = define_option bt_stats_section ["stats"] ""
    (array_option StatsOption.t) (new_stats_array ())

let _ =
  option_hook gstats_array (fun _ ->
      let old_stats = !!gstats_array in
      let old_len = Array.length old_stats in
      if old_len <> brand_count then
        let t = new_stats_array () in
        for i = 0 to old_len - 1 do
          t.(i) <- old_stats.(i)
        done;
        gstats_array =:= t
  )

let diff_time = ref 0

let sources_loaded = ref false  (* added 2.5.24 *)

let save _ =
  if !config_files_loaded then begin
(*  lprintf "SAVING SHARED FILES AND SOURCES\n"; *)
      guptime =:= !!guptime + (last_time () - start_time) - !diff_time;
      diff_time := (last_time () - start_time);
      Options.save_with_help bt_stats_ini;
      Options.save_with_help bt_dht_ini;
    end
(*  lprintf "SAVED\n";  *)

let guptime () = !!guptime - !diff_time

let rec update_options () =
  let update v =
      lprintf_nl "Updating options to version %i" v;
      options_version =:= v;
      update_options ()
  in

  (* (default: router.bittorrent.com:6881, router.utorrent.com:6881, dht.transmissionbt.com:6881, dht.libtorrent.org:25401) *)
  (*session.add_dht_router("router.utorrent.com", 6881)
session.add_dht_router("router.bittorrent.com", 6881)
session.add_dht_router("dht.transmissionbt.com", 6881)
session.add_dht_router("router.bitcomet.com", 6881)
session.add_dht_router("dht.aelitis.com", 6881)*)
	match !!options_version with
	| 0 ->
      let present = ref false in
      (* drop obsolete addresses, add new *)
      dht_bootstrap_nodes =:= List.filter (function
        | "router.utorrent.com", 6881 -> false
        | "router.transmission.com", 6881 -> false
        | "router.bittorrent.com", 8991 -> present := true; true
        | _ -> true) !!dht_bootstrap_nodes;
      if not !present then
        dht_bootstrap_nodes =:= ("router.bittorrent.com", 8991) :: !!dht_bootstrap_nodes;
      update 1
	| 1 ->
		let present = ref false in
		dht_bootstrap_nodes =:= ("router.bittorrent.com", 6881) ::
		("router.bittorrent.com", 8991) ::
		("router.utorrent.com", 6881) ::
		("dht.transmissionbt.com", 6881) ::
		("dht.libtorrent.org", 25401 ) ::
		("router.bitcomet.com", 6881 ) ::
		("dht.aelitis.com", 6881 ) :: [];
		update 2
	| _ -> ()

let () =
  network.op_network_file_of_option <- value_to_file;
  file_ops.op_file_to_option <- file_to_value;

  (* Shut up message "Network.save/load_complex_options not implemented by BitTorrent" *)
  network.op_network_load_complex_options <- load;
  network.op_network_save_complex_options <- save;
  network.op_network_update_options <- update_options;
  network.op_network_save_sources <- (fun _ -> ())
