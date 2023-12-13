// This file is automatically @generated by the `typegen` tool.
// Do not manually edit it! See `common/types.xml` for details.

/* A simple reference to a registered player. */
class PlayerRef {
    uint uid;
    string name;
    PlayerRef() {}
}
namespace PlayerRef {
    Json::Value@ Serialize(PlayerRef cls) {
        auto value = Json::Object();
        value["uid"] = cls.uid;
        value["name"] = cls.name;

        return value;
    }

    PlayerRef Deserialize(Json::Value@ value) {
        auto cls = PlayerRef();
        cls.uid = value["uid"];
        cls.name = value["name"];

        return cls;
    }
}

/* Room parameters set by the host. */
class RoomConfiguration {
    string name;
    bool public;
    bool randomize;
    uint size;
    RoomConfiguration() {}
}
namespace RoomConfiguration {
    Json::Value@ Serialize(RoomConfiguration cls) {
        auto value = Json::Object();
        value["name"] = cls.name;
        value["public"] = cls.public;
        value["randomize"] = cls.randomize;
        value["size"] = cls.size;

        return value;
    }

    RoomConfiguration Deserialize(Json::Value@ value) {
        auto cls = RoomConfiguration();
        cls.name = value["name"];
        cls.public = value["public"];
        cls.randomize = value["randomize"];
        cls.size = value["size"];

        return cls;
    }
}

/* Match parameters set by the host. */
class MatchConfiguration {
    uint gridSize = 5;
    MapMode selection = MapMode::RandomTMX;
    Medal targetMedal = Medal::Author;
    int64 timeLimit;
    int64 noBingoDuration;
    bool overtime;
    bool freeForAll;
    bool rerolls;
    uint mappackId;
    string campaignSelection;
    int mapTag = 1;
    MatchConfiguration() {}
}
namespace MatchConfiguration {
    Json::Value@ Serialize(MatchConfiguration cls) {
        auto value = Json::Object();
        value["grid_size"] = cls.gridSize;
        value["selection"] = int(cls.selection);
        value["target_medal"] = int(cls.targetMedal);
        value["time_limit"] = cls.timeLimit;
        value["no_bingo_duration"] = cls.noBingoDuration;
        value["overtime"] = cls.overtime;
        value["free_for_all"] = cls.freeForAll;
        value["rerolls"] = cls.rerolls;
        value["mappack_id"] = cls.mappackId;
        value["campaign_selection"] = cls.campaignSelection;
        value["map_tag"] = cls.mapTag;

        return value;
    }

    MatchConfiguration Deserialize(Json::Value@ value) {
        auto cls = MatchConfiguration();
        cls.gridSize = value["grid_size"];
        cls.selection = MapMode(int(value["selection"]));
        cls.targetMedal = Medal(int(value["target_medal"]));
        cls.timeLimit = value["time_limit"];
        cls.noBingoDuration = value["no_bingo_duration"];
        cls.overtime = value["overtime"];
        cls.freeForAll = value["free_for_all"];
        cls.rerolls = value["rerolls"];
        if (value["mappack_id"].GetType() != Json::Type::Null) cls.mappackId = value["mappack_id"];
        if (value["campaign_selection"].GetType() != Json::Type::Null) cls.campaignSelection = value["campaign_selection"];
        if (value["map_tag"].GetType() != Json::Type::Null) cls.mapTag = value["map_tag"];

        return cls;
    }
}

/* Request to open a connection by the client. */
class HandshakeRequest {
    string version;
    GamePlatform game;
    string username;
    string token;
    HandshakeRequest() {}
}
namespace HandshakeRequest {
    Json::Value@ Serialize(HandshakeRequest cls) {
        auto value = Json::Object();
        value["version"] = cls.version;
        value["game"] = int(cls.game);
        value["username"] = cls.username;
        value["token"] = cls.token;

        return value;
    }

    HandshakeRequest Deserialize(Json::Value@ value) {
        auto cls = HandshakeRequest();
        cls.version = value["version"];
        cls.game = GamePlatform(int(value["game"]));
        if (value["username"].GetType() != Json::Type::Null) cls.username = value["username"];
        if (value["token"].GetType() != Json::Type::Null) cls.token = value["token"];

        return cls;
    }
}

/* Supported game platforms in Bingo. */
enum GamePlatform {
    Next,
    Turbo,
}

/* Available map selection modes. */
enum MapMode {
    RandomTMX,
    Tags,
    Mappack,
    Campaign,
}

/* A Trackmania medal ranking. */
enum Medal {
    Author,
    Gold,
    Silver,
    Bronze,
    None,
}
