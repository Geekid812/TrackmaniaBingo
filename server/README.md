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
   python3 main.py -o ../../db/mapcache.db
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
