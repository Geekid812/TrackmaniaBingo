
class MapClaim {
    Player@ player;
    RunResult result;
}

namespace MapClaim {
    Json::Value@ Serialize(MapClaim mapClaim) {
        auto value = Json::Object();
        value["player"] = Json::Object();
        value["player"]["uid"] = mapClaim.player.profile.uid;
        value["player"]["team"] = mapClaim.player.team;
        value["time"] = mapClaim.result.time;
        value["medal"] = mapClaim.result.medal;

        return value;
    }

    MapClaim Deserialize(Json::Value@ value) {
        auto mapClaim = MapClaim();
        if (@Match is null) {
            error("MapClaim: attemping to deserialize when Match == null.");
            return mapClaim;
        }

        @mapClaim.player = Match.GetPlayer(int(value["player"]["uid"]));
        mapClaim.result = RunResult(uint64(value["time"]), Medal(int(value["medal"])));

        return mapClaim;
    }
}
