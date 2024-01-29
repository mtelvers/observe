FROM ocaml/opam:debian-12-ocaml-4.14 AS build
RUN sudo apt-get update && sudo apt-get install pkg-config libgmp-dev libsqlite3-dev -y --no-install-recommends
RUN cd ~/opam-repository && git fetch -q origin master && opam update
WORKDIR /src
COPY --chown=opam observe.opam /src/
RUN opam pin -yn add .
RUN opam install -y --deps-only .
ADD --chown=opam . .
RUN opam config exec -- dune build ./_build/install/default/bin/observe

FROM debian:12
RUN apt-get update && apt-get install libsqlite3-dev dumb-init ca-certificates netbase iputils-ping rsync dnsutils curl -y --no-install-recommends
WORKDIR /var/lib/observe
RUN mkdir db
ENTRYPOINT ["dumb-init", "/usr/local/bin/observe"]
COPY --from=build /src/logo-with-name.svg /src/style.css /var/lib/observe
COPY --from=build /src/_build/install/default/bin/observe /usr/local/bin/
