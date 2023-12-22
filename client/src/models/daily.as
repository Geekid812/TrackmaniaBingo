class DailyResult {
    int playerCount;
    array<PlayerRef>@ winners = {};
}

namespace DailyResult {
    DailyResult Deserialize(Json::Value@ value) {
        auto result = DailyResult();
        result.playerCount = int(value["player_count"]);

        for (uint i = 0; i < value["winners"].Length; i++) {
            result.winners.InsertLast(PlayerRef::Deserialize(value["winners"][i]));
        }

        return result;
    }
}
