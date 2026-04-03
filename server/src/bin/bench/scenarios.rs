use std::time::{Duration, Instant};

use anyhow::{bail, Result};
use futures::future::join_all;
use tokio::task::JoinHandle;

use crate::client::BenchClient;
use crate::protocol::*;

/// Stats collected from a set of latency measurements.
pub struct Stats {
    pub count: usize,
    pub p50: Duration,
    pub p95: Duration,
    pub p99: Duration,
    pub max: Duration,
    pub wall_time: Duration,
}

impl Stats {
    pub fn from_durations(mut durations: Vec<Duration>, wall_time: Duration) -> Self {
        durations.sort();
        let n = durations.len();
        Self {
            count: n,
            p50: durations[n / 2],
            p95: durations[(n as f64 * 0.95) as usize],
            p99: durations[(n as f64 * 0.99) as usize],
            max: durations[n - 1],
            wall_time,
        }
    }
}

/// Connect N clients, returning those that succeeded.
/// Bails if more than 10% fail.
async fn connect_clients(addr: &str, count: u32, start_index: u32) -> Result<Vec<BenchClient>> {
    let mut handles: Vec<JoinHandle<Result<BenchClient>>> = Vec::new();
    for i in 0..count {
        let addr = addr.to_string();
        handles.push(tokio::spawn(async move {
            BenchClient::connect(&addr, start_index + i).await
        }));
    }

    let results = join_all(handles).await;
    let mut clients = Vec::new();
    let mut failures = 0u32;
    for result in results {
        match result {
            Ok(Ok(client)) => clients.push(client),
            Ok(Err(e)) => {
                eprintln!("  client connect failed: {e}");
                failures += 1;
            }
            Err(e) => {
                eprintln!("  client task panicked: {e}");
                failures += 1;
            }
        }
    }

    let threshold = (count as f64 * 0.1).ceil() as u32;
    if failures > threshold {
        bail!(
            "{failures}/{count} clients failed to connect (>{} allowed)",
            threshold
        );
    }
    if !clients.is_empty() {
        println!("  connected {}/{count} clients", clients.len());
    }
    Ok(clients)
}

// ---------------------------------------------------------------------------
// Scenario 1: Room Join Storm
// ---------------------------------------------------------------------------

pub async fn join_storm(addr: &str, num_clients: u32) -> Result<Stats> {
    println!("  setting up: creating room with host client...");

    // Host client creates the room
    let mut host = BenchClient::connect(addr, 0).await?;
    let resp = host.request(
        "CreateRoom",
        CreateRoomFields {
            config: RoomConfig {
                size: 0, // unlimited
                ..Default::default()
            },
            match_config: MatchConfig::default(),
            teams: vec![
                Team { id: 0, name: "Team A".into(), color: [255, 0, 0] },
                Team { id: 1, name: "Team B".into(), color: [0, 0, 255] },
            ],
        },
    ).await?;

    let join_code = resp
        .fields
        .get("join_code")
        .and_then(|v| v.as_str())
        .ok_or_else(|| anyhow::anyhow!("no join_code in CreateRoom response"))?
        .to_string();
    println!("  room created with code: {join_code}");

    // Connect all joiner clients first (handshake only)
    println!("  connecting {num_clients} clients...");
    let mut joiners = connect_clients(addr, num_clients, 1).await?;

    // Now fire all JoinRoom requests concurrently and measure each
    println!("  joining all clients to room...");
    let wall_start = Instant::now();

    let mut handles: Vec<JoinHandle<Result<Duration>>> = Vec::new();
    for mut client in joiners.drain(..) {
        let code = join_code.clone();
        handles.push(tokio::spawn(async move {
            let start = Instant::now();
            client.request("JoinRoom", JoinRoomFields { join_code: code }).await?;
            Ok(start.elapsed())
        }));
    }

    let results = join_all(handles).await;
    let wall_time = wall_start.elapsed();

    let mut durations = Vec::new();
    for result in results {
        match result {
            Ok(Ok(d)) => durations.push(d),
            Ok(Err(e)) => eprintln!("  join failed: {e}"),
            Err(e) => eprintln!("  join task panicked: {e}"),
        }
    }

    if durations.is_empty() {
        bail!("all joins failed");
    }

    Ok(Stats::from_durations(durations, wall_time))
}

// ---------------------------------------------------------------------------
// Scenario 2: Broadcast Fan-out
// ---------------------------------------------------------------------------

