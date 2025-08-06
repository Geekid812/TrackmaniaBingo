
namespace UIDevPowerups {
    bool ShiftForwards;
    bool ShiftIsRow;
    uint ShiftIndex;
    uint PowerupTileIndex;

    void Render() {
        UI::Text(Icons::ExclamationTriangle + " Only for testing use, using this in a live game will cause desync with the game state!");

        UIColor::Crimson();

        ShiftControls();
        UI::Separator();
        SpecificTileControls();

        UIColor::Reset();
    }

    void ShiftControls() {
        ShiftForwards = UI::Checkbox("Shift Forwards", ShiftForwards);
        UI::SameLine();
        ShiftIsRow = UI::Checkbox("Shift Row", ShiftIsRow);
        ShiftIndex = UI::InputInt("Shift Index", ShiftIndex);

        if (PowerupAction("Execute Shift")) {
            Powerups::PowerupEffectBoardShift(ShiftIsRow, ShiftIndex, ShiftForwards);
        }
    }

    void SpecificTileControls() {
        PowerupTileIndex = UI::InputInt("Target Tile Index", PowerupTileIndex);
        
        if (PowerupAction("Rainbow Tile")) {
            Powerups::PowerupEffectRainbowTile(PowerupTileIndex);
        }
        UI::SameLine();
        if (PowerupAction("Rally (10 mins)")) {
            Powerups::PowerupEffectRally(PowerupTileIndex, 600000);
        }
        UI::SameLine();
        if (PowerupAction("Jail Yourself (15 mins)")) {
            PlayerRef localPlayer();
            localPlayer.uid = Profile.uid;
            localPlayer.name = Profile.name;

            Powerups::PowerupEffectJail(PowerupTileIndex, localPlayer, 900000);
        }
    }

    bool PowerupAction(const string&in text) {
        return UI::Button(text);
    }
}
