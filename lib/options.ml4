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


    (* Simple options:
  This will enable very simple configuration, by a mouse-based configurator.
  Options will be defined by a special function, which will also check
  if a value has been provided  by the user in its .gwmlrc file.
  The .gwmlrc will be created by a dedicated tool, which could be used
  to generate both .gwmlrc and .efunsrc files.

Note: this is redundant, since such options could also be better set
in the .Xdefaults file (using Xrm to load them). Maybe we should merge
both approaches in a latter release.
  
    *)

open Printf2

type option_value =
  Module of option_module
| StringValue of string
| IntValue of int64
| FloatValue of float
| List of option_value list
| SmallList of option_value list
| OnceValue of option_value
| DelayedValue of (out_channel -> string -> unit)
  
and option_module = (string * option_value) list
;;

exception SideEffectOption
exception OptionNotFound
  
type 'a option_class =
  { class_name : string;
    from_value : option_value -> 'a;
    to_value : 'a -> option_value;
    mutable class_hooks : ('a option_record -> unit) list }
  
and 'a option_record =
  { option_name : string list;
    option_class : 'a option_class;
    mutable option_value : 'a;
    option_help : string;
	option_default : 'a;
    mutable option_hooks : (unit -> unit) list;
    mutable string_wrappers : (('a -> string) * (string -> 'a)) option;
    option_file : options_file;
  }
  
and options_file = {
    mutable file_name : string; 
    mutable file_header_options : Obj.t option_record list;
    mutable file_options : Obj.t option_record list;
    mutable file_rc : option_module;
    mutable file_pruned : bool;
  }
;;

let create_options_file name =
  {
    file_name = name;
    file_header_options = [];
    file_options =[];
    file_rc = [];
    file_pruned = false;
  }
  
let set_options_file opfile name = opfile.file_name <- name
let print_options_not_found = ref false

let
  define_option_class
    (class_name : string)
    (from_value : option_value -> 'a)
    (to_value : 'a -> option_value) =
  let c =
    {class_name = class_name; 
      from_value = from_value; 
      to_value = to_value;
     class_hooks = []}
  in
  c
;;  


let rec find_value list m =
  match list with
    [] -> raise Not_found
  | name :: tail ->
      let m = List.assoc name m in
      match m, tail with
        _, [] -> m
      | Module m, _ :: _ -> find_value tail m
      | _ -> raise Not_found
;;

let find_value list m =
  try
    find_value list m
  with _ -> raise OptionNotFound

let prune_file file =
  file.file_pruned <- true

let
  define_simple_option normalp
    (opfile : options_file)
  (option_name : string list)
  (option_help : string)
  (option_class : 'a option_class)
  (default_value : 'a) =
  let o =
    {option_name = option_name; 
      option_help = option_help;
      option_class = option_class; 
      option_value = default_value;
	  option_default = default_value;
      string_wrappers = None;
      option_hooks = []; 
      option_file = opfile; }
  in
  if normalp then
    opfile.file_options <- (Obj.magic o : Obj.t option_record) ::
    opfile.file_options
  else
    opfile.file_header_options <- (Obj.magic o : Obj.t option_record) ::
    opfile.file_header_options;
  o.option_value <-
    begin try o.option_class.from_value (find_value option_name 
        opfile.file_rc) with
      OptionNotFound -> default_value
    | e ->
        lprintf "Options.define_option, for option %s: "
          (match option_name with
             [] -> "???"
           | name :: _ -> name);
        lprintf "%s" (Printexc2.to_string e);
        lprint_newline ();
        default_value
    end;
  o
;;


let define_header_option
    opfile option_name option_help option_class default_value =
  define_simple_option false opfile option_name option_help option_class
    default_value

let define_option opfile option_name option_help option_class default_value =
  define_simple_option true opfile option_name option_help option_class
    default_value

  
open Genlex2;;

let once_values = Hashtbl.create 13
let once_values_counter = ref 0
let once_values_rev = Hashtbl.create 13

let lexer = make_lexer ["="; "{"; "}"; "["; "]"; ";"; "("; ")"; ","; "."; "@"];;
  
let rec parse_gwmlrc = parser
| [< id = parse_id; 'Kwd "="; v = parse_option ; 
      eof = parse_gwmlrc >] -> (id, v) :: eof
| [< >] -> []

    
and parse_option = parser
| [< 'Kwd "{"; v = parse_gwmlrc; 'Kwd "}" >] -> Module v
| [< 'Ident s >] -> StringValue s
| [< 'String s >] -> StringValue s
| [< 'Int i >] -> IntValue i
| [< 'Float f >] -> FloatValue  f
| [< 'Kwd "@"; 'Int i; v = parse_once_value i >] -> OnceValue v
| [< 'Char c >] -> StringValue (let s = String.create 1 in s.[0] <- c; s)    
| [< 'Kwd "["; v = parse_list >] -> List v
| [< 'Kwd "("; v = parse_list >] -> List v

and parse_once_value i = parser
    [< 'Kwd "@" >] -> 
    begin
      try Hashtbl.find once_values i with Not_found ->
          lprintf "Error in saved file: @%Ld@ not defined" i;
          lprint_newline ();
          exit 2
    end
|  [< 'Kwd "="; v = parse_option >] ->
    begin
      Hashtbl.add once_values i v;
      v
    end
    
and parse_id = parser
    [< 'Ident s >] -> s
|   [< 'String s >] -> s

and parse_list = parser
    [< 'Kwd ";"; v = parse_list >] -> v
|   [< 'Kwd ","; v = parse_list >] -> v
|   [< 'Kwd "."; v = parse_list >] -> v
|   [< v = parse_option; t = parse_list >] -> v :: t
|   [< 'Kwd "]" >] -> []
|   [< 'Kwd ")" >] -> []

let exec_hooks o =
  List.iter
    (fun f ->
       try f () with
         _ -> ())
    o.option_hooks
;;  

let exec_chooks o =
  List.iter
    (fun f ->
       try f o with
         _ -> ())
    o.option_class.class_hooks
;;  
  
let really_load filename header_options options =
  let temp_file = filename ^ ".tmp" in
  if Sys.file_exists temp_file then begin
      Printf.eprintf 
        "File %s exists\n" temp_file;
      Printf.eprintf 
        "An error may have occurred during previous configuration save.\n";
      Printf.eprintf 
        "Please, check your configurations files, and rename/remove this file\n";
      Printf.eprintf "before restarting\n";
      exit 1
    end else
  let ic = open_in filename in
  try
    let s = Stream.of_channel ic in
    try
      let stream = lexer s in
      Hashtbl.clear once_values;
      let list =
        try parse_gwmlrc stream with
          e ->
            Printf.eprintf "Syntax error while parsing file %s at pos %d\n"
              filename (Stream.count s);
            exit 2
      in
      Hashtbl.clear once_values;
      
      let affect_option o =
        try
          (try
              o.option_value <-
                o.option_class.from_value (find_value o.option_name list);
            with SideEffectOption -> ());
          exec_chooks o;
          exec_hooks o
        with
          SideEffectOption -> ()
        | OptionNotFound ->
            if !print_options_not_found then begin
                lprintf "Option ";
                List.iter (fun s -> lprintf "%s " s) o.option_name;
                lprintf "not found in %s" filename;
                lprint_newline ()
              end
        | e ->
            lprintf "Exception: %s while handling option:"
              (Printexc2.to_string e); 
            List.iter (fun s -> lprintf "%s " s) o.option_name;
            lprint_newline ();
            lprintf "  in %s" filename; lprint_newline ();
            lprintf "Aborting."; lprint_newline ();
            exit 2
      in            
      List.iter affect_option header_options;
      List.iter affect_option options;
      close_in ic;
      list
    with
      e ->
        lprintf "Error %s in %s" (Printexc2.to_string e) filename;
        lprint_newline ();
        []
  with e ->
      close_in ic; raise e
;;


let exit_exn = Exit;;


let unsafe_get = String.unsafe_get
external is_printable: char -> bool = "is_printable"
let unsafe_set = String.unsafe_set
  
let escaped s =
  let n = ref 0 in
  for i = 0 to String.length  s - 1 do
    n := !n +
      (match unsafe_get s i with
        '"' | '\\' -> 2
      | '\n' | '\t' -> 1
      | c -> if is_printable c then 1 else 4)
  done;
  if !n = String.length  s then s else begin
      let s' = String.create !n in
      n := 0;
      for i = 0 to String.length  s - 1 do
        begin
          match unsafe_get s i with
            ('"' | '\\') as c ->
              unsafe_set s' !n '\\'; incr n; unsafe_set s' !n c
          | ('\n' | '\t' ) as c -> 
              unsafe_set s' !n c
          | c ->
              if is_printable c then
                unsafe_set s' !n c
              else begin
                  let a = int_of_char c in
                  unsafe_set s' !n '\\';
                  incr n;
                  unsafe_set s' !n (char_of_int (48 + a / 100));
                  incr n;
                  unsafe_set s' !n (char_of_int (48 + (a / 10) mod 10));
                  incr n;
                  unsafe_set s' !n (char_of_int (48 + a mod 10))
                end
        end;
        incr n
      done;
      s'
    end
    
let safe_string s =
  if s = "" then "\"\""
  else
    try
      match s.[0] with
        'a'..'z' | 'A'..'Z' ->
          for i = 1 to String.length s - 1 do
            match s.[i] with
              'a'..'z' | 'A'..'Z' | '_' | '0'..'9' -> ()
            | _ -> raise exit_exn
          done;
        s
    | _ ->
        if Int64.to_string (Int64.of_string s) = s ||
          string_of_float (float_of_string s) = s then
          s
        else raise exit_exn
  with
    _ -> Printf.sprintf "\"%s\"" (escaped s)
;;

let with_help = ref false;;

let tabulate s = String2.replace s '\n' "\n\t"

let rec save_module indent oc list =
  let subm = ref [] in
  List.iter
    (fun (name, help, value) ->
      match name with
        [] -> assert false
      | [name] ->
          if !with_help && help <> "" then
            Printf.fprintf oc "\n\t(* %s *)\n" (tabulate help);
          Printf.fprintf oc "%s %s = " indent (safe_string name);
          save_value indent oc value;
          Printf.fprintf oc "\n"
      | m :: tail ->
          let p =
            try List.assoc m !subm with
              e -> 
(*
                lprintf "Exception %s in Options.save_module" 
		  (Printexc2.to_string e); lprint_newline ();
*)
                let p = ref [] in subm := (m, p) :: !subm; p
          in
          p := (tail, help, value) :: !p)
    list;
  List.iter
    (fun (m, p) ->
      Printf.fprintf oc "%s %s = {\n" indent (safe_string m);
      save_module (indent ^ "  ") oc !p;
      Printf.fprintf oc "%s}\n" indent)
  !subm
  
and save_list indent oc list =
  match list with
    [] -> ()
  | [v] -> save_value indent oc v
  | v :: tail ->
      save_value indent oc v; Printf.fprintf oc ", "; save_list indent oc tail
      
and save_list_nl indent oc list =
  match list with
    [] -> ()
  | [v] -> Printf.fprintf oc "\n%s" indent; save_value indent oc v
  | v :: tail ->
      Printf.fprintf oc "\n%s" indent;
      save_value indent oc v;
      Printf.fprintf oc ";";
      save_list_nl indent oc tail
      
and save_value indent oc v =
  match v with
    StringValue s -> Printf.fprintf oc "%s" (safe_string s)
  | IntValue i -> Printf.fprintf oc "%s" (Int64.to_string i)
  | FloatValue f -> Printf.fprintf oc "%f" f
  | List l ->
      Printf.fprintf oc "[";
      save_list_nl (indent ^ "  ") oc l;
      Printf.fprintf oc "]"
  | DelayedValue f -> f oc indent
  | SmallList l ->
      Printf.fprintf oc "(";
      save_list (indent ^ "  ") oc l;
      Printf.fprintf oc ")"
  | Module m -> 
      Printf.fprintf oc "{";
      save_module_fields (indent ^ "  ") oc m;
      Printf.fprintf oc "}"
  | OnceValue v ->
      begin
        try 
          let i = Hashtbl.find once_values_rev v in
          Printf.fprintf oc "@%Ld@" i
        with Not_found ->
            incr once_values_counter;
            let i = Int64.of_int !once_values_counter in
            Hashtbl.add once_values_rev v i;
            Printf.fprintf oc "@%Ld = " i;
            save_value indent oc v   
      end
      
and save_module_fields indent oc m =
  match m with
    [] -> ()
  | (name, v) :: tail ->
(*      lprintf "Saving %s" name; lprint_newline (); *)
      Printf.fprintf oc "%s %s = " indent (safe_string name);
      save_value indent oc v;
      Printf.fprintf oc "\n";
      save_module_fields indent oc tail
;;


let options_file_name f = f.file_name

let load opfile =
  try opfile.file_rc <- really_load opfile.file_name
      opfile.file_header_options opfile.file_options with
    Not_found -> 
      lprintf "No %s found" opfile.file_name; lprint_newline ()
;;

let append opfile filename =
  try opfile.file_rc <-
      really_load filename 
    opfile.file_header_options opfile.file_options @ opfile.file_rc with
    Not_found -> 
      lprintf "No %s found" filename; lprint_newline ()
;;
      
let ( !! ) o = o.option_value;;
let ( =:= ) o v = o.option_value <- v; exec_chooks o; exec_hooks o;;
    
let rec value_to_string v =
  match v with
    StringValue s -> s
  | IntValue i -> Int64.to_string i
  | FloatValue f -> string_of_float f
  | OnceValue v -> value_to_string v
  | _ -> "NaS" 
;;
      
let string_to_value s = StringValue s;;
  
let rec value_to_int64 v =
  match v with
    StringValue s -> Int64.of_string s
  | IntValue i -> i
  | FloatValue i -> Int64.of_float i
  | OnceValue v -> value_to_int64 v
  | _ -> failwith "Options: not an int option"
;;

let value_to_int v = Int64.to_int (value_to_int64 v);;
let int_to_value i = IntValue (Int64.of_int i);;
let int64_to_value i = IntValue i;;

(* The Pervasives version is too restrictive *)
let bool_of_string s =
  match String.lowercase s with
    "true" -> true
  | "false" -> false
  | "yes" -> true
  | "no" -> false
  | "y" -> true
  | "n" -> false
  | _ -> invalid_arg "bool_of_string"
;;

let rec value_to_bool v =
  match v with
    StringValue s -> bool_of_string s
  | IntValue v when v = Int64.zero -> false
  | IntValue v when v = Int64.one -> true
  | OnceValue v -> value_to_bool v
  | _ -> failwith "Options: not a bool option"
;;
let bool_to_value i = StringValue (string_of_bool i);;

let rec value_to_float v =
  match v with
    StringValue s -> float_of_string s
  | FloatValue f -> f
  | OnceValue v -> value_to_float v
  | _ -> failwith "Options: not a float option"
;; 

let float_to_value i = FloatValue i;;

let rec value_to_string2 v =
  match v with
    List [s1; s2] | SmallList [s1;s2] -> 
      value_to_string s1, value_to_string s2
  | OnceValue v -> value_to_string2 v
  | _ -> failwith "Options: not a string2 option"
;;

let string2_to_value (s1, s2) = SmallList [StringValue s1; StringValue s2];;

let rec value_to_list v2c v =
  match v with
    List l | SmallList l -> List.rev (List.rev_map v2c l)
  | OnceValue v -> value_to_list v2c v
  | StringValue s -> failwith (Printf.sprintf 
        "Options: not a list option (StringValue [%s])" s)
  | FloatValue _ -> failwith "Options: not a list option (FloatValue)"
  | IntValue _ -> failwith "Options: not a list option (IntValue)"
  | Module _ -> failwith "Options: not a list option (Module)"
  | DelayedValue _ -> failwith "Options: not a list option (Delayed)"
      ;;

let rec value_to_hasharray v2c v =
  match v with
    List l ->  
      begin
	let hash=Array.init 256 (fun _ -> Hashtbl.create 10) in
        List.iter ( fun a -> let (num, md4, peer) = v2c a in 
            Hashtbl.add hash.(num) md4 peer) (List.rev l);
	hash
      end
  | OnceValue v -> value_to_hasharray v2c v
  | _ -> failwith (Printf.sprintf "Options: not a list option for list2")
;;

let rec value_to_safelist v2c v =
  match v with
    List l | SmallList l -> 
      let rec iter list left =
        match left with
          [] -> list
        | x :: tail ->
            let list = try (v2c x) :: list with _ -> list
            in
            iter list tail
      in
      List.rev (iter [] (List.rev l))
  | OnceValue v -> value_to_safelist v2c v
  | StringValue s -> failwith (Printf.sprintf 
        "Options: not a list option (StringValue [%s])" s)
  | FloatValue _ -> failwith "Options: not a list option (FloatValue)"
  | IntValue _ -> failwith "Options: not a list option (IntValue)"
  | Module _ -> failwith "Options: not a list option (Module)"
  | DelayedValue _ -> failwith "Options: not a list option (Delayed)";;

let rec value_to_intmap f v2c v =
  match v with
    List l | SmallList l -> 
      let rec iter map left =
        match left with
          [] -> map
        | x :: tail ->
            let map = try 
                let v = v2c x in
                let num = f v in
                Intmap.add num v map with _ -> map
            in
            iter map tail
      in
      iter Intmap.empty l
  | OnceValue v -> value_to_intmap f v2c v
  | StringValue s -> failwith (Printf.sprintf 
        "Options: not a list option (StringValue [%s])" s)
  | FloatValue _ -> failwith "Options: not a list option (FloatValue)"
  | IntValue _ -> failwith "Options: not a list option (IntValue)"
  | Module _ -> failwith "Options: not a list option (Module)"
  | DelayedValue _ -> failwith "Options: not a list option (Delayed)";;

let rec value_to_listiter v2c v =
  match v with
    List l | SmallList l -> List.iter (fun v -> 
          try ignore(v2c v) with SideEffectOption -> ()) l; 
      raise SideEffectOption
  | OnceValue v -> value_to_listiter v2c v
  | StringValue s -> failwith (Printf.sprintf 
        "Options: not a list option (StringValue [%s])" s)
  | FloatValue _ -> failwith "Options: not a list option (FloatValue)"
  | IntValue _ -> failwith "Options: not a list option (IntValue)"
  | Module _ -> failwith "Options: not a list option (Module)"
  | DelayedValue _ -> failwith "Options: not a list option (Delayed)";;

let rec convert_list name c2v l res =
  match l with
    [] -> List.rev res
  | v :: list -> 
      match 
        try
          Some (c2v v)
        with e -> 
            lprintf "Exception %s in Options.convert_list for %s" (
              Printexc2.to_string e) name;
            lprint_newline ();
            None
      with
        None ->
          convert_list name c2v list res
      | Some v -> convert_list name c2v list (v :: res)

let option_to_value c2v o =
  match o with
    None -> StringValue ""
  | Some c -> c2v c

let rec value_to_option v2c v =
  match v with
  | StringValue "" -> None
  | OnceValue v -> value_to_option v2c v
  | _ -> Some (v2c v)

let save_delayed_list_value oc indent c2v =
  let indent = indent ^ "  " in
  (fun v ->
      Printf.fprintf oc "\n%s" indent;
      save_value indent oc (c2v v);
      Printf.fprintf oc ";";
  )
  
let list_to_value name c2v l =
  DelayedValue (fun oc indent ->
      Printf.fprintf oc "[";
      List.iter (save_delayed_list_value oc indent c2v) l;
      Printf.fprintf oc "]"      
  )
  
let intmap_to_value name c2v map =
  DelayedValue (fun oc indent ->
      let save = save_delayed_list_value oc indent c2v in
      Printf.fprintf oc "[";
      Intmap.iter (fun _ v -> save v) map;
      Printf.fprintf oc "]"      
  )
  
let hasharray_to_value x c2v l =
  DelayedValue (fun oc indent ->
      Printf.fprintf oc "[";
      let save = save_delayed_list_value oc indent c2v in
      for i=0 to Array.length l - 1 do   
        Hashtbl.iter (fun a b -> save (0,x,b)) l.(i);
      done;
      Printf.fprintf oc "]"      
  )

let smalllist_to_value name c2v l =
  SmallList (convert_list name c2v l [])

let value_to_path v =
  List.map Filename2.from_string
    (let rec iter v = 
      match v with
      | StringValue s -> Filepath.string_to_path s
      | OnceValue v -> iter v
      | List l ->
          List.map
            (fun v ->
              match v with
                StringValue s -> Filename2.from_string s
              | _ -> failwith "Options: not a path option")
          l
      | _ -> failwith "Options: not path bool option"
    in iter v)
;;
  
let path_to_value list =
  StringValue (Filepath.path_to_string (List.map Filename2.to_string list))
;;


let string_option =
  define_option_class "String" value_to_string string_to_value
;;
let color_option =
  define_option_class "Color" value_to_string string_to_value
;;
let font_option = define_option_class "Font" value_to_string string_to_value;;
  
let int_option = define_option_class "Int" value_to_int int_to_value;;
let int64_option = define_option_class "Int64" value_to_int64 int64_to_value;;

  
let bool_option = define_option_class "Bool" value_to_bool bool_to_value;;
let float_option = define_option_class "Float" value_to_float float_to_value;;
let path_option = define_option_class "Path" value_to_path path_to_value;;

let string2_option =
  define_option_class "String2" value_to_string2 string2_to_value
;;

let option_option cl =
  define_option_class (cl.class_name ^ " Option")
  (value_to_option cl.from_value)
  (option_to_value cl.to_value)

let list_option cl =
  define_option_class (cl.class_name ^ " List") (value_to_list cl.from_value)
    (list_to_value cl.class_name cl.to_value)
;;

let array_option cl =
  define_option_class (cl.class_name ^ " Array") 
  (fun v ->
      Array.of_list (value_to_list cl.from_value v))
  (fun v ->
      list_to_value cl.class_name cl.to_value (Array.to_list v))

let hasharray_option x cl =
  define_option_class "Hashtable array" (value_to_hasharray cl.from_value) 
    (hasharray_to_value x cl.to_value)
;;

let safelist_option cl =
  define_option_class (cl.class_name ^ " List") 
  (value_to_safelist cl.from_value)
  (list_to_value cl.class_name cl.to_value)
;;

let intmap_option f cl =
  define_option_class (cl.class_name ^ " Intmap") 
  (value_to_intmap f cl.from_value)
  (intmap_to_value cl.class_name cl.to_value)
;;

let listiter_option cl =
  define_option_class (cl.class_name ^ " List") (value_to_listiter cl.from_value)
    (list_to_value cl.class_name cl.to_value)
;;

let smalllist_option cl =
  define_option_class (cl.class_name ^ " List") (value_to_list cl.from_value)
    (smalllist_to_value cl.class_name cl.to_value)
;;

let to_value cl = cl.to_value;;
let from_value cl = cl.from_value;;
  
let rec value_to_sum l v =
  match v with
    StringValue s -> List.assoc s l
  | OnceValue v -> value_to_sum l v
  | _ -> failwith "Options: not a sum option"
;;
  
let sum_to_value l v = StringValue (List.assq v l);;
  
let sum_option l =
  let ll = List.map (fun (a1, a2) -> a2, a1) l in
  define_option_class "Sum" (value_to_sum l) (sum_to_value ll)
;;

let option_to_value o = 
  o.option_name, o.option_help,
  (try 
      o.option_class.to_value o.option_value 
    with
      e ->
        lprintf "Error while saving option \"%s\": %s"
          (try List.hd o.option_name with
            _ -> "???")
        (Printexc2.to_string e);
        lprint_newline ();
        StringValue "")
  
let save opfile =
  let filename = opfile.file_name in
  let temp_file = filename ^ ".tmp" in
  let old_file = filename ^ ".old" in
  let oc = open_out temp_file in
  try
    once_values_counter := 0;
    Hashtbl.clear once_values_rev;
    save_module "" oc
      (List.map option_to_value
      (opfile.file_header_options @ opfile.file_options));
    if not opfile.file_pruned then begin
        let rem = ref [] in
        Printf.fprintf oc
          "\n(*\n The following options are not used (errors, obsolete, ...) \n*)\n";
        List.iter
          (fun (name, value) ->
            try
              List.iter (fun list ->
                  List.iter
                    (fun o ->
                      match o.option_name with
                        n :: _ -> if n = name then raise Exit
                      | _ -> ())
                  list)
              [opfile.file_header_options;  opfile.file_options];
              rem := (name, value) :: !rem;
              Printf.fprintf oc "%s = " (safe_string name);
              save_value "  " oc value;
              Printf.fprintf oc "\n"
            with
              Exit -> ()
            | e -> 
                lprintf "Exception %s in Options.save" (
                  Printexc2.to_string e); lprint_newline ())
        opfile.file_rc;
        opfile.file_rc <- !rem;
      end;
    Hashtbl.clear once_values_rev;
    close_out oc;
    (try Unix2.rename filename old_file with _ -> ());
    (try Unix2.rename temp_file filename with _ -> ())
  with e ->
      close_out oc; raise e
;;

let save_with_help opfile =
  with_help := true;
  begin try save opfile with
    _ -> ()
  end;
  with_help := false
;;
  
let option_hook option f = option.option_hooks <- f :: option.option_hooks;;
  
let class_hook option_class f =
  option_class.class_hooks <- f :: option_class.class_hooks
;;

let rec iter_order f list =
  match list with
    [] -> ()
  | v :: tail -> f v; iter_order f tail
;;
  
let help oc opfile =
  List.iter
    (fun o ->
       Printf.fprintf oc "OPTION \"";
       begin match o.option_name with
         [] -> Printf.fprintf oc "???"
       | [name] -> Printf.fprintf oc "%s" name
       | name :: tail ->
           Printf.fprintf oc "%s" name;
           iter_order (fun name -> Printf.fprintf oc ":%s" name) o.option_name
       end;
       Printf.fprintf oc "\" (TYPE \"%s\"): %s\n   CURRENT: \n"
         o.option_class.class_name o.option_help;
      begin try
          once_values_counter := 0;
          Hashtbl.clear once_values_rev;

         save_value "" oc (o.option_class.to_value o.option_value)
       with
         _ -> ()
       end;
       Printf.fprintf oc "\n")
    opfile.file_options;
  flush oc
;;
  
    
let tuple2_to_value (c1, c2) (a1, a2) =
  SmallList [to_value c1 a1; to_value c2 a2]
;;
  
let rec value_to_tuple2 ((c1, c2) as cs) v =
  match v with
    List [v1; v2] -> from_value c1 v1, from_value c2 v2
  | SmallList [v1; v2] -> from_value c1 v1, from_value c2 v2
  | OnceValue v -> value_to_tuple2 cs v
  | List l | SmallList l ->
      lprintf "list of %d" (List.length l);
      lprint_newline ();
      failwith "Options: not a tuple2 list option"
  | _ -> failwith "Options: not a tuple2 option"
;;
  
let tuple2_option p =
  define_option_class "tuple2_option" (value_to_tuple2 p) (tuple2_to_value p)
;;
  
let tuple3_to_value (c1, c2, c3)  (a1, a2, a3) =
  SmallList [to_value c1 a1; to_value c2 a2; to_value c3 a3]
;;
let rec value_to_tuple3 ((c1, c2, c3) as cs) v =
  match v with
    List [v1; v2; v3] -> from_value c1 v1, from_value c2 v2, from_value c3 v3
  | SmallList [v1; v2; v3] ->
      from_value c1 v1, from_value c2 v2, from_value c3 v3
  | OnceValue v -> value_to_tuple3 cs v      
  | _ -> failwith "Options: not a tuple3 option"
;;
      
let tuple3_option p =
  define_option_class "tuple3_option" (value_to_tuple3 p) (tuple3_to_value p)
;;

let tuple4_to_value (c1, c2, c3, c4) (a1, a2, a3, a4) =
  SmallList [to_value c1 a1; to_value c2 a2; to_value c3 a3; to_value c4 a4]
;;
let rec value_to_tuple4 ((c1, c2, c3,c4) as cs) v =
  match v with
    List [v1; v2; v3;v4]
  | SmallList [v1; v2; v3;v4] ->
      from_value c1 v1, from_value c2 v2, from_value c3 v3, from_value c4 v4
  | OnceValue v -> value_to_tuple4 cs v
  | _ -> failwith "Options: not a tuple4 option"
;;
      
let tuple4_option p =
  define_option_class "tuple4_option" (value_to_tuple4 p) (tuple4_to_value p)
;;

      
let value_to_filename v =
  Filename2.from_string
    (match v with
       StringValue s -> s
     | _ -> failwith "Options: not a filename option")
;;
  
let filename_to_value v = StringValue (Filename2.to_string v);;
      
let filename_option =
  define_option_class "Filename" value_to_filename filename_to_value
;;

let shortname o = String.concat ":" o.option_name;;
let get_class o = o.option_class;;
let get_help o =
  let help = o.option_help in if help = "" then "No Help Available" else help
;;


let simple_options opfile =
  let list = ref [] in
  List.iter (fun o ->
      match o.option_name with
        [] | _ :: _ :: _ -> ()
      | [name] ->
          match o.option_class.to_value o.option_value with
            Module _ | SmallList _ | List _ -> 
              begin
                match o.string_wrappers with
                  None -> ()
                | Some (to_string, from_string) ->
                    list := (name, to_string o.option_value) :: !list   
              end
          | v -> 
              list := (name, value_to_string v) :: !list
  ) opfile.file_options;
  !list

let simple_options_html opfile =
  let list = ref [] in
  List.iter
    (fun o ->
       match o.option_name with
         [] | _ :: _ :: _ -> ()
       | [name] ->
           match o.option_class.to_value o.option_value with
             Module _ | SmallList _ | List _ ->
               begin match o.string_wrappers with
                 None -> ()
               | Some (to_string, from_string) ->
                   list := (name, to_string o.option_value, value_to_string (o.option_class.to_value o.option_default), o.option_help) :: !list
               end
           | v -> list := (name, value_to_string v, value_to_string (o.option_class.to_value o.option_default), o.option_help) :: !list)
    opfile.file_options;
  !list


let get_option opfile name =
  let rec iter name list = 
    match list with 
      [] -> 
	prerr_endline (Printf.sprintf "option [%s] not_found in %s" 
			 (String.concat ";" name) opfile.file_name);
	raise Not_found
    | o :: list ->
        if o.option_name = name then o
        else iter name list
  in
  iter [name] opfile.file_options
  
  
let set_simple_option opfile name v =
  let o = get_option opfile name in
  begin
    match o.string_wrappers with
      None ->
        o.option_value <- o.option_class.from_value (string_to_value v);
    | Some (_, from_string) -> 
        o.option_value <- from_string v
  end;
  exec_chooks o; exec_hooks o;;
    
let get_simple_option opfile name =
  let o = get_option opfile name in
  match o.string_wrappers with
    None ->
      value_to_string (o.option_class.to_value o.option_value)
  | Some (to_string, _) -> 
      to_string o.option_value
  
let set_option_hook opfile name hook =
  let o = get_option opfile name in
  o.option_hooks <- hook :: o.option_hooks
  
let set_string_wrappers o to_string from_string =
  o.string_wrappers <- Some (to_string, from_string)
  
let simple_args opfile =
  List.map (fun (name, v) ->
      ("-" ^ name), 
      Arg.String (fun s -> 
          lprintf "Setting option %s" name; lprint_newline ();
          set_simple_option opfile name s), 
      (Printf.sprintf "<string> : \t%s (current: %s)"
          (get_option opfile name).option_help
          v)
  ) (simple_options opfile)

let prefixed_args prefix file =
  List.map (fun (s,f,h) ->
      let s = String.sub s 1 (String.length s - 1) in
      (Printf.sprintf "-%s:%s" prefix s), f,h
  ) (simple_args file)

let option_type o =
  (get_class o).class_name

let once_value v = OnceValue v
    
let strings_of_option o = 
  match o.option_name with
  | [] | _ :: _ :: _ -> failwith "Complex option"
  | [name] -> name,
      match o.string_wrappers with
        None -> value_to_string (o.option_class.to_value o.option_value)
      | Some (to_string, _) -> to_string o.option_value

let strings_of_option_html o = 
  match o.option_name with
  | [] | _ :: _ :: _ -> failwith "Complex option"
  | [name] -> 
      match o.string_wrappers with
      | None -> name, value_to_string (o.option_class.to_value o.option_value), value_to_string (o.option_class.to_value o.option_default), o.option_help
      | Some (to_string, _) -> name, to_string o.option_value, value_to_string (o.option_class.to_value o.option_default), o.option_help

