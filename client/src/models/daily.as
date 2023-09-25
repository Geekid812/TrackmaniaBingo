class DailyResult {
    int playerCount;
    array<PlayerRef>@ winners = {};
}

class PlayerRef {
    int uid;
    string name;

    PlayerRef() {}

    PlayerRef(int uid, const string&in name) {
        this.uid = uid;
        this.name = name;
    }
}

namespace DailyResult {
    DailyResult Deserialize(Json::Value@ value) {
        auto result = DailyResult();
        result.playerCount = int(value["player_count"]);

        for (uint i = 0; i < value["winners"].Length; i++) {
            result.winners.InsertLast(PlayerRef(int(value["winners"][i]["uid"]), value["winners"][i]["name"]));
        }

        return result;
    }
}