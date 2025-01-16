
namespace UIDevGameStat {
    void Render() {
        UI::Text("Current Tile Index = " + Gamemaster::GetCurrentTileIndex());
        UI::Text("Start Time = " + Match.startTime);
        UI::Text("Overtime Start Time = " + Match.overtimeStartTime);
        UI::Text("End Time = " + Match.endState.endTime);
    }
}
