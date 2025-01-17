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

/* A player's detailed profile. */
class PlayerProfile {
    int uid;
    string name;
    string accountId;
    uint64 createdAt;
    uint64 lastPlayedAt;
    string countryCode;
    string title;
    uint gamesPlayed;
    uint gamesWon;
    PlayerProfile() {}
}
namespace PlayerProfile {
    Json::Value@ Serialize(PlayerProfile cls) {
        auto value = Json::Object();
        value["uid"] = cls.uid;
        value["name"] = cls.name;
        value["account_id"] = cls.accountId;
        value["created_at"] = cls.createdAt;
        value["last_played_at"] = cls.lastPlayedAt;
        value["country_code"] = cls.countryCode;
        value["title"] = cls.title;
        value["games_played"] = cls.gamesPlayed;
        value["games_won"] = cls.gamesWon;

        return value;
    }

    PlayerProfile Deserialize(Json::Value@ value) {
        auto cls = PlayerProfile();
        cls.uid = value["uid"];
        cls.name = value["name"];
        cls.accountId = value["account_id"];
        cls.createdAt = value["created_at"];
        cls.lastPlayedAt = value["last_played_at"];
        cls.countryCode = value["country_code"];
        if (value["title"].GetType() != Json::Type::Null) cls.title = value["title"];
        cls.gamesPlayed = value["games_played"];
        cls.gamesWon = value["games_won"];

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
    GamePlatform game = GamePlatform::Next;
    uint gridSize = 5;
    MapMode selection = MapMode::RandomTMX;
    Medal targetMedal = Medal::Author;
    int64 timeLimit;
    int64 noBingoDuration;
    bool overtime = true;
    bool lateJoin = true;
    bool rerolls = true;
    bool competitvePatch;
    uint mappackId;
    array<uint> campaignSelection;
    int mapTag = 1;
    MatchConfiguration() {}
}
namespace MatchConfiguration {
    Json::Value@ Serialize(MatchConfiguration cls) {
        auto value = Json::Object();
        value["game"] = int(cls.game);
        value["grid_size"] = cls.gridSize;
        value["selection"] = int(cls.selection);
        value["target_medal"] = int(cls.targetMedal);
        value["time_limit"] = cls.timeLimit;
        value["no_bingo_duration"] = cls.noBingoDuration;
        value["overtime"] = cls.overtime;
        value["late_join"] = cls.lateJoin;
        value["rerolls"] = cls.rerolls;
        value["competitve_patch"] = cls.competitvePatch;
        value["mappack_id"] = cls.mappackId;
        value["campaign_selection"] = cls.campaignSelection;
        value["map_tag"] = cls.mapTag;

        return value;
    }

    MatchConfiguration Deserialize(Json::Value@ value) {
        auto cls = MatchConfiguration();
        cls.game = GamePlatform(int(value["game"]));
        cls.gridSize = value["grid_size"];
        cls.selection = MapMode(int(value["selection"]));
        cls.targetMedal = Medal(int(value["target_medal"]));
        cls.timeLimit = value["time_limit"];
        cls.noBingoDuration = value["no_bingo_duration"];
        cls.overtime = value["overtime"];
        cls.lateJoin = value["late_join"];
        cls.rerolls = value["rerolls"];
        cls.competitvePatch = value["competitve_patch"];
        if (value["mappack_id"].GetType() != Json::Type::Null) cls.mappackId = value["mappack_id"];
        if (value["campaign_selection"].GetType() != Json::Type::Null) for (uint i = 0; i < value["campaign_selection"].Length; i++) {
            cls.campaignSelection.InsertLast(value["campaign_selection"][i]);
        }
        if (value["map_tag"].GetType() != Json::Type::Null) cls.mapTag = value["map_tag"];

        return cls;
    }
}

/* Request to open a connection by the client. */
class HandshakeRequest {
    string version;
    GamePlatform game;
    string token;
    HandshakeRequest() {}
}
namespace HandshakeRequest {
    Json::Value@ Serialize(HandshakeRequest cls) {
        auto value = Json::Object();
        value["version"] = cls.version;
        value["game"] = int(cls.game);
        value["token"] = cls.token;

        return value;
    }

