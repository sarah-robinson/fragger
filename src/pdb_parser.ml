(* Copyright (C) 2013, Zhang Initiative Research Unit,
 * Advance Science Institute, Riken
 * 2-1 Hirosawa, Wako, Saitama 351-0198, Japan
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License, with
 * the special exception on linking described in file LICENSE.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. *)

open Core
open Printf

module L  = List
module HT = Caml.Hashtbl
module MU = My_utils
module S  = String

let atom_num_of_pdb_line l =
  (* the space before '%d' is important in the format desc. *)
  try Scanf.sscanf (S.sub l 6 5) " %d" (fun i -> i)
  with _ -> failwith ("pdb_parser.ml: atom_num_of_pdb_line: \
                       cannot extract atom num from: " ^ l)

exception Blank_chain_id

let chain_id_of_pdb_line l =
  try Scanf.sscanf (S.sub l 21 1) "%c"
    (fun c -> if c = ' ' then raise Blank_chain_id else c)
  with _ -> failwith ("pdb_parser.ml: chain_id_of_pdb_line: \
                       cannot extract chain id from: " ^ l)

let res_num_of_pdb_line l =
  (* the space before '%d' is important in the format desc. *)
  try Scanf.sscanf (S.sub l 22 4) " %d" (fun i -> i)
  with _ -> failwith ("pdb_parser.ml: res_num_of_pdb_line: \
                       cannot extract res num from: " ^ l)

let res_name_of_pdb_line l =
  try Scanf.sscanf (S.sub l 17 3) " %s" (fun s -> s)
  with _ -> failwith ("pdb_parser.ml: res_name_of_pdb_line: \
                       cannot extract res name from: " ^ l)

(* only valid for N, CA, C, O *)
let bb_atom_name_of_pdb_line l =
  try S.sub l 13 2
  with _ -> failwith ("pdb_parser.ml: bb_atom_name_of_pdb_line: \
                       cannot extract bb atom name from: " ^ l)

let xyz_of_pdb_line l =
  try
    let xs, ys, zs = S.sub l 30 8,
                     S.sub l 38 8,
                     S.sub l 46 8 in
    (MU.atof xs, MU.atof ys, MU.atof zs)
  with _ ->
    failwith ("pdb_parser.ml: xyz_of_pdb_line: cannot extract xyz from: " ^ l)

(* regexp for ligand lines in the .pqr file generated by pdb2pqr when a small
   molecule ligand is compined to a protein receptor *)
let atom_regexp           = Str.regexp "^ATOM"
let helix_regexp          = Str.regexp "^HELIX"
let sheet_regexp          = Str.regexp "^SHEET"
let ligand_regexp         = Str.regexp "^HETATM.*LIG L"
let atom_or_hetatm_regexp = Str.regexp "^\\(ATOM\\|HETATM\\)"
let pdb_ext_regexp        = Str.regexp ".\\.pdb$"

let is_atom           l = Str.string_match atom_regexp  l 0
let is_helix          l = Str.string_match helix_regexp l 0
let is_sheet          l = Str.string_match sheet_regexp l 0
let is_atom_no_altloc l =
  is_atom l &&
    (let alt_loc = S.sub l 16 1 in (alt_loc = " " || alt_loc = "A"))
let is_ligand         l = Str.string_match ligand_regexp         l 0
let is_atom_or_hetatm l = Str.string_match atom_or_hetatm_regexp l 0

let is_a_pdb_file f =
  try
    let _ = Str.search_forward pdb_ext_regexp f 0 in
    true
  with Not_found -> false

(* xyz triplet to corresponding pdb line hash table creation *)
let create_xyz_to_pdb_line f =
  MU.enforce_any_file_extension f [".pdb"];
  let xyz_to_pdb_line = HT.create 1000 in
  let insert_in_ht pdb_line =
    HT.add xyz_to_pdb_line (xyz_of_pdb_line pdb_line) pdb_line
  in
  MU.iter_on_some_lines_of_file is_atom_or_hetatm insert_in_ht f;
  xyz_to_pdb_line
