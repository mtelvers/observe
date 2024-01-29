# Observe

This utility takes a list of web server names and resolves the names to
IPv4 and IPv6 addresses.  Each host is then pinged over both protocols
and if successful, the web page is fetched using `curl`.  The website
is given 5 seconds to respond.  This is repeated every 60 seconds. The
count of successful and failed tests is tracked in an SQLite database.

The data is displayed via a web interface running on port 8080.  Each host
is displayed as a heatmap-style graphic, with each bar representing 1
hour.  The bar is colour-coded depending on the number of failures with
green representing 1 or fewer and red being greater than 15.  The data
is aggregated over 48 hours and displayed as a percentage below the bar.


# Building locally

```shell
opam switch create . 4.14.1 --deps-only -y
dune build
```

# Build with Docker

Optionally include `--platform`.

```shell
docker buildx build -t mtelvers/observe:latest --platform linux/arm/v7 .
```

