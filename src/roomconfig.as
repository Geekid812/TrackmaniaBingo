
class RoomConfiguration {
    uint MaxPlayers = 2;
    MapMode MapSelection = MapMode::TOTD;
    int MappackId;
    Medal TargetMedal = Medal::Author;
    uint MinutesLimit = 30;
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
