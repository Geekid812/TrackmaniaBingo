
namespace UIRoomSettings {
    const uint GRID_SIZE_MIN = 3;
    const uint GRID_SIZE_MAX = 8;
    const int TIMELIMIT_MAX = 180;
    const int NOBINGO_MAX = 120;
    const float CHECKBOXES_ALIGN_X = 180;
    const float GAME_SETTINGS_ALIGN_X = 150;

    FeaturedMappack@ SelectedPack;
    int State;

    void RoomNameInput() {
        UITools::AlignedLabel(Icons::Pencil + "  Room Name");
        UI::SetNextItemWidth(220);
        RoomConfig.name = UI::InputText("##bingoroomname", RoomConfig.name);
        if (RoomConfig.name == "" && LocalUsername != "") {
            RoomConfig.name = LocalUsername + "'s Bingo Room";
        }
    }

    void PlayerLimitToggle() {
        UITools::AlignedLabel(Icons::User + "  Enable Player Limit");
        LayoutTools::MoveTo(CHECKBOXES_ALIGN_X);
        RoomConfig.hasPlayerLimit = UI::Checkbox("##bingomaxplayers", RoomConfig.hasPlayerLimit);
    }

    void PlayerLimitInput() {
        UITools::AlignedLabel(Icons::Users + "  Maximum");
        UI::SetNextItemWidth(200);
        RoomConfig.maxPlayers = Math::Clamp(UI::InputInt(" players allowed", RoomConfig.maxPlayers), 2, 1000);
    }

    void RandomizeToggle() {
        UITools::AlignedLabel(Icons::Random + "  Randomize Teams");
        LayoutTools::MoveTo(CHECKBOXES_ALIGN_X);
        RoomConfig.randomizeTeams = UI::Checkbox("##bingorandomize", RoomConfig.randomizeTeams);
    }

    void AccessToggle() {
        if (RoomConfig.isPublic) {
            UIColor::DarkGreen();
            if (UI::Button(Icons::Unlock + " Public")) {
                RoomConfig.isPublic = false;
            }
            UIColor::Reset();
        } else {
            UIColor::Red();
            if (UI::Button(Icons::Lock + " Private")) {
                RoomConfig.isPublic = true;
            }
            UIColor::Reset();
        }
    }

    void GridSizeSelector() {
        UITools::AlignedLabel(Icons::Th + "  Grid Size");
        LayoutTools::MoveTo(GAME_SETTINGS_ALIGN_X);
        auto result = UITools::MixedInputButton(MatchConfig.gridSize + "x" + MatchConfig.gridSize, "bingogridsize", 3, 8, 1, MatchConfig.gridSize, LoadState(0));
        MatchConfig.gridSize = result.value;
        StoreState(0, result.state);
    }

    void MapModeSelector() {
        UITools::AlignedLabel(Icons::MapO + "  Map Selection");
        LayoutTools::MoveTo(GAME_SETTINGS_ALIGN_X);
        UI::SetNextItemWidth(250);
        if (UI::BeginCombo("##bingomaps", @SelectedPack != null ? SelectedPack.name : stringof(MatchConfig.mapSelection))) {
            if (UI::Selectable(stringof(MapMode::TOTD), MatchConfig.mapSelection == MapMode::TOTD)) {
                MatchConfig.mapSelection = MapMode::TOTD;
                @SelectedPack = null;
            }

            if (UI::Selectable(stringof(MapMode::MXRandom), MatchConfig.mapSelection == MapMode::MXRandom)) {
                MatchConfig.mapSelection = MapMode::MXRandom;
                @SelectedPack = null;
            }

            if (UI::Selectable(stringof(MapMode::Mappack), MatchConfig.mapSelection == MapMode::Mappack && @SelectedPack == null)) {
                MatchConfig.mapSelection = MapMode::Mappack;
                @SelectedPack = null;
            }

            for (uint i = 0; i < Config::FeaturedMappacks.Length; i++) {
                FeaturedMappack pack = Config::FeaturedMappacks[i];
                if (UI::Selectable("\\$ff8Featured Mappack: \\$z" + pack.name, @SelectedPack != null && SelectedPack.tmxid == pack.tmxid)) {
                    MatchConfig.mapSelection = MapMode::Mappack;
                    MatchConfig.mappackId = pack.tmxid;
                    @SelectedPack = pack;
                }
            }

            UI::EndCombo();
        }
    }

    void TimeLimitControl() {
        UITools::AlignedLabel(Icons::ClockO + "  Time Limit");
        LayoutTools::MoveTo(GAME_SETTINGS_ALIGN_X);
        string label = TimeFormat(MatchConfig.minutesLimit);
        if (MatchConfig.minutesLimit == 0) label = "\\$888Disabled";
        auto result = UITools::MixedInputButton(label, "bingotimelimit", 0, TIMELIMIT_MAX, 15, MatchConfig.minutesLimit, LoadState(1));
        MatchConfig.minutesLimit = result.value;
        StoreState(1, result.state);
    }

