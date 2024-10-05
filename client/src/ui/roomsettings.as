
namespace UIRoomSettings {
    const uint GRID_SIZE_MIN = 3;
    const uint GRID_SIZE_MAX = 8;
    const int TIMELIMIT_MAX = 180;
    const int NOBINGO_MAX = 120;
    const float CHECKBOXES_ALIGN_X = 180;
    const float GAME_SETTINGS_ALIGN_X = 180;
    const string SETTING_COLOR_PREFIX = "\\$ff8";

    FeaturedMappack@ SelectedPack;
    int State;

    void RoomNameInput() {
        UITools::AlignedLabel(SETTING_COLOR_PREFIX + Icons::Pencil + "  \\$zRoom Name");

        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        UI::SetNextItemWidth(220);
        RoomConfig.name = UI::InputText("##bingoroomname", RoomConfig.name);
        if (RoomConfig.name == "") {
            RoomConfig.name = User::GetLocalUsername() + "'s Bingo Room";
        }
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
        UITools::AlignedLabel(SETTING_COLOR_PREFIX + Icons::Th + "  \\$zGrid Size");
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
        UITools::AlignedLabel(SETTING_COLOR_PREFIX + Icons::MapO + "  \\$zMap Selection");
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
        UITools::AlignedLabel(SETTING_COLOR_PREFIX + Icons::ClockO + "  \\$zTime Limit");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        string label = TimeFormat(GameConfig.mainDuration);
        if (GameConfig.mainDuration == 0) label = "\\$888Disabled";
        auto result = UITools::MixedInputButton(label, "bingotimelimit", 0, TIMELIMIT_MAX, 15, GameConfig.mainDuration / 60000, LoadState(1));
        GameConfig.mainDuration = result.value * 60000;
        StoreState(1, result.state);
    }

    void NoBingoTimeControl() {
        UITools::AlignedLabel(SETTING_COLOR_PREFIX + Icons::LifeRing + "  \\$zGrace Period");
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
        UITools::AlignedLabel(SETTING_COLOR_PREFIX + Icons::Exchange + "  \\$zTMX Mappack ID");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        UI::SetNextItemWidth(132);
        int mappackId = 0; // TODO: work on map loading
        mappackId = UI::InputInt("##bingomappack", mappackId, 0);
    }

    void MapTagSelector() {
        // TODO: work on map loading
        int mapTag = 0;
        mapTag = Math::Max(mapTag, 1);

        UITools::AlignedLabel(SETTING_COLOR_PREFIX + Icons::Tag + "  \\$zSelected Map Tag");
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
        UITools::AlignedLabel(SETTING_COLOR_PREFIX + Icons::Kenney::ButtonCircle + "  \\$zTarget Medal");
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
        UITools::AlignedLabel(SETTING_COLOR_PREFIX + Icons::PlusSquare + "  \\$zEnable Overtime");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        GameConfig.hasOvertime = UI::Checkbox("##bingoovertime", GameConfig.hasOvertime);
    }

    void FFAToggle() {
        UITools::AlignedLabel(SETTING_COLOR_PREFIX + Icons::Users + "  \\$zEnable Free For All");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        GameConfig.hasFreeForAll = UI::Checkbox("##bingoffa", GameConfig.hasFreeForAll);

        UI::SameLine();
        UITools::HelpTooltip("Everyone is on their own team.");
    }

    void RerollsToggle() {
        UITools::AlignedLabel(SETTING_COLOR_PREFIX + Icons::Kenney::ReloadInverse + "  \\$zEnable Map Rerolls");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        GameConfig.hasRerolls = UI::Checkbox("##bingorerolls", GameConfig.hasRerolls);

        UI::SameLine();
        UITools::HelpTooltip("All players can vote to reroll an unclaimed map.");
    }

    void CompetitvePatchToggle() {
        UITools::AlignedLabel(SETTING_COLOR_PREFIX + Icons::Trophy + "  \\$zCompetitive Patch");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        GameConfig.hasCompetitvePatch = UI::Checkbox("##bingopatch", GameConfig.hasCompetitvePatch);

        UI::SameLine();
        UITools::HelpTooltip("Ingame replays will be disabled.");
    }

    void TotalTimeIndicator() {
        UITools::AlignedLabel(SETTING_COLOR_PREFIX + Icons::PlayCircle + "  \\$zTotal Game Time: " + TimeFormat(GameConfig.mainDuration + GameConfig.noBingoDuration));
        UI::NewLine();
    }

    void SettingsView() {
        UITools::SectionHeader("Game Settings");
        RoomNameInput();
        UI::SameLine();
        AccessToggle();

        MapModeSelector();
        TargetMedalSelector();
        GridSizeSelector();
        TimeLimitControl();
        NoBingoTimeControl();

        if (GameConfig.mainDuration != 0) {
            OvertimeToggle();
        }
        if (GameConfig.noBingoDuration != 0 && GameConfig.mainDuration != 0) {
            TotalTimeIndicator();   
        }

        UI::NewLine();
        UITools::SectionHeader("Challenge Options");

        FFAToggle();
        RerollsToggle();
        CompetitvePatchToggle();

    }
}
