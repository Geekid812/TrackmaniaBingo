
class MatchConfiguration {
    uint gridSize = 5;
    MapMode mapSelection = MapMode::TOTD;
    uint mappackId;
    Medal targetMedal = Medal::Author;
    uint minutesLimit = 0;
    uint noBingoMinutes = 0;
    bool overtime = false;
}

enum MapMode {
    TOTD,
    MXRandom,
    Mappack,
}

string stringof(MapMode mode) {
    if (mode == MapMode::TOTD) {
        return "Track of the Day";
    }
    if (mode == MapMode::MXRandom) {
        return "Random Map (TMX)";
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

        if (config.mapSelection == MapMode::Mappack) value["mappack_id"] = config.mappackId;
        return value;
    }

    MatchConfiguration Deserialize(Json::Value@ value) {
        auto config = MatchConfiguration();
        config.gridSize = value["grid_size"];
        config.mapSelection = MapMode(int(value["selection"]));
        config.targetMedal = Medal(int(value["medal"]));
        config.minutesLimit = uint(value["time_limit"]);

        if (value.HasKey("mappack_id")) config.mappackId = uint(value["mappack_id"]);
        return config;
    }
}