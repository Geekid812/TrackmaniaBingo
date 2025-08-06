
namespace Powerups {
    void TriggerPowerup(Powerup powerup, PlayerRef powerupUser, GameTile targetTile, Json::Value@ extras) {
        if (!Gamemaster::IsBingoActive()) {
            warn("[Powerups::TriggerPowerup] Bingo is not active, ignoring this event.");
            return;
        }

        
        switch (powerup) {
            case Powerup::RowShift:
            case Powerup::ColumnShift:
                // FIXME
        }
    }

    void PowerupEffectBoardShift(bool isRow, int rowColIndex, bool fowards) {
        if (!Gamemaster::IsBingoActive()) {
            warn("[Powerups::PowerupEffectBoardShift] Bingo is not active, ignoring this call.");
            return;
        }

        array<GameTile> replaceMaps;
        uint gridSize = Match.config.gridSize;
        for (uint i = 0; i < gridSize; i++) {
            uint tileIndex = isRow ? gridSize * rowColIndex : gridSize * i + rowColIndex - i;
            replaceMaps.InsertLast(Match.tiles[tileIndex]);
            Match.tiles.RemoveAt(tileIndex);
        }

        if (fowards) {
            replaceMaps.InsertAt(0, replaceMaps[replaceMaps.Length - 1]);
            replaceMaps.RemoveLast();
        } else {
            replaceMaps.InsertLast(replaceMaps[0]);
            replaceMaps.RemoveAt(0);
        }

        for (uint i = 0; i < gridSize; i++) {
            uint tileIndex = isRow ? gridSize * rowColIndex + i : gridSize * i + rowColIndex;
            Match.tiles.InsertAt(tileIndex, replaceMaps[i]);
        }

        Board::ShiftRowColIndex = rowColIndex;
        Board::ShiftIsRow = isRow;
        Board::ShiftIsForwards = fowards;
        Board::ShiftStartTimestamp = Time::Now;
    }
}
