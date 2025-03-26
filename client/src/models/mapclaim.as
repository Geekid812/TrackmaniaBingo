
class MapClaim {
    Player @player;
    int teamId;
    RunResult result;
}

namespace MapClaim {

    Json::Value @Serialize(MapClaim mapClaim) {
        auto value = Json::Object();
        value["player"] = mapClaim.player.AsRef();
        value["team_id"] = mapClaim.teamId;
        value["time"] = mapClaim.result.time;
        value["medal"] = mapClaim.result.medal;

        return value;
    }

    MapClaim Deserialize(Json::Value @value, LiveMatch @match = null) {
        auto mapClaim = MapClaim();
        if (@match is null) {
            if (!Gamemaster::IsBingoActive()) {
                error("[MapClaim::Deserialize] Game is not active.");
                return mapClaim;
            }

            @match = @Match;
        }

        Player @claimingPlayer = match.GetPlayer(int(value["player"]["uid"]));
        @mapClaim.player = claimingPlayer;
        mapClaim.teamId = int(value["team_id"]);
        mapClaim.result = RunResult(uint64(value["time"]), Medal(int(value["medal"])));

        return mapClaim;
    }
}
