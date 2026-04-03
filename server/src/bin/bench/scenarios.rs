use std::time::{Duration, Instant};

use anyhow::{bail, Result};
use futures::future::join_all;
use rand::Rng;
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

// ---------------------------------------------------------------------------
// Scenario 4: Run Submission Storm
// ---------------------------------------------------------------------------

pub async fn run_submission(addr: &str, num_clients: u32, grid_size: u32) -> Result<Stats> {
    let cell_count = (grid_size * grid_size) as usize;
    println!("  setting up room with {num_clients} clients (grid {grid_size}x{grid_size})...");

    // Host creates room
    let mut host = BenchClient::connect(addr, 0).await?;
    let resp = host.request(
        "CreateRoom",
        CreateRoomFields {
            config: RoomConfig { size: 0, ..Default::default() },
            match_config: MatchConfig {
                grid_size,
                overtime: false,
                time_limit: 0,
                // Keep the match in NoBingo phase so completing a row doesn't end
                // the match mid-benchmark.
                no_bingo_duration: 3_600_000,
                ..Default::default()
            },
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

    // Connect and join all clients to the room
    let mut clients = connect_clients(addr, num_clients, 1).await?;
    for client in clients.iter_mut() {
        client.request("JoinRoom", JoinRoomFields { join_code: join_code.clone() }).await?;
    }

    // Poll StartMatch until maps are loaded
    println!("  waiting for maps to load...");
    let start_deadline = Instant::now() + Duration::from_secs(30);
    let match_uid;
    loop {
        if Instant::now() > start_deadline {
            bail!("timed out waiting for maps to load (30s)");
        }
        let result = host.request("StartMatch", StartMatchFields {}).await;
        match result {
            Ok(_) => {
                // Match started — read broadcasts until we find the MatchStart event
                let deadline = Instant::now() + Duration::from_secs(10);
                loop {
                    if Instant::now() > deadline {
                        bail!("timed out waiting for MatchStart broadcast");
                    }
                    let evt = host.recv_any().await?;
                    if evt.fields.get("event").and_then(|v| v.as_str()) == Some("MatchStart") {
                        match evt.fields.get("uid").and_then(|v| v.as_str()) {
                            Some(uid) => {
                                match_uid = uid.to_string();
                                break;
                            }
                            None => bail!("MatchStart broadcast missing uid field"),
                        }
                    }
                }
                break;
            }
            Err(_) => {
                tokio::time::sleep(Duration::from_millis(500)).await;
            }
        }
    }
    println!("  match started: {match_uid}");

    // All clients join the match
    for client in clients.iter_mut() {
        client.request("JoinMatch", JoinMatchFields {
            uid: match_uid.clone(),
            team_id: None,
        }).await?;
    }
    // Wait for the NoBingo phase to activate before submitting runs.
    // The match starts in "Starting" phase where bingo checks are active;
    // we need to wait for the PhaseChange broadcast.
    println!("  waiting for NoBingo phase...");
    let phase_deadline = Instant::now() + Duration::from_secs(10);
    loop {
        if Instant::now() > phase_deadline {
            bail!("timed out waiting for PhaseChange broadcast");
        }
        let evt = host.recv_any().await?;
        if evt.fields.get("event").and_then(|v| v.as_str()) == Some("PhaseChange") {
            break;
        }
    }
    println!("  submitting runs...");

    // Fire concurrent SubmitRun requests from all clients
    let wall_start = Instant::now();

    let mut handles: Vec<JoinHandle<Result<Vec<Duration>>>> = Vec::new();
    for mut client in clients.drain(..) {
        let cells = cell_count;
        // Pre-generate random times (ThreadRng is not Send)
        let times: Vec<u64> = {
            let mut rng = rand::thread_rng();
            (0..cells).map(|_| rng.gen_range(30_000..120_000u64)).collect()
        };
        handles.push(tokio::spawn(async move {
            let mut latencies = Vec::new();
            // Each client submits a run to each cell
            for (tile_index, time) in times.into_iter().enumerate() {
                let start = Instant::now();
                client.request("SubmitRun", SubmitRunFields {
                    tile_index,
                    time,
                    medal: 2, // Gold
                    splits: vec![],
                }).await?;
                latencies.push(start.elapsed());
            }
            Ok(latencies)
        }));
    }

    let results = join_all(handles).await;
    let wall_time = wall_start.elapsed();

    let mut durations = Vec::new();
    for result in results {
        match result {
            Ok(Ok(lats)) => durations.extend(lats),
            Ok(Err(e)) => eprintln!("  submit failed: {e}"),
            Err(e) => eprintln!("  submit task panicked: {e}"),
        }
    }

    if durations.is_empty() {
        bail!("all submissions failed");
    }

    Ok(Stats::from_durations(durations, wall_time))
}
