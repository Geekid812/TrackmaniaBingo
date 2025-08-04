
class LiveMatch {
    string uid;
    MatchConfiguration config;
    array<GameTile> @tiles = {};
    array<Team> @teams = {};
    array<Player> @players = {};
    int64 startTime = 0;
    int64 overtimeStartTime = 0;
    GamePhase phase = GamePhase::Starting;
    bool canReroll = false;
    EndState endState;

    // Local state
    int currentTileIndex = -1;
    bool currentTileInvalid = false;

    Player @GetSelf() {
        for (uint i = 0; i < players.Length; i++) {
            auto player = players[i];
            if (player.IsSelf())
                return player;
        }
        return null;
    }

    Team @GetTeamWithId(int id) {
        for (uint i = 0; i < teams.Length; i++) {
            if (teams[i].id == id)
                return teams[i];
        }
        return null;
    }

    array<Player> GetTeamPlayers(Team team) {
        array<Player> players = {};
        for (uint i = 0; i < players.Length; i++) {
            auto player = players[i];
            if (player.team == team)
                players.InsertLast(player);
        }
        return players;
    }

    uint GetTeamCellCount(Team team) {
        uint sum = 0;
        for (uint i = 0; i < tiles.Length; i++) {
            if (tiles[i].IsClaimed() && tiles[i].LeadingRun().player.team == team) {
                sum += 1;
            }
        }

        return sum;
    }

    Player @GetPlayer(int uid) {
        for (uint i = 0; i < players.Length; i++) {
            auto player = players[i];
            if (player.profile.uid == uid)
                return player;
        }

        warn("Match: GetPlayer(" + uid + ") returned null.");
        return null;
    }

    GameTile @GetCurrentTile() {
        CGameCtnChallenge @currentMap = Playground::GetCurrentMap();
        if (currentMap is null)
            return null;

        if (currentTileIndex >= 0 && currentTileIndex < int(tiles.Length))
            return tiles[currentTileIndex];
        return null;
    }

    int GetMapCellId(string& in uid) {
        for (uint i = 0; i < this.tiles.Length; i++) {
            GameTile @tile = this.tiles[i];
            if (tile !is null && tile.map !is null && tile.map.uid == uid)
                return i;
        }

        return -1;
    }

    GameTile GetCell(int id) { return this.tiles[id]; }

    void SetCurrentTileIndex(int index) {
        this.currentTileIndex = index;
        this.currentTileInvalid = false;
    }
}

class GameTile {

    GameMap @map = null;
    array<MapClaim> @attemptRanking = {};
    vec3 paintColor = vec3();
    Image @thumbnail;
    Image @mapImage;
    TileItemState specialState = TileItemState::Empty;

    GameTile() {}

    GameTile(GameMap map) { SetMap(map); }

    void SetMap(GameMap map) {
        @ this.map = map;
        @ this.thumbnail = Image("https://trackmania.exchange/maps/screenshot_normal/" + map.id);
        @ this.mapImage =
            Image("https://trackmania.exchange/maps/" + map.id +
                  "/image/1"); // Do not use /imagethumb route, Openplanet can't understand WEBP
    }

    bool IsClaimed() { return attemptRanking.Length != 0; }

    MapClaim LeadingRun() {
        if (attemptRanking.Length == 0)
            throw("Program error: attempted to get leading run on unclaimed map");
        return attemptRanking[0];
    }

    MapClaim @GetLocalPlayerRun() {
        for (uint i = 0; i < attemptRanking.Length; i++) {
            if (attemptRanking[i].player.IsSelf())
                return attemptRanking[i];
        }

        return null;
    }

    void RegisterClaim(MapClaim claim) {
        int i = attemptRanking.Length;
        while (i > 0) {
            auto current = attemptRanking[i - 1];
            if (current.player.profile.uid == claim.player.profile.uid) {
                attemptRanking.RemoveAt(i - 1);
            } else if (claim.result.time >= current.result.time) {
                break;
            }
            i -= 1;
        }
        attemptRanking.InsertAt(i, claim);
    }
}

class BingoLine {
    BingoDirection bingoDirection;
    int offset; // Horizontal: Row ID, Vertical: Column ID, Diagonal: 0 -> TL to BR & 1 -> BL to TR
    Team team;

    BingoLine() {}
}

class EndState {
    uint64 endTime;
    BingoDirection bingoDirection;
    array<BingoLine> @bingoLines = {};
    Team @team;

    bool HasEnded() { return this.endTime != 0; }

    uint WinnerTeamsCount() {
        array<int> @uniqueTeams = {};
        for (uint i = 0; i < bingoLines.Length; i++) {
            int team_id = bingoLines[i].team.id;
            if (uniqueTeams.Find(team_id) == -1)
                uniqueTeams.InsertLast(team_id);
        }

        return uniqueTeams.Length;
    }
}

class RunResult {
    int time = -1;
    Medal medal = Medal::None;

    RunResult() {}

    RunResult(int time, Medal medal) {
        this.time = time;
        this.medal = medal;
    }

    string Display(const string& in color = "$z") {
        return symbolOf(this.medal) + "\\" + color + " " + Time::Format(this.time);
    }

    string DisplayTime() { return Time::Format(this.time); }
}

enum BingoDirection {
    None,
    Horizontal,
    Vertical,
    Diagonal
}

enum GamePhase {
    Starting,
    NoBingo,
    Running,
    Overtime,
    Ended
}

enum TileItemState {
    Empty,
    HasPowerup,
    HasSpecialPowerup
}
