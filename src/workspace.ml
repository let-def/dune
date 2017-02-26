open Import
open Sexp.Of_sexp

module Context = struct
  module Opam = struct
    type t =
      { name   : string
      ; switch : string
      ; root   : string option
      }

    let t =
      record
        (field   "switch" string                 >>= fun switch ->
         field   "name"   string ~default:switch >>= fun name ->
         field_o "root"   string                 >>= fun root ->
         return { switch
                ; name
                ; root
                })
  end

  type t = Default | Opam of Opam.t

  let t = function
    | Atom (_, "default") -> Default
    | sexp -> Opam (Opam.t sexp)

  let name = function
    | Default -> "default"
    | Opam o  -> o.name
end

type t = Context.t list

let t sexps =
  List.fold_left sexps ~init:[] ~f:(fun acc sexp ->
    let ctx =
      sum
        [ cstr "context" [Context.t] (fun x -> x) ]
        sexp
    in
    let name = Context.name ctx in
    if name = "" ||
       String.is_prefix name ~prefix:"." ||
       name = "log" ||
       String.contains name '/' ||
       String.contains name '\\' then
      of_sexp_errorf sexp "%S is not allowed as a build context name" name;
    if List.exists acc ~f:(fun c -> Context.name c = name) then
      of_sexp_errorf sexp "second definition of build context %S" name;
    ctx :: acc)
  |> List.rev

let load fn = t (Sexp_load.many fn)