pub async fn broadcast_fanout(addr: &str, num_clients: u32) -> Result<Stats> {
    println!("  setting up room with {num_clients} clients...");

    // Host creates room
    let mut host = BenchClient::connect(addr, 0).await?;
    let resp = host.request(
        "CreateRoom",
        CreateRoomFields {
            config: RoomConfig { size: 0, ..Default::default() },
            match_config: MatchConfig::default(),
            teams: vec![
                Team { id: 0, name: "Team A".into(), color: [255, 0, 0] },
                Team { id: 1, name: "Team B".into(), color: [0, 0, 255] },
            ],
        },
    ).await?;

    let join_code = resp
        .fields
        .get("join_code")
        .and_then(|v| v.as_str())
        .ok_or_else(|| anyhow::anyhow!("no join_code in CreateRoom response"))?
        .to_string();

    // Connect and join all clients
    let mut clients = connect_clients(addr, num_clients, 1).await?;
    for client in clients.iter_mut() {
        client.request("JoinRoom", JoinRoomFields { join_code: join_code.clone() }).await?;
    }
    println!("  all clients joined, sending broadcast...");

    // Host sends a chat message, all clients wait for the broadcast
    let wall_start = Instant::now();

    // Send chat from host
    host.request("SendChatMessage", SendChatMessageFields {
        message: "benchmark ping".into(),
    }).await?;

    // Each client waits for the ChatMessage broadcast
    let mut handles: Vec<JoinHandle<Result<Duration>>> = Vec::new();
    for mut client in clients.drain(..) {
        let start = wall_start;
        handles.push(tokio::spawn(async move {
            loop {
                let msg = client.recv_any().await?;
                // Broadcast events from chat contain a "ChatMessage" variant
                if let Some(content) = msg.fields.get("content") {
                    if content.as_str() == Some("benchmark ping") {
                        return Ok(start.elapsed());
                    }
                }
            }
        }));
    }

    let results = join_all(handles).await;
    let wall_time = wall_start.elapsed();

    let mut durations = Vec::new();
    for result in results {
        match result {
            Ok(Ok(d)) => durations.push(d),
            Ok(Err(e)) => eprintln!("  recv failed: {e}"),
            Err(e) => eprintln!("  recv task panicked: {e}"),
        }
    }

    if durations.is_empty() {
        bail!("no clients received the broadcast");
    }

    Ok(Stats::from_durations(durations, wall_time))
}

// ---------------------------------------------------------------------------
// Scenario 3: Sustained Ping Throughput
// ---------------------------------------------------------------------------

pub struct PingStats {
    pub total_requests: u64,
    pub wall_time: Duration,
    pub latency: Stats,
}

pub async fn ping_throughput(addr: &str, num_clients: u32, duration_secs: u64) -> Result<PingStats> {
    println!("  setting up room with {num_clients} clients...");

    // Host creates room
    let mut host = BenchClient::connect(addr, 0).await?;
    let resp = host.request(
        "CreateRoom",
        CreateRoomFields {
            config: RoomConfig { size: 0, ..Default::default() },
            match_config: MatchConfig::default(),
            teams: vec![
                Team { id: 0, name: "Team A".into(), color: [255, 0, 0] },
                Team { id: 1, name: "Team B".into(), color: [0, 0, 255] },
            ],
        },
    ).await?;

    let join_code = resp
        .fields
        .get("join_code")
        .and_then(|v| v.as_str())
        .ok_or_else(|| anyhow::anyhow!("no join_code in CreateRoom response"))?
        .to_string();

    let mut clients = connect_clients(addr, num_clients, 1).await?;
    for client in clients.iter_mut() {
        client.request("JoinRoom", JoinRoomFields { join_code: join_code.clone() }).await?;
    }
    println!("  running pings for {duration_secs}s...");

    let test_duration = Duration::from_secs(duration_secs);
    let wall_start = Instant::now();

    let mut handles: Vec<JoinHandle<Vec<Duration>>> = Vec::new();
    for mut client in clients.drain(..) {
        let dur = test_duration;
        handles.push(tokio::spawn(async move {
            let mut latencies = Vec::new();
            let start = Instant::now();
            while start.elapsed() < dur {
                let ping_start = Instant::now();
                if client.ping().await.is_ok() {
                    latencies.push(ping_start.elapsed());
                }
            }
            latencies
        }));
    }

    let results = join_all(handles).await;
    let wall_time = wall_start.elapsed();

    let mut all_latencies = Vec::new();
    for result in results {
        if let Ok(latencies) = result {
            all_latencies.extend(latencies);
        }
    }

    if all_latencies.is_empty() {
        bail!("no pings succeeded");
    }

    let total_requests = all_latencies.len() as u64;
    let latency = Stats::from_durations(all_latencies, wall_time);

    Ok(PingStats {
        total_requests,
        wall_time,
        latency,
    })
}
