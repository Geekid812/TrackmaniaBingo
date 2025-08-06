
namespace UIDevPowerups {
    bool ShiftForwards;
    bool ShiftIsRow;
    int ShiftIndex;

    void Render() {
        UI::Text(Icons::ExclamationTriangle + " Only for testing use, using this in a live game will cause desync with the game state!");

        UIColor::Crimson();

        ShiftForwards = UI::Checkbox("Shift Forwards", ShiftForwards);
        ShiftIsRow = UI::Checkbox("Shift Row", ShiftIsRow);
        ShiftIndex = UI::InputInt("Shift Index", ShiftIndex);

        if (PowerupAction("Execute Shift")) {
            Powerups::PowerupEffectBoardShift(ShiftIsRow, ShiftIndex, ShiftForwards);
        }

        UIColor::Reset();
    }

    bool PowerupAction(const string&in text) {
        UI::SetNextItemWidth(300);
        return UI::Button(text);
    }
}
