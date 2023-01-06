
class RoomConfiguration {
    // Room Config
    uint MaxPlayers = 2;
    bool HasPlayerLimit = false;
    bool RandomizeTeams = false;
    bool InGameChat = false;
    // Game Config
    uint GridSize = 5;
    MapMode MapSelection = MapMode::TOTD;
    int MappackId;
    Medal TargetMedal = Medal::Author;
    uint MinutesLimit = 0;
}

enum MapMode {
    TOTD,
    MXRandom,
    Mappack
}

string stringof(MapMode mode) {
    if (mode == MapMode::TOTD) {
        return "Track of the Day";
    }
    if (mode == MapMode::MXRandom) {
        return "Random Map (TMX)";
    }
    return "Selected Mappack";
}

Json::Value@ Serialize(RoomConfiguration Config) {
    auto Value = Json::Object();
    Value["size"] = Config.HasPlayerLimit ? Config.MaxPlayers : 0;
    Value["randomize"] = Config.RandomizeTeams;
    Value["chat_enabled"] = Config.InGameChat;
    Value["grid_size"] = Config.GridSize;
    Value["selection"] = Config.MapSelection;
    Value["medal"] = Config.TargetMedal;
    Value["time_limit"] = Config.MinutesLimit;

    if (Config.MapSelection == MapMode::Mappack) Value["mappack_id"] = tostring(Config.MappackId);
    return Value;
}