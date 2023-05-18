
class PlayerProfile {
    int uid;
    string accountId;
    string username;
    uint64 createdAt;
    int score;
    int deviation;
    string countryCode;
    int matchCount;
    int wins;
    int losses;
    string title;
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
        value["match_count"] = profile.matchCount;
        value["wins"] = profile.wins;
        value["losses"] = profile.losses;
        value["title"] = profile.title;

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
        profile.matchCount = value["match_count"];
        profile.wins = value["wins"];
        profile.losses = value["losses"];
        profile.title = value["title"];

        return profile;
    }
}