    void NoBingoTimeControl() {
        UITools::AlignedLabel(Icons::LifeRing + "  Grace Period");
        LayoutTools::MoveTo(GAME_SETTINGS_ALIGN_X);
        string label = TimeFormat(MatchConfig.noBingoMinutes);
        if (MatchConfig.noBingoMinutes == 0) label = "\\$888Disabled";
        auto result = UITools::MixedInputButton(label, "nobingotime", 0, NOBINGO_MAX, 5, MatchConfig.noBingoMinutes, LoadState(2));
        MatchConfig.noBingoMinutes = result.value;
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
        LayoutTools::MoveTo(GAME_SETTINGS_ALIGN_X);
        UI::SetNextItemWidth(132);
        MatchConfig.mappackId = UI::InputInt("##bingomappack", MatchConfig.mappackId, 0);
    }

    void TargetMedalSelector() {
        UITools::AlignedLabel(Icons::Kenney::ButtonCircle + "  Target Medal");
        LayoutTools::MoveTo(GAME_SETTINGS_ALIGN_X);
        UI::SetNextItemWidth(250);
        if (UI::BeginCombo("##bingomedal", stringof(MatchConfig.targetMedal))) {
            if (UI::Selectable(stringof(Medal::Author), MatchConfig.targetMedal == Medal::Author)) {
                MatchConfig.targetMedal = Medal::Author;
            }

            if (UI::Selectable(stringof(Medal::Gold), MatchConfig.targetMedal == Medal::Gold)) {
                MatchConfig.targetMedal = Medal::Gold;
            }

            if (UI::Selectable(stringof(Medal::Silver), MatchConfig.targetMedal == Medal::Silver)) {
                MatchConfig.targetMedal = Medal::Silver;
            }
            if (UI::Selectable(stringof(Medal::Bronze), MatchConfig.targetMedal == Medal::Bronze)) {
                MatchConfig.targetMedal = Medal::Bronze;
            }
            if (UI::Selectable(stringof(Medal::None), MatchConfig.targetMedal == Medal::None)) {
                MatchConfig.targetMedal = Medal::None;
            }

            UI::EndCombo();
        }
    }

    void OvertimeToggle() {
        UITools::AlignedLabel(Icons::PlusSquare + " Enable Overtime");
        LayoutTools::MoveTo(GAME_SETTINGS_ALIGN_X);
        MatchConfig.overtime = UI::Checkbox("##bingoovertime", MatchConfig.overtime);
    }

    void FFAToggle() {
        UITools::AlignedLabel(Icons::Users + " Enable Free For All");
        LayoutTools::MoveTo(GAME_SETTINGS_ALIGN_X);
        MatchConfig.freeForAll = UI::Checkbox("##bingoffa", MatchConfig.freeForAll);
    }

    void TotalTimeIndicator() {
        UITools::AlignedLabel(Icons::PlayCircle + "  Total Game Time: " + TimeFormat(MatchConfig.minutesLimit + MatchConfig.noBingoMinutes));
        UI::NewLine();
    }

    void SettingsView() {
        UITools::SectionHeader("Room Settings");
        RoomNameInput();
        UI::SameLine();
        AccessToggle();
        PlayerLimitToggle();

        UI::BeginDisabled(MatchConfig.freeForAll);
        RandomizeToggle();
        UI::EndDisabled();
        if (MatchConfig.freeForAll) {
            RoomConfig.randomizeTeams = false;
        }

        if (RoomConfig.hasPlayerLimit) {
            PlayerLimitInput();
        }

        UI::NewLine();
        UITools::SectionHeader("Game Settings");
        MapModeSelector();
        TargetMedalSelector();
        if (MatchConfig.mapSelection == MapMode::Mappack) {
            MappackIdInput();
        }
        GridSizeSelector();
        TimeLimitControl();
        NoBingoTimeControl();
        if (MatchConfig.minutesLimit != 0) {
            OvertimeToggle();
        }
        // FFAToggle();
        if (MatchConfig.noBingoMinutes != 0 && MatchConfig.minutesLimit != 0) TotalTimeIndicator();
    }

    void SaveConfiguredSettings() {
        Json::Value@ configs = Json::Object();
        configs["room"] = RoomConfiguration::Serialize(RoomConfig);
        configs["game"] = MatchConfiguration::Serialize(MatchConfig);
        PersistantStorage::LastConfig = Json::Write(configs);
    }
}