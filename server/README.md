# Bingohost: Trackmania Bingo server

## Running the Trackmania Bingo Server
### Local Development
To run the server locally:

1. Ensure you have Rust installed. If not, install it from [rustup](https://rustup.rs/)
2. Install required system dependencies if running on Linux:
   ```bash
   sudo apt-get install -y pkg-config libssl-dev
   # or on Fedora:
   sudo dnf install pkg-config openssl-devel
   ```
3. Copy or edit your configuration file using the default values:
   ```bash
   cp data/config.default.toml config.toml
   # Edit config.toml as needed
   ```
4. Generate the `db/mapcache.db` database using the mapcache script:
   ```bash
   cd scripts/mapcache
   mkdir -p ../../db
   python3 main.py -o ../../db/mapcache.db -c 100
   cd ../../
   ```
5. Build and run the server:
   ```bash
   cargo run
   ```

The server will use `config.toml` in the project root and store its databases in the `db/` directory.
By default, the web API will be available on port 8080 and the TCP server on port 5500 (configurable in `config.toml`).

### Using Docker

This section explains how to run the Trackmania Bingo server using Docker. This is still experimental, please submit an issue to provide notice if you are using this method of deployment!

#### Build the Docker Image
Navigate to the `server` directory and build the Docker image:

```bash
docker build -t bingohost .
```

#### Running the Server
The server will use its SQLite databases at `/app/db/main.db` and `/app/db/mapcache.db`. Use a single Docker volume to persist both databases:

```bash
docker volume create tm_bingo_db

# Optional, copy the database files from the host machine into the Docker volume
podman run --rm -v tm_bingo_db:/data -v ./db:/from:Z busybox cp -a /from/. /data/

docker run \
  -v tm_bingo_db:/app/db \
  -p 8080:8080 \
  -p 5500:5500 \
  --name bingohost \
  bingohost
```

**Important Note:** When using `environment = "dev"` in the config, the server will only bind to the localhost interface and it will not be reachable from outside of the container. To fix that, change the value to `"live"` before deploying.

## Benchmarking

The `bench` binary is an integration-style load-test harness that connects simulated TCP clients to a running server instance.

### Quick start

```bash
# Build both the server (release) and bench tool
cargo build --release
cargo build --bin bench

# Run all scenarios (auto-starts the server)
cargo run --bin bench -- --scenario all --clients 100 --spawn-server
```

### Scenarios

| Scenario | Description |
|---|---|
| `join_storm` | N clients join a room concurrently. Measures join latency. |
| `broadcast_fanout` | Host sends a chat message, N clients wait to receive it. Measures broadcast delivery time. |
| `ping_throughput` | N clients send pings in a loop for `--duration` seconds. Measures req/sec and latency. |
| `run_submission` | N clients submit runs to every cell on a `--grid-size` board. Requires a populated mapcache DB. |
| `all` | Runs all of the above in sequence. |

### Options

```
--scenario <name>       Scenario to run (required)
--clients <N>           Number of simulated clients (default: 100)
--server-addr <addr>    Server address (default: 127.0.0.1:5000)
--duration <secs>       Duration for throughput tests (default: 3)
--iterations <N>        Iterations per scenario; median is reported (default: 5)
--grid-size <N>         Grid size for match scenarios (default: 5)
--spawn-server          Auto-start a release server using data/config.bench.toml
--output <file.json>    Save results to a JSON file
--compare <file.json>   Compare current run against a previous JSON file
```

### Comparing runs

Save a baseline, make changes, then compare:

```bash
# Before
cargo run --bin bench -- --scenario all --clients 200 --spawn-server --output baseline.json

# After changes
cargo run --bin bench -- --scenario all --clients 200 --spawn-server --output after.json --compare baseline.json
```

This prints a side-by-side table with percentage deltas for p50 and p95 latencies.

### Running against an external server

Without `--spawn-server`, the bench tool connects to whatever is at `--server-addr`:

```bash
cargo run -- --config data/config.bench.toml   # terminal 1
cargo run --bin bench -- --scenario join_storm --clients 500   # terminal 2
```

### Configuration

The `data/config.bench.toml` file configures the server for benchmarking with auth disabled and rooms that never close. The server accepts a `--config <path>` flag to use an alternative config file.
