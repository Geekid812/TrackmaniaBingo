// Global active room
GameRoom Room;
// Milliseconds time until game starts (displayed while loading maps)
int StartCountdown;

class GameRoom {
    bool Active;
    bool InGame;
    string JoinCode;
    array<Team>@ Teams = {};
    array<Player>@ Players = {};
    int MaxPlayers;
    int MaxTeams = 999; // Gets overriden by server
    MapMode MapSelection;
    Medal TargetMedal;
    array<Map>@ MapList = {};
    LoadStatus MapsLoadingStatus = LoadStatus::Loading;
    string HostName;
    bool LocalPlayerIsHost;
    EndState EndState;

    Player@ GetSelf(){
        for (uint i = 0; i < Room.Players.Length; i++){
            auto player = Room.Players[i];
            if (player.IsSelf)
                return player;
        }
        return null;
    }

    Map GetMapWithUid(string&in uid) {
        for (uint i = 0; i < MapList.Length; i++) {
            Map SelectedMap = MapList[i];
            if (SelectedMap.Uid == uid) return SelectedMap;
        }

        return Map();
    }
    
    int GetMapCellId(string&in uid) {
        for (uint i = 0; i < MapList.Length; i++) {
            Map SelectedMap = MapList[i];
            if (SelectedMap.Uid == uid) return i;
        }

        return -1;
    }


    Team@ GetTeamWithId(int id) {
        for (uint i = 0; i < Teams.Length; i++) {
            if (Teams[i].Id == id) 
                return Teams[i];
        }
        return null;
    }

    array<Player> GetTeamPlayers(Team team){
        array<Player> players = {};
        for (uint i = 0; i < Room.Players.Length; i++){
            auto player = Room.Players[i];
            if (player.Team == team)
                players.InsertLast(player);
        }
        return players;
    }

    bool MoreTeamsAvaliable(){
        // Non hosts should not see that more teams can be created
        return Teams.Length < uint(Math::Min(MaxTeams, MaxPlayers)) && Room.LocalPlayerIsHost && StartCountdown <= 0;
    }
}

class Team {
    string Name;
    int Id;
    vec3 Color;

    Team() { }

    Team(int id, string&in name, vec3 color) {
        this.Name = name;
        this.Id = id;
        this.Color = color;
    }

    bool opEquals(Team other) {
        return Id == other.Id;
    }
}

class Player {
    string Name;
    Team Team;
    bool IsSelf;

    Player() { }

    Player(string&in name, Team team, bool self) {
        this.Name = name;
        this.Team = team;
        this.IsSelf = self;
    }
}

class Map {
    string Name;
    string Author;
    int TmxID = -1; // Used to compare whether a map is valid
    string Uid;
    Team@ ClaimedTeam = null;
    RunResult ClaimedRun;
    CachedImage@ Thumbnail;
    CachedImage@ MapImage;

    Map() { }

    Map(string&in name, string&in author, int tmxid, string&in uid) {
        this.Name = name;
        this.Author = author;
        this.TmxID = tmxid;
        this.Uid = uid;
        @this.Thumbnail = Images::CachedFromURL("https://trackmania.exchange/maps/screenshot_normal/" + tmxid);
        @this.MapImage = Images::CachedFromURL("https://trackmania.exchange/maps/" + tmxid + "/image/1"); // Do not use /imagethumb route, Openplanet can't understand WEBP
    }
}

class EndState {
    BingoDirection BingoDirection;
    int Offset; // Horizontal: Row ID, Vertical: Column ID, Diagonal: 0 -> TL to BR & 1 -> BL to TR
    uint64 EndTime;

    bool HasEnded() {
        return this.BingoDirection != BingoDirection::None;
    }
}

class RunResult {
    int Time = -1;
    Medal Medal = Medal::None;

    RunResult() { }
    RunResult(int time, Medal medal) {
        this.Time = time;
        this.Medal = medal;
    }

    string Display() {
        return symbolOf(this.Medal) + "\\$z " + Time::Format(this.Time);
    }
}

enum MapMode {
    TOTD,
    MXRandom
}

string stringof(MapMode mode) {
    if (mode == MapMode::TOTD) {
        return "Track of the Day";
    }
    return "Random Map (TMX)";
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

// Game tick function
void Tick(int dt) {
    if (Room.InGame && !Room.EndState.HasEnded()) {
        Playground::CheckMedals();
    }

    // Update countdown
    if (StartCountdown > 0) {
        StartCountdown -= dt;
        if (dt >= StartCountdown) {
            Room.InGame = true;
            Window::Visible = false;
            MapList::Visible = true;
            InfoBar::StartTime = Time::Now;
        }
    }
}
