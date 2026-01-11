
namespace Powerups {
    UI::Texture @PowerupRowShiftTex;
    UI::Texture @PowerupColumnShiftTex;
    UI::Texture @PowerupRallyTex;
    UI::Texture @PowerupJailTex;
    UI::Texture @PowerupRainbowTileTex;
    UI::Texture @PowerupGoldenDiceTex;

    UI::Texture @LoadInternalTex(const string& in filename) {
        IO::FileSource fileSource(filename);
        return UI::LoadTexture(fileSource.Read(fileSource.Size()));
    }

    UI::Texture @GetPowerupTexture(Powerup powerup) {
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
        case Powerup::GoldenDice:
            return PowerupGoldenDiceTex;
        default:
            return null;
        }
    }

    string GetExplainerText(Powerup powerup, uint boardIndex, uint duration) {
        switch (powerup) {
            case Powerup::Rally:
                if (duration > 90) {
                    return "\nThe team who is winning here in " + tostring(duration / 60) + " minutes will claim all adjacent squares!";
                } else{
                return "\nThe team who is winning here in " + tostring(duration) + " seconds will claim all adjacent squares!";
                }
            case Powerup::Jail:
                return "\nThey have to remain on this map until they can beat the current record!";
            case Powerup::RainbowTile:
                return "\nThis map will be counted as every color for win conditions!";
            case Powerup::ColumnShift:
                return "\nThe " + tostring(boardIndex + 1) + OrdinalValue(boardIndex + 1) + " column of the board has been moved!";
            case Powerup::RowShift:
                return "\nThe " + tostring(boardIndex + 1) + OrdinalValue(boardIndex + 1) + " row of the board has been moved!";
        }

        return "";
    }

    string OrdinalValue(uint index) {
        if (index == 1)
            return "st";
        if (index == 2)
            return "nd";
        if (index == 3)
            return "rd";

        return "th";
    }

    void InitPowerupTextures() {
        @PowerupRowShiftTex = LoadInternalTex("data/row_shift.png");
        @PowerupColumnShiftTex = LoadInternalTex("data/column_shift.png");
        @PowerupRallyTex = LoadInternalTex("data/rally.png");
        @PowerupJailTex = LoadInternalTex("data/jail.png");
        @PowerupRainbowTileTex = LoadInternalTex("data/rainbow.png");
        @PowerupGoldenDiceTex = LoadInternalTex("data/golden_dice.png");
        logtrace("[Powerups::InitPowerupTextures] Item textures loaded.");
    }

    void SyncPowerupEffects() {
        if (!Gamemaster::IsBingoActive()) {
            logwarn("[Powerups::SyncPowerupEffects] Bingo not active, ignoring this call.");
            return;
        }

        for (uint i = 0; i < Match.tiles.Length; i++) {
            if (Match.tiles[i].specialState == TileItemState::Jail &&
                int(Match.tiles[i].statePlayerTarget.uid) == Profile.uid) {
                @Jail = Match.GetCell(i);
            }
        }
    }

    void TriggerPowerup(Powerup powerup,
                        PlayerRef powerupUser,
                        int boardIndex,
                        bool forwards,
                        PlayerRef @targetPlayer,
                        uint duration) {
        if (!Gamemaster::IsBingoActive()) {
            logwarn("[Powerups::TriggerPowerup] Bingo is not active, ignoring this event.");
            return;
        }

        switch (powerup) {
        case Powerup::RowShift:
        case Powerup::ColumnShift:
            PowerupEffectBoardShift(powerup == Powerup::RowShift, boardIndex, forwards);
            break;
        case Powerup::Rally:
            PowerupEffectRally(boardIndex, duration * 1000);
            break;
        case Powerup::RainbowTile:
            PowerupEffectRainbowTile(boardIndex);
            break;
        case Powerup::Jail:
            PowerupEffectJail(boardIndex, targetPlayer, duration * 1000);
            break;
        case Powerup::GoldenDice:
            PowerupEffectGoldenDice(boardIndex);
            break;
        }
    }

    void PowerupEffectBoardShift(bool isRow, uint rowColIndex, bool fowards) {
        if (!Gamemaster::IsBingoActive()) {
            logwarn("[Powerups::PowerupEffectBoardShift] Bingo is not active, ignoring this call.");
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
            logwarn("[Powerups::PowerupEffectRainbowTile] Bingo is not active, ignoring this call.");
            return;
        }

        Match.tiles[tileIndex].specialState = TileItemState::Rainbow;
    }

    void PowerupEffectRally(uint tileIndex, uint64 duration) {
        if (!Gamemaster::IsBingoActive()) {
            logwarn("[Powerups::PowerupEffectRally] Bingo is not active, ignoring this call.");
            return;
        }

        Match.tiles[tileIndex].specialState = TileItemState::Rally;
        Match.tiles[tileIndex].stateTimeDeadline = Time::Now + duration;
    }

    void PowerupEffectJail(uint tileIndex, PlayerRef targetPlayer, uint64 duration) {
        if (!Gamemaster::IsBingoActive()) {
            logwarn("[Powerups::PowerupEffectJail] Bingo is not active, ignoring this call.");
            return;
        }

        Match.tiles[tileIndex].specialState = TileItemState::Jail;
        Match.tiles[tileIndex].statePlayerTarget = targetPlayer;
        Match.tiles[tileIndex].stateTimeDeadline = Time::Now + duration;

        if (int(targetPlayer.uid) == Profile.uid) {
            @Jail = Match.tiles[tileIndex];
        }
    }

    void PowerupEffectGoldenDice(uint tileIndex) {
        if (!Gamemaster::IsBingoActive()) {
            logwarn("[Powerups::PowerupEffectGoldenDice] Bingo is not active, ignoring this call.");
            return;
        }

        GameTile @tile = Match.GetCell(tileIndex);

        if (tile.claimant.id == -1 && tile.HasRunSubmissions()) {
            tile.claimant = tile.LeadingRun().player.team;
        }
        tile.attemptRanking = {};
    }

    void NotifyJail() {
        UI::ShowNotification("",
                             Icons::ExclamationCircle +
                                 " You are in jail. You must go to the map where you were "
                                 "emprisoned! To break out of jail, you must beat the current "
                                 "record on this map within the time limit.",
                             vec4(.6, .2, .2, .9),
                             20000);
    }
}
