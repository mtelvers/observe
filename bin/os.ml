open Lwt.Infix

let pread_with_status command =
  Lwt.catch (fun () ->
    Lwt_process.with_process_in ~timeout:5. command @@ fun p ->
    Lwt.both (Lwt_io.read p#stdout) p#status
  ) (function
    | Lwt_io.Channel_closed _ -> Lwt.return ("", Unix.WSIGNALED 9) (* timeout was reached *)
    | _ -> Lwt.return ("", Unix.WEXITED 1)
  )

let dig fqdn =
  pread_with_status ("dig", [|"dig"; "@8.8.8.8"; "+noall"; "+answer"; fqdn; "A"; fqdn; "AAAA"|]) >>= fun (result, rc) ->
    let lst = match rc with
    | WEXITED 0 ->
      String.split_on_char '\n' result |>
      List.filter_map (fun s ->
        match (Scanf.sscanf s "%s %s %s %s %s" (fun _ _ _ rtype ip -> (rtype, ip))) with
        | "AAAA", ip -> Some (`V6 ip)
        | "A", ip -> Some (`V4 ip)
        | _, _ -> None
        | exception Scanf.Scan_failure _ -> None
        | exception End_of_file -> None)
    | _ -> [] in
    Lwt.return lst

let ping ip =
  let cmd = match ip with
    | `V4 ip -> [| "ping"; "-c"; "1"; ip |]
    | `V6 ip -> [| "ping6"; "-c"; "1"; ip |] in
  pread_with_status ("", cmd) >>= fun (_, rc) ->
  let success = match rc with
    | WEXITED 0 -> true
    | _ -> false in
  Lwt.return success

let curl fqdn ip =
  let cmd = match ip with
    | `V4 ip -> [| "curl"; "--silent"; "-L"; "--resolve"; fqdn ^ ":443:" ^ ip; "https://" ^ fqdn |]
    | `V6 ip -> [| "curl"; "--silent"; "-L"; "--resolve"; fqdn ^ ":443:[" ^ ip ^ "]"; "https://" ^ fqdn |] in
  pread_with_status ("", cmd) >>= fun (result, rc) ->
  let success = match rc with
    | WEXITED 0 -> (String.length result) > 1024
    | _ -> false in
  Lwt.return success

