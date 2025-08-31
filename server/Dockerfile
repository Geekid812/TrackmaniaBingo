# Build stage: compile the Rust server
FROM rust:1.77 as builder
WORKDIR /app

COPY Cargo.toml Cargo.lock ./

# Copy the source code and other necessary files
COPY src ./src
COPY data ./data
COPY config.toml ./

RUN cargo build --release

# Runtime stage: minimal image for running the server
FROM debian:bookworm-slim
WORKDIR /app

# Install required system libraries
RUN apt-get update && apt-get install -y libssl-dev ca-certificates \
    # Clean up apt cache to reduce image size
    && rm -rf /var/lib/apt/lists/*

# Copy the compiled server binary from the builder stage
COPY --from=builder /app/target/release/bingohost /app/bingohost

# Expose web API and TCP server ports
EXPOSE 8080 5500

# Start the server
CMD ["/app/bingohost"]
