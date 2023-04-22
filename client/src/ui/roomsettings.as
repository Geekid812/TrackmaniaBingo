
namespace UIRoomSettings {
    const uint[] TimeLimitOptions = { 15, 30, 45, 60, 90, 120 };
    const uint GridSizeMin = 3;
    const uint GridSizeMax = 8;
    const float CheckboxesAlignX = 180;
    const float GameSettingsAlignX = 150;

    FeaturedMappack@ SelectedPack;
    int State;

    void RoomNameInput() {
        UITools::AlignedLabel(Icons::Pencil + "  Room Name");
        UI::SetNextItemWidth(220);
        RoomConfig.Name = UI::InputText("##bingoroomname", RoomConfig.Name);
        if (RoomConfig.Name == "" && LocalUsername != "") {
            RoomConfig.Name = LocalUsername + "'s Bingo Room";
        }
    }

    void PlayerLimitToggle() {
        UITools::AlignedLabel(Icons::User + "  Enable Player Limit");
        LayoutTools::MoveTo(CheckboxesAlignX);
        RoomConfig.HasPlayerLimit = UI::Checkbox("##bingomaxplayers", RoomConfig.HasPlayerLimit);
    }

    void PlayerLimitInput() {
        UITools::AlignedLabel(Icons::Users + "  Maximum");
        UI::SetNextItemWidth(200);
        RoomConfig.MaxPlayers = Math::Clamp(UI::InputInt(" players allowed", RoomConfig.MaxPlayers), 2, 1000);
    }

    void RandomizeToggle() {
        UITools::AlignedLabel(Icons::Random + "  Randomize Teams");
        LayoutTools::MoveTo(CheckboxesAlignX);
        RoomConfig.RandomizeTeams = UI::Checkbox("##bingorandomize", RoomConfig.RandomizeTeams);
    }

    void AccessToggle() {
        if (RoomConfig.IsPublic) {
            UIColor::DarkGreen();
            if (UI::Button(Icons::Unlock + " Public")) {
                RoomConfig.IsPublic = false;
            }
            UIColor::Reset();
        } else {
            UIColor::Red();
            if (UI::Button(Icons::Lock + " Private")) {
                RoomConfig.IsPublic = true;
            }
            UIColor::Reset();
        }
    }

    void GridSizeSelector() {
        UITools::AlignedLabel(Icons::Th + "  Grid Size");
        LayoutTools::MoveTo(GameSettingsAlignX);
        auto result = UITools::MixedInputButton(RoomConfig.GridSize + "x" + RoomConfig.GridSize, "bingogridsize", 3, 8, 1, RoomConfig.GridSize, LoadState(0));
        RoomConfig.GridSize = result.value;
        StoreState(0, result.state);
    }

    void MapModeSelector() {
        UITools::AlignedLabel(Icons::MapO + "  Map Selection");
        LayoutTools::MoveTo(GameSettingsAlignX);
        UI::SetNextItemWidth(250);
        if (UI::BeginCombo("##bingomaps", @SelectedPack != null ? SelectedPack.name : stringof(RoomConfig.MapSelection))) {
            if (UI::Selectable(stringof(MapMode::TOTD), RoomConfig.MapSelection == MapMode::TOTD)) {
                RoomConfig.MapSelection = MapMode::TOTD;
                @SelectedPack = null;
            }

            if (UI::Selectable(stringof(MapMode::MXRandom), RoomConfig.MapSelection == MapMode::MXRandom)) {
                RoomConfig.MapSelection = MapMode::MXRandom;
                @SelectedPack = null;
            }

            if (UI::Selectable(stringof(MapMode::Mappack), RoomConfig.MapSelection == MapMode::Mappack && @SelectedPack == null)) {
                RoomConfig.MapSelection = MapMode::Mappack;
                @SelectedPack = null;
            }

            for (uint i = 0; i < Config::featuredMappacks.Length; i++) {
                FeaturedMappack pack = Config::featuredMappacks[i];
                if (UI::Selectable("\\$ff8Featured Mappack: \\$z" + pack.name, @SelectedPack != null && SelectedPack.tmxid == pack.tmxid)) {
                    RoomConfig.MapSelection = MapMode::Mappack;
                    RoomConfig.MappackId = pack.tmxid;
                    @SelectedPack = pack;
                }
            }

            UI::EndCombo();
        }
    }

