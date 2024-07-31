
namespace UIRoomSettings {
    const uint GRID_SIZE_MIN = 3;
    const uint GRID_SIZE_MAX = 8;
    const int TIMELIMIT_MAX = 180;
    const int NOBINGO_MAX = 120;
    const float CHECKBOXES_ALIGN_X = 200;
    const float GAME_SETTINGS_ALIGN_X = 180;

    FeaturedMappack@ SelectedPack;
    int State;

    void RoomNameInput() {
        UITools::AlignedLabel(Icons::Pencil + "  Room Name");
        UI::SetNextItemWidth(220);
        RoomConfig.name = UI::InputText("##bingoroomname", RoomConfig.name);
        if (RoomConfig.name == "") {
            RoomConfig.name = User::GetLocalUsername() + "'s Bingo Room";
        }
    }

    void PlayerLimitToggle() {
        UITools::AlignedLabel(Icons::User + "  Enable Player Limit");
        Layout::MoveTo(CHECKBOXES_ALIGN_X * UI::GetScale());
        bool toggle = UI::Checkbox("##bingomaxplayers", hasPlayerLimit(RoomConfig));
        if (toggle != hasPlayerLimit(RoomConfig)) RoomConfig.size = toggle ? 4 : 0;
    }

    void PlayerLimitInput() {
        UITools::AlignedLabel(Icons::Users + "  Maximum");
        UI::SetNextItemWidth(200);
        RoomConfig.size = Math::Clamp(UI::InputInt(" players allowed", RoomConfig.size), 2, 1000);
    }

    void RandomizeToggle() {
        UITools::AlignedLabel(Icons::Random + "  Randomize Teams");
        Layout::MoveTo(CHECKBOXES_ALIGN_X * UI::GetScale());
        RoomConfig.randomize = UI::Checkbox("##bingorandomize", RoomConfig.randomize);
    }

    void AccessToggle() {
        UI::SetCursorPos(UI::GetCursorPos() - vec2(0, 4));
        if (RoomConfig.public) {
            UIColor::DarkGreen();
            if (UI::Button(Icons::Unlock + " Public")) {
                RoomConfig.public = false;
            }
            UIColor::Reset();
        } else {
            UIColor::Red();
            if (UI::Button(Icons::Lock + " Private")) {
                RoomConfig.public = true;
            }
            UIColor::Reset();
        }
    }

    void GridSizeSelector() {
        UITools::AlignedLabel(Icons::Th + "  Grid Size");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        auto result = UITools::MixedInputButton(MatchConfig.gridSize + "x" + MatchConfig.gridSize, "bingogridsize", 3, 8, 1, MatchConfig.gridSize, LoadState(0));
        MatchConfig.gridSize = result.value;
        StoreState(0, result.state);
    }

    void MapModeSelector() {
        bool disabled = false;
#if TURBO
        MatchConfig.selection = MapMode::Campaign;
        @SelectedPack = null;
        disabled = true;
#endif
        UI::BeginDisabled(disabled);
        UITools::AlignedLabel(Icons::MapO + "  Map Selection");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        UI::SetNextItemWidth(250);
        if (UI::BeginCombo("##bingomaps", @SelectedPack != null ? SelectedPack.name : stringof(MatchConfig.selection))) {

            if (UI::Selectable(stringof(MapMode::RandomTMX), MatchConfig.selection == MapMode::RandomTMX)) {
                MatchConfig.selection = MapMode::RandomTMX;
                @SelectedPack = null;
            }

            if (UI::Selectable(stringof(MapMode::Tags), MatchConfig.selection == MapMode::Tags)) {
                MatchConfig.selection = MapMode::Tags;
                @SelectedPack = null;
            }

            if (UI::Selectable(stringof(MapMode::Mappack), MatchConfig.selection == MapMode::Mappack && @SelectedPack == null)) {
                MatchConfig.selection = MapMode::Mappack;
                @SelectedPack = null;
            }

            for (uint i = 0; i < Config::FeaturedMappacks.Length; i++) {
                FeaturedMappack pack = Config::FeaturedMappacks[i];
                if (UI::Selectable("\\$ff8Featured Mappack: \\$z" + pack.name, @SelectedPack != null && SelectedPack.tmxid == pack.tmxid)) {
                    MatchConfig.selection = MapMode::Mappack;
                    MatchConfig.mappackId = pack.tmxid;
                    @SelectedPack = pack;
                }
            }

            UI::EndCombo();
        }
        UI::EndDisabled();
    }

    void MapSelectButton() {
        if (MatchConfig.campaignSelection.Length < 7) {
            MatchConfig.campaignSelection = {0, 0, 0, 0, 0, 0, 0};
        }

        UIColor::Crimson();
        if (UI::Button(Icons::Map + " Select Maps")) {
            UIMapSelect::Visible = !UIMapSelect::Visible;
        }
        UIColor::Reset();
    }

