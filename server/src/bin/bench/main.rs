mod client;
mod protocol;
mod scenarios;

use std::collections::HashMap;
use std::net::TcpStream;
use std::process::{Child, Command, Stdio};
use std::time::Duration;

use clap::Parser;
use serde::{Deserialize, Serialize};

#[derive(Parser)]
#[command(name = "bench", about = "Benchmark harness for the Trackmania Bingo server")]
struct Args {
    /// Scenario to run: all, join_storm, broadcast_fanout, ping_throughput, run_submission
    #[arg(long)]
    scenario: String,

    /// Number of simulated clients
    #[arg(long, default_value = "100")]
    clients: u32,

    /// Server address (ignored when --spawn-server is used)
    #[arg(long, default_value = "127.0.0.1:5000")]
    server_addr: String,

    /// Duration in seconds for throughput tests
    #[arg(long, default_value = "3")]
    duration: u64,

    /// Number of iterations per scenario (median is reported)
    #[arg(long, default_value = "5")]
    iterations: u32,

    /// Grid size for match scenarios (NxN)
    #[arg(long, default_value = "5")]
    grid_size: u32,

    /// Automatically start the server as a subprocess (uses data/config.bench.toml)
    #[arg(long)]
    spawn_server: bool,

    /// Save results to a JSON file
    #[arg(long)]
    output: Option<String>,

    /// Compare results against a previous JSON file
    #[arg(long)]
    compare: Option<String>,
}

fn fmt_dur(d: Duration) -> String {
    if d.as_millis() < 1 {
        format!("{:.0}us", d.as_micros())
    } else if d.as_secs() < 1 {
        format!("{:.1}ms", d.as_secs_f64() * 1000.0)
    } else {
        format!("{:.2}s", d.as_secs_f64())
    }
}

struct Row {
    name: String,
    stats: scenarios::Stats,
    extra: Option<String>,
}

fn print_table(rows: &[Row]) {
    // Header
    println!();
    println!(
        "  {:<20} {:>7} {:>9} {:>9} {:>9} {:>9} {:>9} {:>12}  {}",
        "Scenario", "Ops", "Wall", "p50", "p95", "p99", "Max", "Throughput", "Extra"
    );
    println!("  {}", "-".repeat(105));

    for row in rows {
        let throughput = row.stats.count as f64 / row.stats.wall_time.as_secs_f64();
        println!(
            "  {:<20} {:>7} {:>9} {:>9} {:>9} {:>9} {:>9} {:>10.1}/s  {}",
            row.name,
            row.stats.count,
            fmt_dur(row.stats.wall_time),
            fmt_dur(row.stats.p50),
            fmt_dur(row.stats.p95),
            fmt_dur(row.stats.p99),
            fmt_dur(row.stats.max),
            throughput,
            row.extra.as_deref().unwrap_or(""),
        );
    }
    println!();
}

// -- JSON output / compare --

#[derive(Serialize, Deserialize)]
struct RunResult {
    timestamp: String,
    git_commit: Option<String>,
    clients: u32,
    scenarios: HashMap<String, ScenarioResult>,
}

#[derive(Serialize, Deserialize, Clone)]
struct ScenarioResult {
    count: usize,
    wall_time_ms: f64,
    p50_ms: f64,
    p95_ms: f64,
    p99_ms: f64,
    max_ms: f64,
    throughput: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    extra: Option<String>,
}

fn dur_ms(d: Duration) -> f64 {
    d.as_secs_f64() * 1000.0
}

