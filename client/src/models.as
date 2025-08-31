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

bool hasPlayerLimit(RoomConfiguration config) { return config.size != 0; }

bool canPlayersChooseTheirOwnTeam(RoomConfiguration @roomConfig) {
    return !roomConfig.hostControl && !roomConfig.randomize;
}

string itemName(Powerup powerup) {
    switch (powerup) {
    case Powerup::RowShift:
        return "Row Shift";
    case Powerup::ColumnShift:
        return "Column Shift";
    case Powerup::Rally:
        return "Rally";
    case Powerup::Jail:
        return "Jail";
    case Powerup::RainbowTile:
        return "Rainbow Tile";
    case Powerup::GoldenDice:
        return "Golden Dice";
    default:
        return "";
    }
}
