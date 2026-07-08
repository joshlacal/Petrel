# Build from the PETREL REPO ROOT so the path dependency resolves:
#   docker build -f Server/Dockerfile -t petrel-cab-server .
FROM swift:6.1-noble AS build
# libsecret is only needed to satisfy Petrel's Linux system-library target
# during dependency resolution; the server product itself never links it.
RUN apt-get update && apt-get install -y --no-install-recommends \
      libsecret-1-dev libglib2.0-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /repo
COPY . .
WORKDIR /repo/Server
RUN swift build -c release --product petrel-cab-server

FROM swift:6.1-noble-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /repo/Server/.build/release/petrel-cab-server /usr/local/bin/petrel-cab-server
EXPOSE 8080
ENTRYPOINT ["petrel-cab-server"]
CMD ["serve"]