    HandshakeRequest Deserialize(Json::Value@ value) {
        auto cls = HandshakeRequest();
        cls.version = value["version"];
        cls.game = GamePlatform(int(value["game"]));
        cls.token = value["token"];

        return cls;
    }
}

/* A map identifier for an official campaign. */
class CampaignMap {
    int campaignId = -1;
    int map = -1;
    CampaignMap() {}
}
namespace CampaignMap {
    Json::Value@ Serialize(CampaignMap cls) {
        auto value = Json::Object();
        value["campaign_id"] = cls.campaignId;
        value["map"] = cls.map;

        return value;
    }

    CampaignMap Deserialize(Json::Value@ value) {
        auto cls = CampaignMap();
        cls.campaignId = value["campaign_id"];
        cls.map = value["map"];

        return cls;
    }
}

/* A message sent by a player in a text chat. */
class ChatMessage {
    uint uid;
    string name;
    string title;
    uint64 timestamp;
    string content;
    bool teamMessage;
    ChatMessage() {}
}
namespace ChatMessage {
    Json::Value@ Serialize(ChatMessage cls) {
        auto value = Json::Object();
        value["uid"] = cls.uid;
        value["name"] = cls.name;
        value["title"] = cls.title;
        value["timestamp"] = cls.timestamp;
        value["content"] = cls.content;
        value["team_message"] = cls.teamMessage;

        return value;
    }

    ChatMessage Deserialize(Json::Value@ value) {
        auto cls = ChatMessage();
        cls.uid = value["uid"];
        cls.name = value["name"];
        if (value["title"].GetType() != Json::Type::Null) cls.title = value["title"];
        cls.timestamp = value["timestamp"];
        cls.content = value["content"];
        cls.teamMessage = value["team_message"];

        return cls;
    }
}

/* One of the available options in a poll. */
class PollChoice {
    string text;
    vec3 color;
    PollChoice() {}
}
namespace PollChoice {
    Json::Value@ Serialize(PollChoice cls) {
        auto value = Json::Object();
        value["text"] = cls.text;
        value["color"] = Color::Serialize(cls.color);

        return value;
    }

    PollChoice Deserialize(Json::Value@ value) {
        auto cls = PollChoice();
        cls.text = value["text"];
        cls.color = Color::Deserialize(value["color"]);

        return cls;
    }
}

/* A set of choices to which players can answer. */
class Poll {
    uint id;
    string title;
    vec3 color;
    int64 duration;
    array<PollChoice> choices;
    Poll() {}
}
namespace Poll {
    Json::Value@ Serialize(Poll cls) {
        auto value = Json::Object();
        value["id"] = cls.id;
        value["title"] = cls.title;
        value["color"] = Color::Serialize(cls.color);
        value["duration"] = cls.duration;
        array<Json::Value@> choices = {};
        for (uint i = 0; i < cls.choices.Length; i++) {
            choices.InsertLast(PollChoice::Serialize(cls.choices[i]));
        }
        value["choices"] = choices;

        return value;
    }

    Poll Deserialize(Json::Value@ value) {
        auto cls = Poll();
        cls.id = value["id"];
        cls.title = value["title"];
        cls.color = Color::Deserialize(value["color"]);
        cls.duration = value["duration"];
        for (uint i = 0; i < value["choices"].Length; i++) {
            cls.choices.InsertLast(PollChoice::Deserialize(value["choices"][i]));
        }

        return cls;
    }
}

/* Supported game platforms in Bingo. */
enum GamePlatform {
    Next,
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

/* When a connection to the server fails, give the client a hint of what it should do. */
enum HandshakeFailureIntentCode {
    ShowError,
    RequireUpdate,
    Reauthenticate,
}