fn rows_to_result(rows: &[Row], clients: u32) -> RunResult {
    let git_commit = std::process::Command::new("git")
        .args(["rev-parse", "--short", "HEAD"])
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_string());

    let mut scenarios = HashMap::new();
    for row in rows {
        let s = &row.stats;
        scenarios.insert(row.name.clone(), ScenarioResult {
            count: s.count,
            wall_time_ms: dur_ms(s.wall_time),
            p50_ms: dur_ms(s.p50),
            p95_ms: dur_ms(s.p95),
            p99_ms: dur_ms(s.p99),
            max_ms: dur_ms(s.max),
            throughput: s.count as f64 / s.wall_time.as_secs_f64(),
            extra: row.extra.clone(),
        });
    }

    RunResult {
        timestamp: chrono::Utc::now().to_rfc3339(),
        git_commit,
        clients,
        scenarios,
    }
}

fn print_comparison(current: &RunResult, baseline: &RunResult) {
    println!();
    println!("  Comparison vs baseline ({})", baseline.git_commit.as_deref().unwrap_or("unknown"));
    println!("  {}", "-".repeat(90));
    println!(
        "  {:<20} {:>12} {:>12} {:>10}  {:>12} {:>12} {:>10}",
        "Scenario", "base p50", "curr p50", "delta", "base p95", "curr p95", "delta"
    );
    println!("  {}", "-".repeat(90));

    let mut names: Vec<&String> = current.scenarios.keys().collect();
    names.sort();

    for name in names {
        let curr = &current.scenarios[name];
        if let Some(base) = baseline.scenarios.get(name) {
            let p50_delta = pct_change(base.p50_ms, curr.p50_ms);
            let p95_delta = pct_change(base.p95_ms, curr.p95_ms);
            println!(
                "  {:<20} {:>10.1}ms {:>10.1}ms {:>+9.1}%  {:>10.1}ms {:>10.1}ms {:>+9.1}%",
                name,
                base.p50_ms, curr.p50_ms, p50_delta,
                base.p95_ms, curr.p95_ms, p95_delta,
            );
        } else {
            println!("  {:<20} {:>12} {:>10.1}ms {:>10}  {:>12} {:>10.1}ms {:>10}",
                name, "-", curr.p50_ms, "new", "-", curr.p95_ms, "new");
        }
    }
    println!();
}

fn pct_change(base: f64, curr: f64) -> f64 {
    if base == 0.0 { return 0.0; }
    ((curr - base) / base) * 100.0
}

fn median_dur(vals: &mut Vec<Duration>) -> Duration {
    vals.sort();
    vals[vals.len() / 2]
}

fn median_f64(vals: &mut Vec<f64>) -> f64 {
    vals.sort_by(|a, b| a.partial_cmp(b).unwrap());
    vals[vals.len() / 2]
}

fn median_usize(vals: &mut Vec<usize>) -> usize {
    vals.sort();
    vals[vals.len() / 2]
}

/// Compute the median Stats across multiple runs.
fn median_stats(runs: &[scenarios::Stats]) -> scenarios::Stats {
    let mut counts: Vec<usize> = runs.iter().map(|s| s.count).collect();
    let mut walls: Vec<Duration> = runs.iter().map(|s| s.wall_time).collect();
    let mut p50s: Vec<Duration> = runs.iter().map(|s| s.p50).collect();
    let mut p95s: Vec<Duration> = runs.iter().map(|s| s.p95).collect();
    let mut p99s: Vec<Duration> = runs.iter().map(|s| s.p99).collect();
    let mut maxes: Vec<Duration> = runs.iter().map(|s| s.max).collect();
    scenarios::Stats {
        count: median_usize(&mut counts),
        wall_time: median_dur(&mut walls),
        p50: median_dur(&mut p50s),
        p95: median_dur(&mut p95s),
        p99: median_dur(&mut p99s),
        max: median_dur(&mut maxes),
    }
}

use std::sync::atomic::{AtomicU32, Ordering};

/// PID of the spawned server process, used to ensure cleanup on exit.
static SERVER_PID: AtomicU32 = AtomicU32::new(0);

