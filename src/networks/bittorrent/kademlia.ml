(** Generic implementation of Kademlia *)

let k = 8

module H = Md4.Sha1

let pr fmt = Printf.ksprintf print_endline fmt

let () =
  let hash = H.random () in
  pr "len: %d up: %x %x %x" H.length (H.up hash) (H.up2 hash) (H.up3 hash);
  pr "string: %s" (H.to_string hash);
  pr "direct: %S" (H.direct_to_string hash);
  pr "hexa: %s" (H.to_hexa hash);
  pr "bits: %s" (H.to_bits hash);
  pr "base32: %s" (H.to_base32 hash);

(** node ID type *)
type id = H.t
let show_id = H.to_hexa
type addr = Ip.t * int

type time = float
type status = | Good | Bad | Unknown | Pinged
type node = { id : id; addr : addr; mutable last : time; mutable status : status; }
type bucket = { lo : id; hi : id; mutable last_change : time; nodes : node array; }
type table = bucket array

let show_addr (ip,port) = Printf.sprintf "%s:%u" (Ip.to_string ip) port

let show_status = function
  | Good -> "good"
  | Bad -> "bad"
  | Unknown -> "unk"
  | Pinged -> "ping"

let show_node n =
  pr " id : %s inet %s last : %f status : %s" 
    (H.to_hexa n.id) (show_addr n.addr) n.last (show_status n.status)

let show_bucket b = 
  pr "lo : %s hi : %s changed : %f" (H.to_hexa b.lo) (H.to_hexa b.hi) b.last_change;
  Array.iter show_node b.nodes

let show_table = Array.iter show_bucket 

type cmp = LT | EQ | GT

let cmp id1 id2 = 
  match String.compare (H.direct_to_string id1) (H.direct_to_string id2) with
  | -1 -> LT
  | 0 -> EQ
  | 1 -> GT
  | _ -> assert false

(* boundaries inclusive *)
let between x lo hi = not (cmp x lo = LT || cmp x hi = GT)

let bracket res destroy k =
  let x = try k res with exn -> destroy res; raise exn in
  destroy res;
  x

let with_open_in_bin file = bracket (open_in_bin file) close_in_noerr
let with_open_out_bin file = bracket (open_out_bin file) close_out_noerr

let load file : table = with_open_in_bin file Marshal.from_channel
let store file (t:table) = with_open_out_bin file (fun ch -> Marshal.to_channel ch t [])

let middle =
  let s = String.make 20 (Char.chr 0xFF) in
  s.[0] <- Char.chr 0x7F;
  H.direct_of_string s

let middle' =
  let s = String.make 20 (Char.chr 0x00) in
  s.[0] <- Char.chr 0x80;
  H.direct_of_string s

let last =
  H.direct_of_string (String.make 20 (Char.chr 0xFF))

open Big_int

let big_int_of_hash h =
  let s = H.direct_to_string h in
  assert (String.length s = H.length);
  let n = ref zero_big_int in
  for i = 0 to String.length s - 1 do
    n := add_int_big_int (Char.code s.[i]) (mult_int_big_int 256 !n)
  done;
  !n

let hash_of_big_int n =
  let s = String.create H.length in
  let n = ref n in
  let div = big_int_of_int 256 in
  for i = String.length s - 1 downto 0 do
    let (d,m) = quomod_big_int !n div in
    s.[i] <- Char.chr (int_of_big_int m);
    n := d
  done;
  assert (eq_big_int zero_big_int !n);
  H.direct_of_string s

(* hash <-> number *)
let h2n = big_int_of_hash
let n2h = hash_of_big_int

let split lo hi =
  assert (cmp lo hi = LT);
  let mid = div_big_int (add_big_int (h2n lo) (h2n hi)) (big_int_of_int 2) in
  n2h mid 

let distance h1 h2 = abs_big_int (sub_big_int (h2n h1) (h2n h2))

let () =
  print_endline (show_id H.null);
  print_endline (show_id middle);
  print_endline (show_id middle');
  print_endline (show_id last);
  assert (LT = cmp H.null middle);
  assert (LT = cmp H.null middle');
  assert (LT = cmp H.null last);
  assert (GT = cmp middle' middle);
  assert (GT = cmp last middle');
  assert (GT = cmp last middle);
  assert (EQ = cmp H.null H.null);
  assert (EQ = cmp middle middle);
  assert (EQ = cmp last last);
  assert (n2h (h2n middle) = middle);
  assert (n2h (h2n middle') = middle');
  assert (n2h (h2n last) = last);
  assert (n2h (h2n H.null) = H.null);
  assert (compare_big_int (h2n H.null) zero_big_int = 0);
  assert (cmp (split H.null last) middle = EQ);
  assert (eq_big_int (distance middle' middle) unit_big_int);
  ()

let now = Unix.gettimeofday ()

let create_table () =
  Array.init 2 (function 
    | 0 -> { lo = H.null; hi = middle; last_change = now; nodes = [||]; }
    | _ -> { lo = middle'; hi = last; last_change = now; nodes = [||]; })

let () =
  show_table (create_table ())

