// Persisently saved: whether the game has crashed during a game
[Setting hidden]
bool WasConnected = false;

class GameRoom {
    string name;
    RoomConfiguration config;
    MatchConfiguration matchConfig;
    string joinCode;
    array<Team>@ teams = {};
    array<Player>@ players = {};
    int maxTeams = 999; // Gets overriden by server
    bool localPlayerIsHost;
    LiveMatch@ activeMatch;

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

    bool CanCreateMoreTeams(){
        // Non hosts should not see that more teams can be created
        return teams.Length < uint(Math::Min(maxTeams, config.hasPlayerLimit ? config.maxPlayers : maxTeams)) && Room.localPlayerIsHost;
    }
}

class Team {
    string name;
    int id;
    vec3 color;

    Team() { }

    Team(int id, string&in name, vec3 color) {
        this.name = name;
        this.id = id;
        this.color = color;
    }

    bool opEquals(Team other) {
        return id == other.id;
    }
}

class Player {
    PlayerProfile profile;
    string name;
    Team team;
    bool isSelf;

    Player() { }

    Player(PlayerProfile profile, Team team, bool self) {
        this.profile = profile;
        this.name = profile.username;
        this.team = team;
        this.isSelf = self;
    }
}