/// Kill the server process by PID. Safe to call multiple times.
fn kill_server_pid() {
    let pid = SERVER_PID.swap(0, Ordering::SeqCst);
    if pid != 0 {
        unsafe { libc::kill(pid as i32, libc::SIGKILL); }
        unsafe { libc::waitpid(pid as i32, std::ptr::null_mut(), 0); }
    }
}

struct ServerGuard {
    child: Child,
    addr: String,
}

impl Drop for ServerGuard {
    fn drop(&mut self) {
        eprintln!("  shutting down server...");
        let _ = self.child.kill();
        let _ = self.child.wait();
        SERVER_PID.store(0, Ordering::SeqCst);
    }
}

/// Spawn the server binary as a child process, wait for it to be ready.
/// The returned guard kills the server on drop.
fn spawn_server() -> ServerGuard {
    let server_dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
    let server_bin = server_dir.join("target/release/bingohost");
    let bench_config = server_dir.join("data/config.bench.toml");
    let log_path = server_dir.join("bench-server.log");

    let addr: std::net::SocketAddr = "127.0.0.1:5000".parse().unwrap();

    // Fail early if the port is already occupied
    if TcpStream::connect_timeout(&addr, Duration::from_millis(200)).is_ok() {
        eprintln!("error: port {} is already in use — kill the existing server first", addr.port());
        std::process::exit(1);
    }

    // Build the release server binary so we never run a stale one
    print!("  building release server...");
    let build_status = Command::new("cargo")
        .current_dir(server_dir)
        .args(["build", "--release", "--bin", "bingohost"])
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .status()
        .expect("failed to run cargo build");
    if !build_status.success() {
        eprintln!(" FAILED (exit {})", build_status);
        std::process::exit(1);
    }
    println!(" ok");

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
    print!("  waiting for server to be ready...");
    let deadline = std::time::Instant::now() + Duration::from_secs(15);
    loop {
        // Check the child hasn't already exited (e.g. crash on startup)
        if let Some(status) = child.try_wait().expect("failed to check server status") {
            eprintln!("\n\nserver exited immediately with {status}. Server output:");
            if let Ok(log) = std::fs::read_to_string(&log_path) {
                eprintln!("{log}");
            }
            std::process::exit(1);
        }

        if std::time::Instant::now() > deadline {
            eprintln!("\n\nserver did not become ready within 15s. Server output:");
            if let Ok(log) = std::fs::read_to_string(&log_path) {
                eprintln!("{log}");
            }
            let _ = child.kill();
            let _ = child.wait();
            std::process::exit(1);
        }
        if TcpStream::connect_timeout(&addr, Duration::from_millis(100)).is_ok() {
            break;
        }
        std::thread::sleep(Duration::from_millis(100));
    }
    println!(" ready");

    SERVER_PID.store(child.id(), Ordering::SeqCst);

    ServerGuard {
        child,
        addr: addr.to_string(),
    }
}

extern "C" fn atexit_kill_server() {
    kill_server_pid();
}

