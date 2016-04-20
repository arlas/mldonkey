
open DriverInteractive
open GuiTypes
open CommonTypes

open ExtLib

module T = DriverApi_t

let of_file f =
  let f = CommonFile.file_info f in
  {
    T.file_id = f.file_num;
    file_name = f.file_name;
    file_size = f.file_size;
    file_downloaded = f.file_downloaded;
    file_download_rate = f.file_download_rate;
    file_network = net_shortname f;
    file_state = f.file_state;
  }

let of_search { CommonTypes.search_num; search_string; search_waiting; search_nresults; } =
    { T.search_id = search_num;
      search_query = search_string;
      search_waiting = search_waiting;
      search_results = search_nresults;
    }

let of_client { GuiTypes.client_software; client_os; client_release; client_file_queue;
        client_total_uploaded; client_total_downloaded; client_session_uploaded;
        client_session_downloaded; } =
    { T.client_software; client_os; client_version=client_release; client_queue_length = List.length client_file_queue;
      client_total_uploaded; client_total_downloaded; client_session_uploaded;
      client_session_downloaded;
    }

let strings_of_tags =
  List.filter_map (fun { tag_name; tag_value; } ->
    match tag_name with
    | Field_Availability -> None
    | _ ->
      Some (match tag_value with String s -> s | (Uint64 i | Fint64 i)  -> Int64.to_string i | _ -> "???")
  )

let of_result (rs,r,avail) =
  { T.result_id = r.result_num;
    result_size = r.result_size;
    result_avail = avail;
    result_downloaded = r.result_done;
    result_comment = r.result_comment;
    result_names = r.result_names;
    result_tags = strings_of_tags r.result_tags;
    result_uids = List.map Uid.to_string r.result_uids;
  }