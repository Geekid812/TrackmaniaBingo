/* A player's detailed profile. */
class PlayerProfile {
    int uid;
    string name;
    string accountId;
    uint64 createdAt;
    string countryCode;
    string title;
    uint gamesPlayed;
    PlayerProfile() {}
}

namespace PlayerProfile {
    Json::Value@ Serialize(PlayerProfile cls) {
        auto value = Json::Object();
        value["uid"] = cls.uid;
        value["username"] = cls.name;
        value["account_id"] = cls.accountId;
        value["created_at"] = cls.createdAt;
        value["country_code"] = cls.countryCode;
        value["title"] = cls.title;
        value["games_played"] = cls.gamesPlayed;

        return value;
    }

    PlayerProfile Deserialize(Json::Value@ value) {
        auto cls = PlayerProfile();
        cls.uid = value["uid"];
        cls.name = value["username"];
        cls.accountId = value["account_id"];
        cls.createdAt = value["created_at"];
        cls.countryCode = value["country_code"];
        if (value["title"].GetType() != Json::Type::Null) cls.title = value["title"];
        cls.gamesPlayed = value["games_played"];

        return cls;
    }
}