
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
        auto result = UITools::MixedInputButton(GameConfig.gridWidth + "x" + GameConfig.gridHeight, "bingogridsize", 3, 8, 1, GameConfig.gridWidth, LoadState(0));
        GameConfig.gridWidth = result.value;
        GameConfig.gridHeight = result.value; // TODO: split selector?
        StoreState(0, result.state);
    }

    void MapModeSelector() {
        MapMode mapMode = MapMode::RandomTMX; // TODO: work on loading maps

        bool disabled = false;
#if TURBO
        mapMode = MapMode::Campaign;
        @SelectedPack = null;
        disabled = true;
#endif
        UI::BeginDisabled(disabled);
        UITools::AlignedLabel(Icons::MapO + "  Map Selection");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        UI::SetNextItemWidth(250);
        if (UI::BeginCombo("##bingomaps", @SelectedPack != null ? SelectedPack.name : stringof(mapMode))) {

            if (UI::Selectable(stringof(MapMode::RandomTMX), mapMode == MapMode::RandomTMX)) {

            }

            if (UI::Selectable(stringof(MapMode::Tags), mapMode == MapMode::Tags)) {

            }

            if (UI::Selectable(stringof(MapMode::Mappack), mapMode == MapMode::Mappack && @SelectedPack == null)) {

            }

            for (uint i = 0; i < Config::FeaturedMappacks.Length; i++) {
                FeaturedMappack pack = Config::FeaturedMappacks[i];
                if (UI::Selectable("\\$ff8Featured Mappack: \\$z" + pack.name, @SelectedPack != null && SelectedPack.tmxid == pack.tmxid)) {

                }
            }

            UI::EndCombo();
        }
        UI::EndDisabled();
    }

    void TimeLimitControl() {
        UITools::AlignedLabel(Icons::ClockO + "  Time Limit");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        string label = TimeFormat(GameConfig.mainDuration);
        if (GameConfig.mainDuration == 0) label = "\\$888Disabled";
        auto result = UITools::MixedInputButton(label, "bingotimelimit", 0, TIMELIMIT_MAX, 15, GameConfig.mainDuration / 60000, LoadState(1));
        GameConfig.mainDuration = result.value * 60000;
        StoreState(1, result.state);
    }

    void NoBingoTimeControl() {
        UITools::AlignedLabel(Icons::LifeRing + "  Grace Period");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        string label = TimeFormat(GameConfig.noBingoDuration);
        if (GameConfig.noBingoDuration == 0) label = "\\$888Disabled";
        auto result = UITools::MixedInputButton(label, "nobingotime", 0, NOBINGO_MAX, 5, GameConfig.noBingoDuration / 60000, LoadState(2));
        GameConfig.noBingoDuration = result.value * 60000;
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
        int mappackId = 0; // TODO: work on map loading
        mappackId = UI::InputInt("##bingomappack", mappackId, 0);
    }

    void MapTagSelector() {
        // TODO: work on map loading
        int mapTag = 0;
        mapTag = Math::Max(mapTag, 1);

        UITools::AlignedLabel(Icons::Tag + "  Selected Map Tag");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        UI::SetNextItemWidth(250);
        if (!MXTags::TagsLoaded()) {
            UI::BeginDisabled();
            UI::InputText("##maptaginput", "...", false);
            UI::EndDisabled();
            return;
        }
        if (UI::BeginCombo("##bingomaptag", MXTags::GetTag(mapTag).name)) {
            for (uint i = 0; i < MXTags::Tags.Length; i++) {
                MXTags::Tag tag = MXTags::Tags[i];
                if (UI::Selectable(tag.name, tag.id == mapTag)) {
                    mapTag = tag.id;
                }
            }
            UI::EndCombo();
        }
    }

    void TargetMedalSelector() {
        UITools::AlignedLabel(Icons::Kenney::ButtonCircle + "  Target Medal");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        UI::SetNextItemWidth(250);
        if (UI::BeginCombo("##bingomedal", stringof(GameConfig.targetMedal))) {
            if (UI::Selectable(stringof(Medal::Author), GameConfig.targetMedal == Medal::Author)) {
                GameConfig.targetMedal = Medal::Author;
            }

            if (UI::Selectable(stringof(Medal::Gold), GameConfig.targetMedal == Medal::Gold)) {
                GameConfig.targetMedal = Medal::Gold;
            }

            if (UI::Selectable(stringof(Medal::Silver), GameConfig.targetMedal == Medal::Silver)) {
                GameConfig.targetMedal = Medal::Silver;
            }
            if (UI::Selectable(stringof(Medal::Bronze), GameConfig.targetMedal == Medal::Bronze)) {
                GameConfig.targetMedal = Medal::Bronze;
            }
            if (UI::Selectable(stringof(Medal::None), GameConfig.targetMedal == Medal::None)) {
                GameConfig.targetMedal = Medal::None;
            }

            UI::EndCombo();
        }
    }

    void OvertimeToggle() {
        UITools::AlignedLabel(Icons::PlusSquare + " Enable Overtime");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        GameConfig.hasOvertime = UI::Checkbox("##bingoovertime", GameConfig.hasOvertime);
    }

    void FFAToggle() {
        UITools::AlignedLabel(Icons::Users + " Enable Free For All");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        GameConfig.hasFreeForAll = UI::Checkbox("##bingoffa", GameConfig.hasFreeForAll);
    }

    void RerollsToggle() {
        UITools::AlignedLabel(Icons::Kenney::ReloadInverse + " Enable Map Rerolls");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        GameConfig.hasRerolls = UI::Checkbox("##bingorerolls", GameConfig.hasRerolls);
        UI::SameLine();
        UITools::HelpTooltip("All players can vote to reroll an unclaimed map.");
    }

    void CompetitvePatchToggle() {
        UITools::AlignedLabel(Icons::Trophy + " Competitive Patch");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        GameConfig.hasCompetitvePatch = UI::Checkbox("##bingopatch", GameConfig.hasCompetitvePatch);
        UI::SameLine();
        UITools::HelpTooltip("In game map replays will be disabled.");
    }

    void TotalTimeIndicator() {
        UITools::AlignedLabel(Icons::PlayCircle + "  Total Game Time: " + TimeFormat(GameConfig.mainDuration + GameConfig.noBingoDuration));
        UI::NewLine();
    }

    void SettingsView() {
        UITools::SectionHeader("Room Settings");
        RoomNameInput();
        UI::SameLine();
        AccessToggle();
        PlayerLimitToggle();

        UI::BeginDisabled(GameConfig.hasFreeForAll);
        RandomizeToggle();
        UI::EndDisabled();
        if (GameConfig.hasFreeForAll) {
            RoomConfig.randomize = false;
        }

        if (hasPlayerLimit(RoomConfig)) {
            PlayerLimitInput();
        }

        UI::NewLine();
        UITools::SectionHeader("Game Settings");

        MapModeSelector();
        TargetMedalSelector();
        GridSizeSelector();
        TimeLimitControl();
        NoBingoTimeControl();

        if (GameConfig.mainDuration != 0) {
            OvertimeToggle();
        }

        FFAToggle();
        RerollsToggle();
        CompetitvePatchToggle();

        if (GameConfig.noBingoDuration != 0 && GameConfig.mainDuration != 0) TotalTimeIndicator();
    }

    void SaveConfiguredSettings() {
        Json::Value@ configs = Json::Object();
        configs["room"] = RoomConfiguration::Serialize(RoomConfig);
        configs["game"] = GameRules::Serialize(GameConfig);
        PersistantStorage::LastConfig = Json::Write(configs);
    }
}