    void TimeLimitControl() {
        UITools::AlignedLabel(Icons::ClockO + "  Time Limit");
        LayoutTools::MoveTo(GameSettingsAlignX);
        string label = TimeFormat(RoomConfig.MinutesLimit);
        if (RoomConfig.MinutesLimit == 0) label = "\\$888Disabled";
        auto result = UITools::MixedInputButton(label, "bingotimelimit", 0, 120, 15, RoomConfig.MinutesLimit, LoadState(1));
        RoomConfig.MinutesLimit = result.value;
        StoreState(1, result.state);
    }

    void NoBingoTimeControl() {
        UITools::AlignedLabel(Icons::LifeRing + "  Grace Period");
        LayoutTools::MoveTo(GameSettingsAlignX);
        string label = TimeFormat(RoomConfig.NoBingoMinutes);
        if (RoomConfig.NoBingoMinutes == 0) label = "\\$888Disabled";
        auto result = UITools::MixedInputButton(label, "nobingotime", 0, 60, 5, RoomConfig.NoBingoMinutes, LoadState(2));
        RoomConfig.NoBingoMinutes = result.value;
        StoreState(2, result.state);

        UI::SameLine();
        UITools::HelpTooltip("If enabled, bingos cannot be scored for the first X minutes.");
    }

    int LoadState(int id) {
        return (State >> (2 * id)) & 0b11;
    }

    void StoreState(int id, int state) {
        State &= 0xffff - (0b11 << (2 * id));
        State |= (state & 0b11) << (2 * id);
    }

    string TimeFormat(int minutes) {
        int hours = minutes / 60;
        minutes %= 60;
        if (hours > 0) {
            return hours + "h" + (minutes > 0 ? " " + minutes + "min" : "");
        }
        return minutes + "min";
    }

    void MappackIdInput() {
        UITools::AlignedLabel(Icons::Exchange + "  TMX Mappack ID");
        LayoutTools::MoveTo(GameSettingsAlignX);
        UI::SetNextItemWidth(132);
        RoomConfig.MappackId = UI::InputInt("##bingomappack", RoomConfig.MappackId, 0);
    }

    void TargetMedalSelector() {
        UITools::AlignedLabel(Icons::Kenney::ButtonCircle + "  Target Medal");
        LayoutTools::MoveTo(GameSettingsAlignX);
        UI::SetNextItemWidth(250);
        if (UI::BeginCombo("##bingomedal", stringof(RoomConfig.TargetMedal))) {
            if (UI::Selectable(stringof(Medal::Author), RoomConfig.TargetMedal == Medal::Author)) {
                RoomConfig.TargetMedal = Medal::Author;
            }

            if (UI::Selectable(stringof(Medal::Gold), RoomConfig.TargetMedal == Medal::Gold)) {
                RoomConfig.TargetMedal = Medal::Gold;
            }

            if (UI::Selectable(stringof(Medal::Silver), RoomConfig.TargetMedal == Medal::Silver)) {
                RoomConfig.TargetMedal = Medal::Silver;
            }
            if (UI::Selectable(stringof(Medal::Bronze), RoomConfig.TargetMedal == Medal::Bronze)) {
                RoomConfig.TargetMedal = Medal::Bronze;
            }
            if (UI::Selectable(stringof(Medal::None), RoomConfig.TargetMedal == Medal::None)) {
                RoomConfig.TargetMedal = Medal::None;
            }

            UI::EndCombo();
        }
    }

    void OvertimeToggle() {
        UITools::AlignedLabel(Icons::PlusSquare + " Enable Overtime");
        LayoutTools::MoveTo(GameSettingsAlignX);
        RoomConfig.Overtime = UI::Checkbox("##bingoovertime", RoomConfig.Overtime);
    }

    void TotalTimeIndicator() {
        UITools::AlignedLabel(Icons::PlayCircle + "  Total Game Time: " + TimeFormat(RoomConfig.MinutesLimit + RoomConfig.NoBingoMinutes));
        UI::NewLine();
    }

    void SettingsView() {
        UITools::SectionHeader("Room Settings");
        RoomNameInput();
        UI::SameLine();
        AccessToggle();
        PlayerLimitToggle();
        RandomizeToggle();
        if (RoomConfig.HasPlayerLimit) {
            PlayerLimitInput();
        }

        UITools::SectionHeader("Game Settings");
        MapModeSelector();
        TargetMedalSelector();
        if (RoomConfig.MapSelection == MapMode::Mappack) {
            MappackIdInput();
        }
        GridSizeSelector();
        TimeLimitControl();
        NoBingoTimeControl();
        if (RoomConfig.MinutesLimit != 0) {
            OvertimeToggle();
            if (RoomConfig.NoBingoMinutes != 0) TotalTimeIndicator();
        }
    }
}