    void TimeLimitControl() {
        UITools::AlignedLabel(Icons::ClockO + "  Time Limit");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        string label = TimeFormat(MatchConfig.timeLimit);
        if (MatchConfig.timeLimit == 0) label = "\\$888Disabled";
        auto result = UITools::MixedInputButton(label, "bingotimelimit", 0, TIMELIMIT_MAX, 15, MatchConfig.timeLimit / 60000, LoadState(1));
        MatchConfig.timeLimit = result.value * 60000;
        StoreState(1, result.state);
    }

    void NoBingoTimeControl() {
        UITools::AlignedLabel(Icons::LifeRing + "  Grace Period");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        string label = TimeFormat(MatchConfig.noBingoDuration);
        if (MatchConfig.noBingoDuration == 0) label = "\\$888Disabled";
        auto result = UITools::MixedInputButton(label, "nobingotime", 0, NOBINGO_MAX, 5, MatchConfig.noBingoDuration / 60000, LoadState(2));
        MatchConfig.noBingoDuration = result.value * 60000;
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

    string TimeFormat(int64 millis) {
        int hours = millis / (60 * 60000);
        int minutes = (millis / 60000) % 60;
        if (hours > 0) {
            return hours + "h" + (minutes > 0 ? " " + minutes + "min" : "");
        }
        return minutes + "min";
    }

    void MappackIdInput() {
        UITools::AlignedLabel(Icons::Exchange + "  TMX Mappack ID");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        UI::SetNextItemWidth(132);
        MatchConfig.mappackId = UI::InputInt("##bingomappack", MatchConfig.mappackId, 0);
    }

    void MapTagSelector() {
        // FIX: mapTag should not be 0, as it is invalid. Correct it if it was loaded from an invalid LastConfig
        MatchConfig.mapTag = Math::Max(MatchConfig.mapTag, 1);

        UITools::AlignedLabel(Icons::Tag + "  Selected Map Tag");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        UI::SetNextItemWidth(250);
        if (!MXTags::TagsLoaded()) {
            UI::BeginDisabled();
            UI::InputText("##maptaginput", "...", false);
            UI::EndDisabled();
            return;
        }
        if (UI::BeginCombo("##bingomaptag", MXTags::GetTag(MatchConfig.mapTag).name)) {
            for (uint i = 0; i < MXTags::Tags.Length; i++) {
                MXTags::Tag tag = MXTags::Tags[i];
                if (UI::Selectable(tag.name, tag.id == MatchConfig.mapTag)) {
                    MatchConfig.mapTag = tag.id;
                }
            }
            UI::EndCombo();
        }
    }

    void TargetMedalSelector() {
        UITools::AlignedLabel(Icons::Kenney::ButtonCircle + "  Target Medal");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
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
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        MatchConfig.overtime = UI::Checkbox("##bingoovertime", MatchConfig.overtime);
    }

    void FFAToggle() {
        UITools::AlignedLabel(Icons::Users + " Enable Free For All");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        MatchConfig.freeForAll = UI::Checkbox("##bingoffa", MatchConfig.freeForAll);
    }

    void RerollsToggle() {
        UITools::AlignedLabel(Icons::Kenney::ReloadInverse + " Enable Map Rerolls");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        MatchConfig.rerolls = UI::Checkbox("##bingorerolls", MatchConfig.rerolls);
        UI::SameLine();
        UITools::HelpTooltip("Players can vote to reroll an unclaimed map if the majority of players agree.");
    }

    void CompetitvePatchToggle() {
        UITools::AlignedLabel(Icons::Trophy + " Competitive Patch");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        MatchConfig.competitvePatch = UI::Checkbox("##bingopatch", MatchConfig.competitvePatch);
        UI::SameLine();
        UITools::HelpTooltip("In game map replays will be disabled.");
    }

    void TotalTimeIndicator() {
        UITools::AlignedLabel(Icons::PlayCircle + "  Total Game Time: " + TimeFormat(MatchConfig.timeLimit + MatchConfig.noBingoDuration));
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
            RoomConfig.randomize = false;
        }

        if (hasPlayerLimit(RoomConfig)) {
            PlayerLimitInput();
        }

        UI::NewLine();
        UITools::SectionHeader("Game Settings");
        MapModeSelector();
        if (MatchConfig.selection == MapMode::Campaign) {
            UI::SameLine();
            MapSelectButton();
        }
        if (MatchConfig.selection == MapMode::Mappack) {
            MappackIdInput();
        }
        if (MatchConfig.selection == MapMode::Tags) {
            MapTagSelector();
        }
        TargetMedalSelector();
        GridSizeSelector();
        TimeLimitControl();
        NoBingoTimeControl();
        if (MatchConfig.timeLimit != 0) {
            OvertimeToggle();
        }
        FFAToggle();
        RerollsToggle();
        CompetitvePatchToggle();
        if (MatchConfig.noBingoDuration != 0 && MatchConfig.timeLimit != 0) TotalTimeIndicator();
    }

    void SaveConfiguredSettings() {
        Json::Value@ configs = Json::Object();
        configs["room"] = RoomConfiguration::Serialize(RoomConfig);
        configs["game"] = MatchConfiguration::Serialize(MatchConfig);
        PersistantStorage::LastConfig = Json::Write(configs);
    }
}
