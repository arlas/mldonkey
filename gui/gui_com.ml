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

(** Communicating with the mldonkey client. *)

module M = Gui_messages
module O = Gui_options
module G = Gui_global

let (!!) = Options.(!!)

let connection = ref None

let disconnect () = 
  match !connection with
    None -> ()
  | Some sock ->
      TcpBufferedSocket.close sock "user close";
      connection := None

let reconnect gui value_reader =
  (try disconnect () with _ -> ());
  let sock = TcpBufferedSocket.connect ""
      (try
        let h = Unix.gethostbyname 
            (if !!O.hostname = "" then Unix.gethostname () else !!O.hostname) in
        h.Unix.h_addr_list.(0)
      with 
        e -> 
          Printf.printf "Exception %s in gethostbyname" (Printexc.to_string e);
          print_newline ();
          try 
            Unix.inet_addr_of_string !!O.hostname
          with e ->
              Printf.printf "Exception %s in inet_addr_of_string" 
                (Printexc.to_string e);
              print_newline ();
              raise Not_found
      )
      !!O.port
      (fun _ _ -> ()) 
  in
  try
    connection := Some sock;
    TcpBufferedSocket.set_closer sock (fun _ _ -> 
        match !connection with
          None -> ()
        | Some s -> 
            if s == sock then begin
                connection := None;
              end
    );
    TcpBufferedSocket.set_max_write_buffer sock !!O.interface_buffer;
    TcpBufferedSocket.set_reader sock (
      TcpBufferedSocket.value_handler value_reader);
    gui#label_connect_status#set_text "Connecting"
  with e ->
      Printf.printf "Exception %s in connecting" (Printexc.to_string e);
      print_newline ();
      TcpBufferedSocket.close sock "error";
      connection := None

let send t =
  match !connection with
    None -> 
      Printf.printf "Message not sent since not connected";
      print_newline ();
  | Some sock ->
      TcpBufferedSocket.value_send sock (t : Gui_proto.from_gui)  

let receive () =
  match !connection with
    None -> 
      Printf.printf "Nothing read since not connected";
      print_newline ();
  | Some sock ->
      ()
