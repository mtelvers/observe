(lang dune 3.12)

(name observe)

(generate_opam_files true)

(source
 (github username/reponame))

(authors "Mark Elvers")

(maintainers "Mark Elvers")

(license MIT)

(documentation https://github.com/mtelvers/observe)
(homepage https://github.com/mtelvers/observe)
(bug_reports https://github.com/mtelvers/observe/issue)

(package
 (name observe)
 (synopsis "Remotely Monitor Services")
 (description "Remotely Monitor Services")
 (depends ocaml dune sqlite3 cohttp-lwt-unix conduit-lwt tyxml)
 (tags
  (topics ocaml service monitoring)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
