
namespace UIDevGameStat {
    void Render() {
        UI::SeparatorText("Current Match");

        if (UI::BeginTable("bingodevstat", 2, UI::TableFlags::RowBg | UI::TableFlags::SizingFixedFit)) {
            StatEntry("UID", Match.uid);
            StatEntry("Join code", Match.joinCode);
            StatEntry("Start time", tostring(Match.startTime));
            StatEntry("Overtime start time", tostring(Match.overtimeStartTime));
            StatEntry("End time", tostring(Match.endState.endTime));
            StatEntry("Phase", tostring(Match.phase));
            StatEntry("Room config", Json::Write(RoomConfiguration::Serialize(Match.roomConfig)));
            StatEntry("Match config", Json::Write(MatchConfiguration::Serialize(Match.config)));
            StatEntry("Can reroll", tostring(Match.canReroll));
            UI::EndTable();
        }

        UI::SeparatorText("Local State");
        UI::TextWrapped("Current Tile Index = " + Gamemaster::GetCurrentTileIndex());
    }

    void StatEntry(const string&in key, const string&in value) {
        UI::TableNextColumn();
        UI::Text(key);

        UI::TableNextColumn();
        Font::Set(Font::Style::Mono, Font::Size::Medium);

        UI::TextWrapped(value);

        Font::Unset();
    }
}
