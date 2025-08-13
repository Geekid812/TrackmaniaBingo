
namespace Powerups {
    UI::Texture@ PowerupRowShiftTex;
    UI::Texture@ PowerupColumnShiftTex;
    UI::Texture@ PowerupRallyTex;
    UI::Texture@ PowerupJailTex;
    UI::Texture@ PowerupRainbowTileTex;
    UI::Texture@ PowerupGoldenDiceTex;

    UI::Texture@ LoadInternalTex(const string&in filename) {
        IO::FileSource fileSource(filename);
        return UI::LoadTexture(fileSource.Read(fileSource.Size()));
    }

    UI::Texture@ GetPowerupTexture(Powerup powerup) {
        switch (powerup) {
            case Powerup::RowShift:
                return PowerupRowShiftTex;
            case Powerup::ColumnShift:
                return PowerupColumnShiftTex;
            case Powerup::Rally:
                return PowerupRallyTex;
            case Powerup::Jail:
                return PowerupJailTex;
            case Powerup::RainbowTile:
                return PowerupRainbowTileTex;
            default:
                return null;
        }
    }

    string GetExplainerText(Powerup powerup) {
        if (powerup == Powerup::Rally) {
            return "\nThe team who is winning here in 10 minutes will claim all adjacent squares!";
        }
        if (powerup == Powerup::Jail) {
            return "\nThey have to remain on this map until they can beat the current record!";
        }
        if (powerup == Powerup::RainbowTile) {
            return "\nThis map will be counted as every color for win conditions!";
        }

        return "";
    }

    void InitPowerupTextures() {
        @PowerupRowShiftTex = LoadInternalTex("data/row_shift.png");
        @PowerupColumnShiftTex = LoadInternalTex("data/column_shift.png");
        @PowerupRallyTex = LoadInternalTex("data/rally.png");
        @PowerupJailTex = LoadInternalTex("data/jail.png");
        @PowerupRainbowTileTex = LoadInternalTex("data/rainbow.png");
        @PowerupGoldenDiceTex = LoadInternalTex("data/golden_dice.png");
        trace("[Powerups::InitPowerupTextures] Item textures loaded.");
    }

    void TriggerPowerup(Powerup powerup, PlayerRef powerupUser, int boardIndex, bool forwards, PlayerRef@ targetPlayer) {
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
            case Powerup::Jail:
                PowerupEffectJail(boardIndex, targetPlayer, 900000);
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
