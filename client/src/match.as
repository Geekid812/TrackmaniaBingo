
class LiveMatch {
    string uid;
    MatchConfiguration config;
    array<MapCell>@ gameMaps = {};
    array<Team>@ teams = {};
    array<Player>@ players = {};
    int64 startTime = 0;
    int64 overtimeStartTime = 0;
    int64 endTime = 0;
    MatchPhase phase = MatchPhase::Starting;
    bool canReroll = false;
    EndState endState;

    Player@ GetSelf(){
        for (uint i = 0; i < players.Length; i++){
            auto player = players[i];
            if (player.IsSelf())
                return player;
        }
        return null;
    }

    Team@ GetTeamWithId(int id) {
        for (uint i = 0; i < teams.Length; i++) {
            if (teams[i].id == id) 
                return teams[i];
        }
        return null;
    }

    array<Player> GetTeamPlayers(Team team){
        array<Player> players = {};
        for (uint i = 0; i < players.Length; i++){
            auto player = players[i];
            if (player.team == team)
                players.InsertLast(player);
        }
        return players;
    }

    uint GetTeamCellCount(Team team) {
        uint sum = 0;
        for (uint i = 0; i < gameMaps.Length; i++) {
            if (gameMaps[i].IsClaimed() && gameMaps[i].LeadingRun().player.team == team) {
                sum += 1;
            }
        }

        return sum;
    }

    Player@ GetPlayer(int uid) {
        for (uint i = 0; i < players.Length; i++){
            auto player = players[i];
            if (player.profile.uid == uid) return player;
        }

        warn("Match: GetPlayer(" + uid + ") returned null.");
        return null;
    }

    MapCell GetMapWithUid(string&in uid) {
        for (uint i = 0; i < this.gameMaps.Length; i++) {
            MapCell selectedMap = this.gameMaps[i];
            if (selectedMap.map.uid == uid) return selectedMap;
        }

        return MapCell();
    }

    MapCell GetCurrentMap() {
        CGameCtnChallenge@ currentMap = Playground::GetCurrentMap();
        if (@currentMap == null) return MapCell();
        return GetMapWithUid(currentMap.EdChallengeId);
    }
    
    int GetMapCellId(string&in uid) {
        for (uint i = 0; i < this.gameMaps.Length; i++) {
            MapCell selectedMap = this.gameMaps[i];
            if (selectedMap.map.uid == uid) return i;
        }

        return -1;
    }

    MapCell GetCell(int id) {
        return this.gameMaps[id];
    }

    MatchPhase GetPhase() {
        return this.phase;
    }

    void SetPhase(MatchPhase phase) {
        auto previous = this.phase;
        this.phase = phase;

        if (previous == MatchPhase::Starting) {
            UIGameRoom::Visible = false;
            UIMapList::Visible = true;
        }

        if (phase == MatchPhase::Overtime) {
            overtimeStartTime = Time::Now;
        }
    }
}


class MapCell {
    GameMap@ map = null;
    array<MapClaim>@ attemptRanking = {};
    vec3 paintColor = vec3();
    array<uint> rerollIds = {};
    CachedImage@ thumbnail;
    CachedImage@ mapImage;

    MapCell() { }

    MapCell(GameMap map) {
        @this.map = map;
#if TURBO
        auto url = Turbo::GetCampaignThumbnailUrl(map.uid);
        @this.mapImage = Images::CachedFromURL(url);
        @this.thumbnail = Images::FindExisting(url);
#elif NEXT
        @this.thumbnail = Images::CachedFromURL("https://trackmania.exchange/maps/screenshot_normal/" + map.id);
        @this.mapImage = Images::CachedFromURL("https://trackmania.exchange/maps/" + map.id + "/image/1"); // Do not use /imagethumb route, Openplanet can't understand WEBP
#endif
    }

    bool IsClaimed() {
        return attemptRanking.Length != 0;
    }

    MapClaim LeadingRun() {
        if (attemptRanking.Length == 0) throw("Program error: attempted to get leading run on unclaimed map");
        return attemptRanking[0];
    }

    MapClaim@ GetLocalPlayerRun() {
        for (uint i = 0; i < attemptRanking.Length; i++) {
            if (attemptRanking[i].player.IsSelf()) return attemptRanking[i]; 
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
    array<BingoLine>@ bingoLines = {};
    Team@ team;

    bool HasEnded() {
        return this.endTime != 0;
    }

    uint WinnerTeamsCount() {
        array<int>@ uniqueTeams = {};
        for (uint i = 0; i < bingoLines.Length; i++) {
            int team_id = bingoLines[i].team.id;
            if (uniqueTeams.Find(team_id) == -1) uniqueTeams.InsertLast(team_id);
        }

        return uniqueTeams.Length;
    }
}

class RunResult {
    int time = -1;
    Medal medal = Medal::None;

    RunResult() { }
    RunResult(int time, Medal medal) {
        this.time = time;
        this.medal = medal;
    }

    string Display(const string&in color = "$z") {
        return symbolOf(this.medal) + "\\" + color + " " + Time::Format(this.time);
    }

    string DisplayTime() {
        return Time::Format(this.time);
    }
}

enum BingoDirection {
    None,
    Horizontal,
    Vertical,
    Diagonal
}

enum MatchPhase {
    Starting,
    NoBingo,
    Running,
    Overtime,
    Ended
}

namespace Game {
    // Game tick function
    void Tick() {
        if (@Match == null) return;
        if (!Match.endState.HasEnded()) {
            Playground::CheckRunFinished();
        }
    }
}
