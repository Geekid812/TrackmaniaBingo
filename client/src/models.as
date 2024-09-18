string stringof(MapMode mode) {
    if (mode == MapMode::RandomTMX) {
        return "Random Maps";
    }
    if (mode == MapMode::Tags) {
        return "Maps With Tag";
    }
    if (mode == MapMode::Campaign) {
        return "Campaign";
    }
    return "Custom Mappack";
}
