
class MatchConfiguration {
    uint gridSize = 5;
    MapMode mapSelection = MapMode::MXRandom;
    uint mappackId;
    int mapTag = 1;
    Medal targetMedal = Medal::Author;
    uint minutesLimit = 0;
    uint noBingoMinutes = 0;
    bool overtime = false;
    bool freeForAll = false;
}

enum MapMode {
    MXRandom,
    Tags,
    Mappack,
}

string stringof(MapMode mode) {
    if (mode == MapMode::MXRandom) {
        return "Random Maps";
    }
    if (mode == MapMode::Tags) {
        return "Maps With Tag";
    }
    return "Custom Mappack";
}

namespace MatchConfiguration {
    Json::Value@ Serialize(MatchConfiguration config) {
        auto value = Json::Object();
        value["grid_size"] = config.gridSize;
        value["selection"] = config.mapSelection;
        value["medal"] = config.targetMedal;
        value["time_limit"] = config.minutesLimit;
        value["no_bingo_mins"] = config.noBingoMinutes;
        value["overtime"] = config.overtime;
        value["free_for_all"] = config.freeForAll;

        if (config.mapSelection == MapMode::Mappack) value["mappack_id"] = config.mappackId;
        if (config.mapSelection == MapMode::Tags) value["map_tag"] = config.mapTag;
        return value;
    }

    MatchConfiguration Deserialize(Json::Value@ value) {
        auto config = MatchConfiguration();
        config.gridSize = value["grid_size"];
        config.mapSelection = MapMode(int(value["selection"]));
        config.targetMedal = Medal(int(value["medal"]));
        config.minutesLimit = uint(value["time_limit"]);
        config.noBingoMinutes = uint(value["no_bingo_mins"]);
        config.overtime = bool(value["overtime"]);
        config.freeForAll = bool(value["free_for_all"]);

        if (value.HasKey("mappack_id")) config.mappackId = uint(value["mappack_id"]);
        if (value.HasKey("map_tag")) config.mapTag = uint(value["map_tag"]);
        return config;
    }
}