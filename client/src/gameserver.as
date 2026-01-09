const uint MAX_TEAMS = 6;

class GameServer {
    string uid;
    string joinCode;
    RoomConfiguration roomConfig;
    MatchConfiguration config;
    array<GameTile> @tiles = {};
    array<Team> @teams = {};
    array<Player> @players = {};
    GamePhase phase = GamePhase::Pregame;
    int64 startTime = 0;
    int64 overtimeStartTime = 0;
    bool canReroll = false;
    EndState endState;

    // Local state
    int currentTileIndex = -1;
    bool currentTileInvalid = false;
    bool isLocalPlayerHost = false;
    bool verificationLocked = false;

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

    Team @GetTeamWithName(const string& in name) {
        for (uint i = 0; i < teams.Length; i++) {
            if (teams[i].name == name)
                return teams[i];
        }
        return null;
    }

    uint GetTeamCellCount(Team team) {
        uint sum = 0;
        for (uint i = 0; i < tiles.Length; i++) {
            if (tiles[i].HasRunSubmissions() && tiles[i].LeadingRun().player.team == team) {
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

        logwarn("Match: GetPlayer(" + uid + ") returned null.");
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

    NetworkRoom NetworkState() {
        auto netroom = NetworkRoom();
        netroom.name = this.roomConfig.name;
        netroom.config = this.roomConfig;
        netroom.matchConfig = this.config;
        netroom.playerCount = this.players.Length;
        netroom.hostName = "";

        return netroom;
    }

    GameTile @GetCell(int id) { return this.tiles[id]; }

    void SetCurrentTileIndex(int index) {
        this.currentTileIndex = index;
        this.currentTileInvalid = false;
    }

    void SetMvp(int playerUid) {
        for (uint i = 0; i < players.Length; i++) {
            players[i].isMvp = players[i].profile.uid == playerUid;
        }
    }

    bool CanCreateMoreTeams() {
        return teams.Length <
                   uint(Math::Min(MAX_TEAMS, hasPlayerLimit(roomConfig) ? roomConfig.size : MAX_TEAMS)) &&
               Match.isLocalPlayerHost && !Gamemaster::IsBingoActive();
    }

    bool CanDeleteTeams() {
        // Must have at least 2 teams to play
        return teams.Length > 2 && Match.isLocalPlayerHost;
    }
}

class GameTile {

    GameMap @map = null;
    array<MapClaim> @attemptRanking = {};
    vec3 paintColor = vec3();
    Image @thumbnail;
    Image @mapImage;
    TileItemState specialState = TileItemState::Empty;
    PlayerRef statePlayerTarget = PlayerRef();
    int64 stateTimeDeadline = 0;
    Team claimant = Team(-1, "", vec3());

    GameTile() {}

    GameTile(GameMap map) { SetMap(map); }

    void SetMap(GameMap @map) {
        @this.map = map;
        if (@map !is null) {
            @this.thumbnail =
                Image("https://trackmania.exchange/maps/screenshot_normal/" + map.id);
            @this.mapImage =
                Image("https://trackmania.exchange/maps/" + map.id +
                      "/image/1"); // Do not use /imagethumb route, Openplanet can't understand WEBP
        } else {
            @this.thumbnail = null;
            @this.mapImage = null;
        }
    }

    bool HasRunSubmissions() { return attemptRanking.Length != 0; }

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

        if (i == 0) { // new record
            if (specialState == TileItemState::HasPowerup ||
                specialState == TileItemState::HasSpecialPowerup) {
                specialState = TileItemState::Empty;
            }

            claimant = Team(
                -1, "", vec3()); // reset the team who owns this map to the current record holder
        }
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
    PlayerRef @mvpPlayer;
    int mvpScore;

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
    array<uint> checkpoints = {};
    Medal medal = Medal::None;

    RunResult() {}

    RunResult(int time, Medal medal, array<uint> checkpoints = {}) {
        this.time = time;
        this.medal = medal;
        this.checkpoints = checkpoints;
    }

    string Display(const string& in color = "$z") {
        return symbolOf(this.medal) + "\\" + color + " " + Time::Format(this.time);
    }

    string DisplayTime() { return Time::Format(this.time); }
}


class Team {

    string name;
    int id;
    vec3 color;

    Team() {}

    Team(int id, string& in name, vec3 color) {
        this.name = name;
        this.id = id;
        this.color = color;
    }

    bool opEquals(Team other) { return id == other.id; }
}

namespace Team {
    Team Deserialize(Json::Value @value) {
        return Team(
            value["id"],
            value["name"],
            vec3(value["color"][0] / 255., value["color"][1] / 255., value["color"][2] / 255.));
    }

    Json::Value @Serialize(Team team) {
        Json::Value @value = Json::Object();
        value["id"] = team.id;
        value["name"] = team.name;
        value["color"] = Json::Array();
        value["color"].Add(int(team.color.x * 255.));
        value["color"].Add(int(team.color.y * 255.));
        value["color"].Add(int(team.color.z * 255.));
        return value;
    }
}

class Player {
    PlayerProfile profile;
    string name;
    Team team;
    Powerup holdingPowerup = Powerup::Empty;
    int64 powerupExpireTimestamp;
    bool isMvp;

    Player() {}

    Player(PlayerProfile profile, Team team) {
        this.profile = profile;
        this.name = profile.name;
        this.team = team;
    }

    bool IsSelf() {
        if (@Profile is null)
            return false;
        return profile.uid == Profile.uid;
    }

    PlayerRef AsRef() {
        PlayerRef playerRef();
        playerRef.name = this.name;
        playerRef.uid = this.profile.uid;
        return playerRef;
    }
}

/**
 * Makes sure the player handle given as an argument is not null.
 * If it is, replace it by a "BROKEN PLAYER" handle.
 */
Player@ PlayerEnsureNotNull(Player@ player) {
    if (@player !is null)
        return player;

    PlayerProfile profile();
    profile.name = "\\$f00Broken Player";
    profile.uid = -1;

    Team team(-1, "\\$f00Broken Player", vec3(1., 0., 0.));
    return Player(profile, team);
}

enum BingoDirection {
    None,
    Horizontal,
    Vertical,
    Diagonal
}

enum GamePhase {
    Pregame,
    Starting,
    NoBingo,
    Running,
    Overtime,
    Ended
}

enum TileItemState {
    Empty,
    HasPowerup,
    HasSpecialPowerup,
    Rainbow,
    Rally,
    Jail
}
