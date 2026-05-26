FROM rust:1.92-bookworm AS builder

RUN apt-get update && apt-get install -y \
    clang \
    cmake \
    build-essential \
    pkg-config \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY . .

# Build with liquid feature enabled
RUN cargo build --features liquid --release --bin electrs

FROM debian:bookworm-slim

LABEL maintainer="Blockstream" \
      description="Electrs - Esplora backend for Liquid" \
      version="latest"

RUN apt-get update && apt-get install -y \
    ca-certificates \
    tini \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash electrs

WORKDIR /home/electrs

COPY --from=builder --chown=electrs:electrs /build/target/release/electrs /usr/local/bin/electrs

RUN chmod +x /usr/local/bin/electrs

RUN mkdir -p /data/electrs /data/liquid && chown -R electrs:electrs /data

USER electrs

# Expose ports
# 3000 - HTTP API 
# 50001 - Electrum RPC
EXPOSE 3000 50001

VOLUME ["/data"]

# Use tini as entrypoint for proper signal handling
ENTRYPOINT ["/usr/bin/tini", "--"]

# Default command for Liquid network
# Note: Specify external Elements daemon address via --daemon-rpc-addr
CMD ["electrs", \
     "--network", "liquid", \
     "--db-dir", "/data/electrs", \
     "--http-addr", "0.0.0.0:3000", \
     "--electrum-rpc-addr", "0.0.0.0:50001"]