#[tokio::main]
async fn main() {
    // Ensure the server subprocess is killed on Ctrl-C, panic, or normal exit.
    unsafe { libc::atexit(atexit_kill_server); }
    tokio::spawn(async {
        tokio::signal::ctrl_c().await.ok();
        kill_server_pid();
        std::process::exit(130);
    });

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

    let to_run: Vec<&str> = match args.scenario.as_str() {
        "all" => vec!["join_storm", "broadcast_fanout", "ping_throughput", "run_submission"],
        other => vec![other],
    };

    let iterations = args.iterations.max(1);
    println!(
        "bench: scenarios={}, clients={}, iterations={iterations}, addr={server_addr}",
        to_run.join(","),
        args.clients,
    );

    let mut rows: Vec<Row> = Vec::new();
    let mut had_error = false;

    for scenario in &to_run {
        println!("\n--- {scenario} ---");
        match *scenario {
            "join_storm" => {
                let mut runs = Vec::new();
                for i in 0..iterations {
                    if iterations > 1 { println!("  iteration {}/{iterations}", i + 1); }
                    match scenarios::join_storm(&server_addr, args.clients).await {
                        Ok(stats) => runs.push(stats),
                        Err(e) => { eprintln!("  ERROR: {e:#}"); had_error = true; }
                    }
                }
                if !runs.is_empty() {
                    rows.push(Row { name: "Join Storm".into(), stats: median_stats(&runs), extra: None });
                }
            },
            "broadcast_fanout" => {
                let mut runs = Vec::new();
                for i in 0..iterations {
                    if iterations > 1 { println!("  iteration {}/{iterations}", i + 1); }
                    match scenarios::broadcast_fanout(&server_addr, args.clients).await {
                        Ok(stats) => runs.push(stats),
                        Err(e) => { eprintln!("  ERROR: {e:#}"); had_error = true; }
                    }
                }
                if !runs.is_empty() {
                    rows.push(Row { name: "Broadcast Fan-out".into(), stats: median_stats(&runs), extra: None });
                }
            },
            "ping_throughput" => {
                let mut runs = Vec::new();
                let mut extras: Vec<(u64, f64)> = Vec::new();
                for i in 0..iterations {
                    if iterations > 1 { println!("  iteration {}/{iterations}", i + 1); }
                    match scenarios::ping_throughput(&server_addr, args.clients, args.duration).await {
                        Ok(ping_stats) => {
                            let total = ping_stats.total_requests;
                            let rps = total as f64 / ping_stats.wall_time.as_secs_f64();
                            extras.push((total, rps));
                            runs.push(ping_stats.latency);
                        }
                        Err(e) => { eprintln!("  ERROR: {e:#}"); had_error = true; }
                    }
                }
                if !runs.is_empty() {
                    let mut rps_vals: Vec<f64> = extras.iter().map(|(_, rps)| *rps).collect();
                    let median_rps = median_f64(&mut rps_vals);
                    let median_total = extras[extras.len() / 2].0;
                    rows.push(Row {
                        name: "Ping Throughput".into(),
                        stats: median_stats(&runs),
                        extra: Some(format!("{median_total} reqs, {median_rps:.0} agg req/s")),
                    });
                }
            },
            "run_submission" => {
                let mut runs = Vec::new();
                for i in 0..iterations {
                    if iterations > 1 { println!("  iteration {}/{iterations}", i + 1); }
                    match scenarios::run_submission(&server_addr, args.clients, args.grid_size).await {
                        Ok(stats) => runs.push(stats),
                        Err(e) => { eprintln!("  ERROR: {e:#}"); had_error = true; }
                    }
                }
                if !runs.is_empty() {
                    rows.push(Row { name: "Run Submission".into(), stats: median_stats(&runs), extra: None });
                }
            },
            other => {
                eprintln!("unknown scenario: {other}");
                eprintln!("available: all, join_storm, broadcast_fanout, ping_throughput, run_submission");
                std::process::exit(1);
            }
        }
    }

    if !rows.is_empty() {
        print_table(&rows);
    }

    // Save results to JSON
    if let Some(ref path) = args.output {
        let result = rows_to_result(&rows, args.clients);
        let json = serde_json::to_string_pretty(&result).expect("json serialization failed");
        std::fs::write(path, &json).unwrap_or_else(|e| {
            eprintln!("failed to write output to {path}: {e}");
        });
        println!("  results saved to {path}");
    }

    // Compare against baseline
    if let Some(ref path) = args.compare {
        match std::fs::read_to_string(path) {
            Ok(json) => match serde_json::from_str::<RunResult>(&json) {
                Ok(baseline) => {
                    let current = rows_to_result(&rows, args.clients);
                    print_comparison(&current, &baseline);
                }
                Err(e) => eprintln!("failed to parse baseline {path}: {e}"),
            },
            Err(e) => eprintln!("failed to read baseline {path}: {e}"),
        }
    }

    if had_error {
        std::process::exit(1);
    }
}
