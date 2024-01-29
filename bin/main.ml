open Cohttp_lwt_unix
open Tyxml.Html
open Lwt.Infix

let read_whole_file filename =
    let ch = open_in_bin filename in
    let s = really_input_string ch (in_channel_length ch) in
    close_in ch;
    s

let db = Db.of_dir "db/sqlite"

let format_timestamp time =
  let { Unix.tm_year; tm_mon; tm_mday; tm_hour; tm_min; tm_sec; _ } = time in
  Fmt.str "%04d-%02d-%02d %02d:%02d:%02d" (tm_year + 1900) (tm_mon + 1) tm_mday tm_hour tm_min tm_sec

let hosts = [ "opam.ocaml.org"; "www.ocaml.org"; "check.ci.ocaml.org"; "staging.ocaml.org"; "watch.ocaml.org"; "docs.ci.ocaml.org"; "v2.ocaml.org"; "staging.docs.ci.ocamllabs.io"; "opam-repo.ci.ocaml.org";
              "deploy.ci.ocaml.org"; "images.ci.ocaml.org"; "freebsd.check.ci.dev"]

let rec run () = 
  Lwt_list.map_s (Os.dig) hosts >>= fun addresses ->
  List.combine hosts addresses |>
  Lwt_list.iter_s (fun (fqdn, ips) ->
    ips |> Lwt_list.iter_s (fun ip ->
    Os.ping ip >>= fun ping ->
    Os.curl fqdn ip >>= fun curl ->
    let now = format_timestamp (Unix.(gmtime (gettimeofday () ))) in
    let rc = match ping && curl with
      | true -> 0L
      | false -> 1L in
    let () = Db.exec db (Sqlite3.prepare db {| INSERT INTO results (time, host, failure) VALUES (?, ?, ?) |}) Sqlite3.Data.[ TEXT now; TEXT fqdn; INT rc ] in
    Lwt.return ())) >>= fun () ->
  Lwt_unix.sleep 60. >>= fun () -> run ()

let error_count_to_colour count =
  List.fold_left2 (fun r color band -> if count < band then color else r) (`Color ("#e74c3c", None))
    [ `Color ("#e67924", None); `Color ("#eeb314", None); `Color ("#abc72e", None); `Color ("#b9c628", None); `Color ("#2fcc66", None); ] 
    [ 15; 10; 6; 3; 1 ]

let server =
  let callback _conn req _ =
    let uri = req |> Request.uri in
    let headers, body = match Uri.path uri with
    | "/style.css" -> Cohttp.Header.of_list ["Content-Type", "text/css"], read_whole_file "style.css"
    | "/script.js" -> Cohttp.Header.of_list ["Content-Type", "application/javascript"], read_whole_file "script.js"
    | "/logo-with-name.svg" -> Cohttp.Header.of_list ["Content-Type", "image/svg+xml"], read_whole_file "logo-with-name.svg"
    | _ ->
      Cohttp.Header.of_list ["Content-Type", "text/html"],
      let hosts = 
        let rows = Db.query db (Sqlite3.prepare db {| SELECT host, MAX(time), failure FROM results GROUP BY host; |}) [] in
        List.fold_left (fun acc row ->
          match row with
            | [ Sqlite3.Data.TEXT h; Sqlite3.Data.TEXT _; Sqlite3.Data.INT c; ] -> 
              (h, c) :: acc
            | _ -> Fmt.failwith "Invalid row"
          ) [] rows
      in 
      let status = List.map (fun (host, state) ->
        let rows = Db.query db (Sqlite3.prepare db {| SELECT SUM(failure), strftime('%Y-%m-%d %H', time) hour, COUNT(*)
                                                      FROM results WHERE host = ? GROUP BY hour, host ORDER BY time LIMIT 48; |}) Sqlite3.Data.[ TEXT host ] in
        let _, fails, sum, graph = List.fold_left (fun (x, fails, sum, acc) row ->
          match row with
            | [ Sqlite3.Data.INT f; Sqlite3.Data.TEXT _; Sqlite3.Data.INT c; ] -> 
              x -. 10., Int64.add fails f, Int64.add sum c, acc @
              [Tyxml.Svg.rect ~a:[Tyxml.Svg.a_x (x, None); Tyxml.Svg.a_y (0., None); Tyxml.Svg.a_height (34., None); Tyxml.Svg.a_width (7., None); Tyxml.Svg.a_fill (error_count_to_colour (Int64.to_int f))] []]
            | _ -> Fmt.failwith "Invalid row"
          ) (470., 0L, 0L, []) rows
        in [div ~a:[a_class ["host"]] [div ~a:[a_class ["timeline"]] [
                                         div [txt host];
                                         div ~a:[a_class ["spacer"]] [];
                                         div ~a:[a_class [(if state = 0L then "good" else "bad")]] [txt (if state = 0L then "ok" else "down")];
                                       ];
                                       div ~a:[a_class ["graph"]] [ svg ~a:[Tyxml.Svg.a_height (34., None); Tyxml.Svg.a_width (10. *. 48., None)] graph];
                                       div ~a:[a_class ["timeline"; "legend"]] [
                                         div [txt "48 hours ago"];
                                         div ~a:[a_class ["spacer"]] [];
                                         div [txt (Int64.to_string (Int64.div(Int64.mul (Int64.sub sum fails) 100L) sum) ^ "% available")];
                                         div ~a:[a_class ["spacer"]] [];
                                         div [txt "now"];
                                       ]
                                      ]]
        ) hosts
      in
      Format.asprintf "%a"
        (Tyxml.Html.pp ())
        (html (head (title (txt "OCaml Services")) [link ~rel:[`Stylesheet] ~href:"style.css" (); link ~rel:[`Stylesheet] ~href:"https://fonts.googleapis.com/css?family=Inter" ()])
        (body [div ~a:[a_class ["content"]] [
               div ~a:[a_class ["header"]] [h1 [img ~src:"logo-with-name.svg" ~alt:"OCaml logo" (); txt "Services"]];
          div (List.flatten status);
          div [txt ""] ; ]])) in
    Server.respond_string ~status:`OK ~body ~headers ()
  in
  Server.create ~mode:(`TCP (`Port 8080)) (Server.make ~callback ())

let () =
  Db.exec db (Sqlite3.prepare db "CREATE TABLE IF NOT EXISTS results (time DATETIME NOT NULL, host TEXT NOT NULL, failure INTEGER NOT NULL);") []

let () = Lwt.async run
let () = ignore (Lwt_main.run server)
