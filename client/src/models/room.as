
class NetworkRoom {
    string name;
    string joinCode;
    string hostName;
    RoomConfiguration config;
    MatchConfiguration matchConfig;
    uint playerCount;
    uint64 createdTimestamp;
    uint64 startedTimestamp;
}

namespace NetworkRoom {
    Json::Value @Serialize(NetworkRoom room) {
        auto value = Json::Object();
        value["name"] = room.name;
        value["join_code"] = room.joinCode;
        value["host_name"] = room.hostName;
        value["config"] = room.config;
        value["match_config"] = room.matchConfig;
        value["player_cout"] = room.playerCount;
        value["created"] = room.createdTimestamp;
        value["started"] = room.startedTimestamp;

        return value;
    }

    NetworkRoom Deserialize(Json::Value @value) {
        auto room = NetworkRoom();
        room.name = value["name"];
        room.joinCode = value["join_code"];
        room.hostName = value["host_name"].GetType() != Json::Type::Null ? value["host_name"] : "";
        room.config = RoomConfiguration::Deserialize(value["config"]);
        room.matchConfig = MatchConfiguration::Deserialize(value["match_config"]);
        room.playerCount = uint(value["player_count"]);
        room.createdTimestamp = uint64(value["created"]);
        room.startedTimestamp = uint64(value["started"]);

        return room;
    }
}
