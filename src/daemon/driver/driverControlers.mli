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

val dollar_escape : CommonTypes.ui_conn -> bool -> string -> string
val eval : bool ref -> string -> CommonTypes.ui_conn -> unit

  
val telnet_handler : TcpServerSocket.t -> TcpServerSocket.event -> unit
val chat_handler : TcpServerSocket.t -> TcpServerSocket.event -> unit
val create_http_handler : unit -> unit

val check_calendar : unit -> unit

(* should not be here ... *)
val text_of_html : string -> string
