class GameRoom {
    string name;
    RoomConfiguration config;
    MatchConfiguration matchConfig;
    string joinCode;
    array<Team> @teams = {};
    array<Player> @players = {};
    int maxTeams = 999; // Gets overriden by server
    bool localPlayerIsHost;
    LiveMatch @activeMatch;

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

    Team @GetTeamWithName(const string& in name) {
        for (uint i = 0; i < teams.Length; i++) {
            if (teams[i].name == name)
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

    Player @GetPlayer(int uid) {
        for (uint i = 0; i < players.Length; i++) {
            auto player = players[i];
            if (player.profile.uid == uid)
                return player;
        }
        return null;
    }

    bool CanCreateMoreTeams() {
        return teams.Length <
                   uint(Math::Min(maxTeams, hasPlayerLimit(config) ? config.size : maxTeams)) &&
               Room.localPlayerIsHost && !Gamemaster::IsBingoActive();
    }

    bool CanDeleteTeams() {
        // Must have at least 2 teams to play
        return teams.Length > 2 && Room.localPlayerIsHost;
    }

    NetworkRoom NetworkState() {
        auto netroom = NetworkRoom();
        netroom.name = this.name;
        netroom.config = this.config;
        netroom.matchConfig = this.matchConfig;
        netroom.playerCount = this.players.Length;
        netroom.hostName = "";

        return netroom;
    }
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
