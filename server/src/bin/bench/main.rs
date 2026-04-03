mod client;
mod protocol;
mod scenarios;

use std::net::TcpStream;
use std::process::{Child, Command, Stdio};
use std::time::Duration;

use clap::Parser;

#[derive(Parser)]
#[command(name = "bench", about = "Benchmark harness for the Trackmania Bingo server")]
struct Args {
    /// Scenario to run: join_storm, broadcast_fanout, ping_throughput
    #[arg(long)]
    scenario: String,

    /// Number of simulated clients
    #[arg(long, default_value = "100")]
    clients: u32,

    /// Server address (ignored when --spawn-server is used)
    #[arg(long, default_value = "127.0.0.1:5000")]
    server_addr: String,

    /// Duration in seconds for throughput tests
    #[arg(long, default_value = "10")]
    duration: u64,

    /// Automatically start the server as a subprocess (uses bench.config.toml)
    #[arg(long)]
    spawn_server: bool,
}

fn fmt_duration(d: Duration) -> String {
    if d.as_millis() < 1 {
        format!("{:.0}us", d.as_micros())
    } else if d.as_secs() < 1 {
        format!("{:.1}ms", d.as_secs_f64() * 1000.0)
    } else {
        format!("{:.2}s", d.as_secs_f64())
    }
}

fn print_stats(label: &str, stats: &scenarios::Stats) {
    let throughput = stats.count as f64 / stats.wall_time.as_secs_f64();
    println!();
    println!("  {label}");
    println!("  {:-<50}", "");
    println!("  Completed:  {}", stats.count);
    println!("  Wall time:  {}", fmt_duration(stats.wall_time));
    println!("  Throughput: {throughput:.1} ops/sec");
    println!("  p50:        {}", fmt_duration(stats.p50));
    println!("  p95:        {}", fmt_duration(stats.p95));
    println!("  p99:        {}", fmt_duration(stats.p99));
    println!("  max:        {}", fmt_duration(stats.max));
}

struct ServerGuard {
    child: Child,
    addr: String,
}

impl Drop for ServerGuard {
    fn drop(&mut self) {
        println!("  shutting down server...");
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

/// Spawn the server binary as a child process, wait for it to be ready.
/// The returned guard kills the server on drop.
fn spawn_server() -> ServerGuard {
    let server_dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
    let server_bin = server_dir.join("target/release/bingohost");
    let bench_config = server_dir.join("bench.config.toml");
    let log_path = server_dir.join("bench-server.log");

    println!("  starting server from {}", server_bin.display());

    let log_file = std::fs::File::create(&log_path).expect("cannot create server log file");

    let mut child = Command::new(&server_bin)
        .current_dir(server_dir)
        .args(["--config", bench_config.to_str().unwrap()])
        .stderr(log_file)
        .stdout(Stdio::null())
        .spawn()
        .unwrap_or_else(|e| {
            panic!(
                "failed to start server at {}: {e}\nhint: run `cargo build --release` first",
                server_bin.display()
            )
        });

    // Poll TCP until the server is accepting connections
    let addr = "127.0.0.1:5000";
    print!("  waiting for server to be ready...");
    let deadline = std::time::Instant::now() + Duration::from_secs(15);
    loop {
        if std::time::Instant::now() > deadline {
            eprintln!("\n\nserver did not become ready within 15s. Server output:");
            if let Ok(log) = std::fs::read_to_string(&log_path) {
                eprintln!("{log}");
            }
            let _ = child.kill();
            let _ = child.wait();
            std::process::exit(1);
        }
        if TcpStream::connect_timeout(
            &addr.parse().unwrap(),
            Duration::from_millis(100),
        ).is_ok() {
            break;
        }
        std::thread::sleep(Duration::from_millis(100));
    }
    println!(" ready");

    ServerGuard {
        child,
        addr: addr.to_string(),
    }
}

#[tokio::main]
async fn main() {
    let args = Args::parse();

    let _server_guard: Option<ServerGuard>;
    let server_addr;

    if args.spawn_server {
        println!("bench: spawning server...");
        let guard = spawn_server();
        server_addr = guard.addr.clone();
        _server_guard = Some(guard);
    } else {
        _server_guard = None;
        server_addr = args.server_addr.clone();
    }

    println!("bench: scenario={}, clients={}, addr={server_addr}", args.scenario, args.clients);

    let result = match args.scenario.as_str() {
        "join_storm" => {
            scenarios::join_storm(&server_addr, args.clients)
                .await
                .map(|stats| print_stats("Join Storm", &stats))
        }
        "broadcast_fanout" => {
            scenarios::broadcast_fanout(&server_addr, args.clients)
                .await
                .map(|stats| print_stats("Broadcast Fan-out", &stats))
        }
        "ping_throughput" => {
            scenarios::ping_throughput(&server_addr, args.clients, args.duration)
                .await
                .map(|ping_stats| {
                    print_stats("Ping Throughput", &ping_stats.latency);
                    let rps = ping_stats.total_requests as f64 / ping_stats.wall_time.as_secs_f64();
                    println!("  Total reqs: {}", ping_stats.total_requests);
                    println!("  Aggregate:  {rps:.1} req/sec");
                })
        }
        other => {
            eprintln!("unknown scenario: {other}");
            eprintln!("available: join_storm, broadcast_fanout, ping_throughput");
            std::process::exit(1);
        }
    };

    if let Err(e) = result {
        eprintln!("\nERROR: {e:#}");
        std::process::exit(1);
    }

    println!();
}
