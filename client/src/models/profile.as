
class PlayerProfile {
    int uid;
    string accountId;
    string username;
    uint64 createdAt;
    int score;
    int deviation;
    string countryCode;
}

namespace PlayerProfile {
    Json::Value Deserialize(PlayerProfile profile) {
        auto value = Json::Object();
        value["uid"] = profile.uid;
        value["account_id"] = profile.accountId;
        value["username"] = profile.username;
        value["created_at"] = profile.createdAt;
        value["score"] = profile.score;
        value["deviation"] = profile.deviation;
        value["country_code"] = profile.countryCode;

        return value;
    }

    PlayerProfile Deserialize(Json::Value@ value) {
        auto profile = PlayerProfile();
        profile.uid = value["uid"];
        profile.accountId = value["account_id"];
        profile.username = value["username"];
        profile.createdAt = value["created_at"];
        profile.score = value["score"];
        profile.deviation = value["deviation"];
        profile.countryCode = value["country_code"];

        return profile;
    }
}
