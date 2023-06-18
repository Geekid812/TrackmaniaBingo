
class LiveMatch {
    MatchConfiguration config;
    array<MapCell>@ gameMaps = {};
    array<Team>@ teams = {};
    array<Player>@ players = {};
    uint64 startTimestamp = 0;
    uint64 endTimestamp = 0;
    EndState endState;

    Player@ GetSelf(){
        for (uint i = 0; i < players.Length; i++){
            auto player = players[i];
            if (player.isSelf)
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

    Player@ GetPlayer(int uid) {
        for (uint i = 0; i < players.Length; i++){
            auto player = players[i];
            if (player.profile.uid == uid) return player;
        }
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

}


class MapCell {
    GameMap@ map = null;
    array<GameAttempt>@ attemptRanking = {};
    CachedImage@ thumbnail;
    CachedImage@ mapImage;

    MapCell() { }

    MapCell(GameMap map) {
        this.map = map;
        @this.thumbnail = Images::CachedFromURL("https://trackmania.exchange/maps/screenshot_normal/" + map.tmxid);
        @this.mapImage = Images::CachedFromURL("https://trackmania.exchange/maps/" + map.tmxid + "/image/1"); // Do not use /imagethumb route, Openplanet can't understand WEBP
    }

    bool IsClaimed() {
        return attemptRanking.Length != 0;
    }

    GameAttempt LeadingRun() {
        if (attemptRanking.Length == 0) throw("Program error: attempted to get leading run on unclaimed map");
        return attemptRanking[0];
    }
}

class GameAttempt {
    Player@ player;
    RunResult recordedRun;
}

class EndState {
    BingoDirection BingoDirection;
    int Offset; // Horizontal: Row ID, Vertical: Column ID, Diagonal: 0 -> TL to BR & 1 -> BL to TR
    uint64 EndTime;

    bool HasEnded() {
        return this.EndTime != 0;
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

    string Display() {
        return symbolOf(this.medal) + "\\$z " + Time::Format(this.time);
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

enum LoadStatus {
    Loading,
    LoadSuccess,
    LoadFail
}

namespace Game {
    // Game tick function
    void Tick() {
        if (@Match == null) return;
        if (!Match.endState.HasEnded()) {
            Playground::CheckMedals();
        
            // check if countdown time is up
            if (Match.config.minutesLimit != 0 && Time::MillisecondsRemaining() == 0) {
                Network::NotifyCountdownEnd();
            }
        }

        // start game if start countdown ended
        // TODO: rework needed
    }
}
