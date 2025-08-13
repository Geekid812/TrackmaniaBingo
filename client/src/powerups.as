
namespace Powerups {
    void TriggerPowerup(Powerup powerup, PlayerRef powerupUser, int boardIndex, bool forwards) {
        if (!Gamemaster::IsBingoActive()) {
            warn("[Powerups::TriggerPowerup] Bingo is not active, ignoring this event.");
            return;
        }

        
        switch (powerup) {
            case Powerup::RowShift:
            case Powerup::ColumnShift:
                PowerupEffectBoardShift(powerup == Powerup::RowShift, boardIndex, forwards);
                break;
            case Powerup::Rally:
                PowerupEffectRally(boardIndex, 600000);
                break;
            case Powerup::RainbowTile:
                PowerupEffectRainbowTile(boardIndex);
                break;
        }
    }

    void PowerupEffectBoardShift(bool isRow, uint rowColIndex, bool fowards) {
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

    void PowerupEffectRainbowTile(uint tileIndex) {
        if (!Gamemaster::IsBingoActive()) {
            warn("[Powerups::PowerupEffectRainbowTile] Bingo is not active, ignoring this call.");
            return;
        }

        Match.tiles[tileIndex].specialState = TileItemState::Rainbow;
    }

    void PowerupEffectRally(uint tileIndex, uint64 duration) {
        if (!Gamemaster::IsBingoActive()) {
            warn("[Powerups::PowerupEffectRally] Bingo is not active, ignoring this call.");
            return;
        }

        Match.tiles[tileIndex].specialState = TileItemState::Rally;
        Match.tiles[tileIndex].stateTimeDeadline = Time::Now + duration;
    }

    void PowerupEffectJail(uint tileIndex, PlayerRef targetPlayer, uint64 duration) {
        if (!Gamemaster::IsBingoActive()) {
            warn("[Powerups::PowerupEffectJail] Bingo is not active, ignoring this call.");
            return;
        }

        Match.tiles[tileIndex].specialState = TileItemState::Jail;
        Match.tiles[tileIndex].statePlayerTarget = targetPlayer;
        Match.tiles[tileIndex].stateTimeDeadline = Time::Now + duration;

        if (int(targetPlayer.uid) == Profile.uid) {
            @Jail = Match.tiles[tileIndex];
        }
    }
}
