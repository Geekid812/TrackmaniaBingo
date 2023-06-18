
class RoomConfiguration {
    string name;
    uint maxPlayers = 2;
    bool hasPlayerLimit = false;
    bool randomizeTeams = false;
    bool inGameChat = false;
    bool isPublic = false;
}

namespace RoomConfiguration {
    Json::Value@ Serialize(RoomConfiguration config) {
        auto value = Json::Object();
        value["name"] = config.name;
        value["public"] = config.isPublic;
        value["size"] = config.hasPlayerLimit ? config.maxPlayers : 0;
        value["randomize"] = config.randomizeTeams;
        value["chat_enabled"] = config.inGameChat;

        return value;
    }

    RoomConfiguration Deserialize(Json::Value@ value) {
        auto config = RoomConfiguration();
        config.name = value["name"];
        config.isPublic = value["public"];
        config.hasPlayerLimit = int(value["size"]) != 0;
        config.maxPlayers = value["size"];
        config.randomizeTeams = value["randomize"];
        config.inGameChat = value["chat_enabled"];

        return config;
    }
}