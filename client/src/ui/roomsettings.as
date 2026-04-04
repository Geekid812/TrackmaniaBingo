
namespace UIRoomSettings {
    const uint GRID_SIZE_MIN = 3;
    const uint GRID_SIZE_MAX = 8;
    const int TIMELIMIT_MAX = 180;
    const int NOBINGO_MAX = 120;
    const float CHECKBOXES_ALIGN_X = 200;
    const float GAME_SETTINGS_ALIGN_X = 160;

    FeaturedMappack @SelectedPack;
    int State;
    string HoveredTrackSelect;

    void RoomNameInput() {
        UITools::AlignedLabel(Icons::Pencil + "  Room Name");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
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
        if (toggle != hasPlayerLimit(RoomConfig))
            RoomConfig.size = toggle ? 4 : 0;
    }

    void PlayerLimitInput() {
        UITools::AlignedLabel(Icons::Users + "  Maximum");
        UI::SetNextItemWidth(200);
        RoomConfig.size = Math::Clamp(UI::InputInt(" players allowed", RoomConfig.size), 2, 1000);
    }

    void RandomizeToggle() {
        UITools::AlignedLabel(Icons::Random + "  Randomize Teams");
        Layout::MoveTo(CHECKBOXES_ALIGN_X * UI::GetScale());
        RoomConfig.randomize =
            UI::Checkbox("##bingorandomize", RoomConfig.randomize) && !RoomConfig.hostControl;
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

    void LabelAdvancedSettings(const string&in title) {
        vec2 originalPosition = UI::GetCursorPos();
        UITools::AlignedLabel(title);
        Layout::MoveTo(originalPosition.x + GAME_SETTINGS_ALIGN_X * UI::GetScale());
    }

    void GridSizeSelector() {
        UITools::AlignedLabel(Icons::Th + "  Grid Size");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        auto result = UITools::MixedInputButton(MatchConfig.gridSize + "x" + MatchConfig.gridSize,
                                                "bingogridsize",
                                                3,
                                                8,
                                                1,
                                                MatchConfig.gridSize,
                                                LoadState(0));
        MatchConfig.gridSize = result.value;
        StoreState(0, result.state);
    }

    void MapModeSelector() {
        bool disabled = false;

        UI::BeginDisabled(disabled);
        UITools::AlignedLabel(Icons::MapO + "  Map Selection");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        UI::SetNextItemWidth(250);
        if (UI::BeginCombo("##bingomaps",
                           @SelectedPack != null ? SelectedPack.name
                                                 : stringof(MatchConfig.selection))) {

            if (UI::Selectable(stringof(MapMode::RandomTMX),
                               MatchConfig.selection == MapMode::RandomTMX)) {
                MatchConfig.selection = MapMode::RandomTMX;
                @SelectedPack = null;
            }

            if (UI::Selectable(stringof(MapMode::Tags), MatchConfig.selection == MapMode::Tags)) {
                MatchConfig.selection = MapMode::Tags;
                @SelectedPack = null;
            }

            if (UI::Selectable(stringof(MapMode::Mappack),
                               MatchConfig.selection == MapMode::Mappack &&
                                   @SelectedPack == null)) {
                MatchConfig.selection = MapMode::Mappack;
                @SelectedPack = null;
            }

            for (uint i = 0; i < Config::FeaturedMappacks.Length; i++) {
                FeaturedMappack pack = Config::FeaturedMappacks[i];
                if (UI::Selectable("\\$ff8Featured Mappack: \\$z" + pack.name,
                                   @SelectedPack != null && SelectedPack.tmxid == pack.tmxid)) {
                    MatchConfig.selection = MapMode::Mappack;
                    MatchConfig.mappackId = pack.tmxid;
                    @SelectedPack = pack;
                }
            }

            UI::EndCombo();
        }
        UI::EndDisabled();
    }

    void DiscoveryToggle() {
        LabelAdvancedSettings(Icons::Search + " Map Discovery");
        MatchConfig.discovery = UI::Checkbox("##bingodiscovery", MatchConfig.discovery);
        UI::SameLine();
        UITools::HelpTooltip("Excludes maps where any player in the match currently has a record on.");
    }

    void SecretToggle() {
        LabelAdvancedSettings(Icons::QuestionCircle + " Secret Records");
        MatchConfig.secret = UI::Checkbox("##bingosecret", MatchConfig.secret);
        UI::SameLine();
        UITools::HelpTooltip("All records from other players will be hidden until the end of the game.");
    }

    void TimeLimitControl() {
        UITools::AlignedLabel(Icons::ClockO + "  Time Limit");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        string label = TimeFormat(MatchConfig.timeLimit);
        if (MatchConfig.timeLimit == 0)
            label = "\\$888Disabled";
        auto result = UITools::MixedInputButton(label,
                                                "bingotimelimit",
                                                0,
                                                TIMELIMIT_MAX,
                                                15,
                                                MatchConfig.timeLimit / 60000,
                                                LoadState(1));
        MatchConfig.timeLimit = result.value * 60000;
        StoreState(1, result.state);
    }

    void NoBingoTimeControl() {
        UITools::AlignedLabel(Icons::LifeRing + "  Grace Period");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        string label = TimeFormat(MatchConfig.noBingoDuration);
        if (MatchConfig.noBingoDuration == 0)
            label = "\\$888Disabled";
        auto result = UITools::MixedInputButton(label,
                                                "nobingotime",
                                                0,
                                                NOBINGO_MAX,
                                                5,
                                                MatchConfig.noBingoDuration / 60000,
                                                LoadState(2));
        MatchConfig.noBingoDuration = result.value * 60000;
        StoreState(2, result.state);

        UI::SameLine();
        UITools::HelpTooltip("If enabled, bingos cannot be scored for the first X minutes.");
    }

    int LoadState(int id) { return (State >> (2 * id)) & 0b11; }

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
        UI::SetNextItemWidth(150);
        MatchConfig.mappackId = UI::InputInt("##bingomappack", MatchConfig.mappackId, 0);
    }

    void MapTagSelector() {
        // FIX: mapTag should not be less than 1, as it is invalid. Correct it if it was loaded from an
        // invalid LastConfig
        MatchConfig.mapTag = Math::Max(MatchConfig.mapTag, 1);

        UITools::AlignedLabel(Icons::Tag + "  Track Style");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        UI::SetNextItemWidth(250);
        if (!MXTags::TagsLoaded()) {
            UI::BeginDisabled();
            UI::InputText("##maptaginput", "...");
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
        UITools::AlignedLabel(Icons::Kenney::ButtonCircle + "  Medal Objective");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());
        UI::SetNextItemWidth(250);
        if (UI::BeginCombo("##bingomedal", stringof(MatchConfig.targetMedal))) {
            if (UI::Selectable(stringof(Medal::WR), MatchConfig.targetMedal == Medal::WR)) {
                MatchConfig.targetMedal = Medal::WR;
            }

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
        LabelAdvancedSettings(Icons::PlusSquare + " Enable Overtime");
        MatchConfig.overtime = UI::Checkbox("##bingoovertime", MatchConfig.overtime);
    }

    void LateJoinToggle() {
        LabelAdvancedSettings(Icons::SignIn + " Allow Late Joins");
        MatchConfig.lateJoin = UI::Checkbox("##bingolatejoin", MatchConfig.lateJoin);
        UI::SameLine();
        UITools::HelpTooltip("Players can still join after the game has started.");
    }

    void HostControlsSetupToggle() {
        LabelAdvancedSettings(Icons::Lock + " Host Controls Setup");
        RoomConfig.hostControl = UI::Checkbox("##bingohostcontrols", RoomConfig.hostControl);
        UI::SameLine();
        UITools::HelpTooltip("The room host assigns players to their respective teams. Players "
                             "cannot change their own team.");
    }

    void RerollsToggle() {
        LabelAdvancedSettings(Icons::Kenney::ReloadInverse + " Map Rerolls");
        MatchConfig.rerolls = UI::Checkbox("##bingorerolls", MatchConfig.rerolls);
        UI::SameLine();
        UITools::HelpTooltip(
            "Players can vote to reroll an unclaimed map if the majority of players agree.");
    }

    void CompetitvePatchToggle() {
        LabelAdvancedSettings(Icons::Trophy + " Competitive Patch");
        MatchConfig.competitvePatch = UI::Checkbox("##bingopatch", MatchConfig.competitvePatch) || MatchConfig.secret;
        UI::SameLine();
        UITools::HelpTooltip("Viewing records, leaderboards and splits will be disabled. Some blacklisted plugins will be disabled during the match.");
    }

    void TotalTimeIndicator() {
        UITools::AlignedLabel(Icons::PlayCircle + "  Total Game Time: " +
                              TimeFormat(MatchConfig.timeLimit + MatchConfig.noBingoDuration));
        UI::NewLine();
    }

    void GamemodeSelect() {
        UITools::AlignedLabel(Icons::PencilSquareO + " Gamemode");
        Layout::MoveTo(GAME_SETTINGS_ALIGN_X * UI::GetScale());

        if (UI::ButtonColored(
                "Standard", .6, .6, (MatchConfig.mode == Gamemode::Standard ? .6 : .1))) {
            MatchConfig.mode = Gamemode::Standard;
        }
        UI::SetItemTooltip("The classic gamemode for Bingo.\nGet a row, column, or diagonal on the "
                           "board with your team to win.");

        UI::SameLine();
        Layout::EndLabelAlign();
        if (UI::ButtonColored(
                "Frenzy", .15, .6, (MatchConfig.mode == Gamemode::Frenzy ? .6 : .1))) {
            MatchConfig.mode = Gamemode::Frenzy;
        }
        UI::SetItemTooltip("Powerups will appear randomly on the board.\nUse their different "
                           "powers efficiently to claim victory!");
    }

    void EditItemSettings() {
        if (UI::Button(Icons::Cog + " Edit Item Settings")) {
            UIItemSettings::Visible = !UIItemSettings::Visible;
        }
    }

    void ItemExpiryEdit() {
        LabelAdvancedSettings(Icons::HourglassEnd + " Items Expire");

        UI::SetNextItemWidth(Math::Min(UI::GetContentRegionAvail().x, 200));
        if (UI::BeginCombo("##bingoitemexpire",
                           MatchConfig.itemsExpire == 0
                               ? "Never"
                               : "After " + (MatchConfig.itemsExpire) / 60 + " minutes")) {

            if (UI::Selectable("After 2 minutes", MatchConfig.itemsExpire == 120)) {
                MatchConfig.itemsExpire = 120;
            }

            if (UI::Selectable("After 10 minutes", MatchConfig.itemsExpire == 600)) {
                MatchConfig.itemsExpire = 600;
            }

            if (UI::Selectable("Never", MatchConfig.itemsExpire == 0)) {
                MatchConfig.itemsExpire = 0;
            }

            UI::EndCombo();
        }
        UI::SameLine();
        UITools::HelpTooltip("After being collected, a powerup must be used within a certain time "
                             "frame or it will disappear.");
    }

    void ItemTickrateEdit() {
        LabelAdvancedSettings(Icons::Forward + " Item Spawns");

        UI::SetNextItemWidth(Math::Min(UI::GetContentRegionAvail().x, 200));
        if (UI::BeginCombo("##bingoitemtickrate",
                           MatchConfig.itemsTickMultiplier <= 1000 ? (MatchConfig.itemsTickMultiplier == 400 ? "Few" : "Balanced") : (MatchConfig.itemsTickMultiplier == 2000 ? "Many" : "True Frenzy"))) {

            if (UI::Selectable("Few", MatchConfig.itemsTickMultiplier == 400)) {
                MatchConfig.itemsTickMultiplier = 400;
            }

            if (UI::Selectable("Balanced", MatchConfig.itemsTickMultiplier == 1000)) {
                MatchConfig.itemsTickMultiplier = 1000;
            }

            if (UI::Selectable("Many", MatchConfig.itemsTickMultiplier == 2000)) {
                MatchConfig.itemsTickMultiplier = 2000;
            }

            if (UI::Selectable("True Frenzy", MatchConfig.itemsTickMultiplier == 4000)) {
                MatchConfig.itemsTickMultiplier = 4000;
            }

            UI::EndCombo();
        }
        UI::SameLine();
        UITools::HelpTooltip("Controls how frequently new items will appear.");
    }

    void SettingsView() {
        UITools::SectionHeader("Track Select");
        PlaymodeSelect();
        UI::NewLine();

        UITools::SectionHeader("Game Settings");
        GamemodeSelect();
        RoomNameInput();
        UI::SameLine();
        AccessToggle();
        TargetMedalSelector();
        if (MatchConfig.selection == MapMode::Tags) {
            MapTagSelector();
        }
        if (MatchConfig.selection == MapMode::Mappack) {
            MappackIdInput();
        }

        GridSizeSelector();
        TimeLimitControl();
        // PlayerLimitToggle();
        NoBingoTimeControl();
        if (MatchConfig.noBingoDuration != 0 && MatchConfig.timeLimit != 0)
            TotalTimeIndicator();

        UI::BeginDisabled(RoomConfig.hostControl);
        // RandomizeToggle();
        UI::EndDisabled();


        if (hasPlayerLimit(RoomConfig)) {
            PlayerLimitInput();
        }

        UI::NewLine();
        UITools::SectionHeader("Advanced Settings");

        if (UI::BeginTable("bingoadvsettings", 2)) {
            UI::TableNextColumn();
            UI::BeginDisabled(MatchConfig.selection == MapMode::Mappack);
            DiscoveryToggle();
            UI::EndDisabled();

            UI::TableNextColumn();
            RerollsToggle();
            
            UI::TableNextColumn();
            UI::BeginDisabled(MatchConfig.secret);
            CompetitvePatchToggle();
            UI::EndDisabled();

            UI::TableNextColumn();
            LateJoinToggle();

            UI::TableNextColumn();
            HostControlsSetupToggle();

            UI::TableNextColumn();
            SecretToggle();

            if (MatchConfig.mode == Gamemode::Frenzy) {
                UI::TableNextColumn();
                ItemExpiryEdit();

                UI::TableNextColumn();
                ItemTickrateEdit();
            }

            if (MatchConfig.timeLimit != 0) {
                UI::TableNextColumn();
                OvertimeToggle();
            }

            UI::EndTable();
        }

        if (MatchConfig.mode == Gamemode::Frenzy) {
            EditItemSettings();
        }
    }

    void SaveConfiguredSettings() {
        Json::Value @configs = Json::Object();
        configs["room"] = RoomConfiguration::Serialize(RoomConfig);
        configs["game"] = MatchConfiguration::Serialize(MatchConfig);
        PersistantStorage::LastConfig = Json::Write(configs);
    }

    void PlaymodeSelect() {
        Font::Set(Font::Style::Bold, Font::Size::Medium);
        UI::PushStyleVar(UI::StyleVar::ChildBorderSize, 1.);

        if (UI::BeginTable("bingoplaymodes", 2)) {
            MapmodeSelectTablet("bingoplaymode1", "Random Maps", MatchConfig.selection == MapMode::RandomTMX, vec3(.25, .7, 1.), MapMode::RandomTMX);
            MapmodeTooltip("All maps uploaded on Trackmania Exchange. There's no\ntelling what you will get!\n\n\\$aaaTrack Duration: < 02:00.000");

            MapmodeSelectTablet("bingoplaymode2", "Map Tags", MatchConfig.selection == MapMode::Tags, vec3(1., .8, .4), MapMode::Tags);
            MapmodeTooltip("Pick different map styles to create a unique map\npool for your game.\n\n\\$aaaTrack Duration: < 02:00.000");

            MapmodeSelectTablet("bingoplaymode3", "Custom Mappack", MatchConfig.selection == MapMode::Mappack, vec3(1., .4, .4), MapMode::Mappack);
            MapmodeTooltip("Play with your own maps.\n\n\\$aaaTrack Duration: Unrestricted");

            UI::EndTable();
        }

        UI::PopStyleVar();
        Font::Unset();
    }

    void MapmodeTooltip(const string&in tooltipText) {
        Font::Set(Font::Style::Regular, Font::Size::Medium);
        UI::SetItemTooltip(tooltipText);
        Font::Unset();
    }

    void MapmodeSelectTablet(const string&in id, const string&in name, bool selected, vec3 color, MapMode mapmode) {
        UI::TableNextColumn();

        bool wasHoveredLastFrame = HoveredTrackSelect == id;
        UI::PushStyleColor(UI::Col::ChildBg, vec4(color * (selected || wasHoveredLastFrame ? 1. : .7), .5));
        UI::PushStyleColor(UI::Col::Border, vec4(1., 1., 1., selected ? .5 : 0.));
        UI::BeginChild(id, vec2(0, 0), UI::ChildFlags::AutoResizeY | UI::ChildFlags::Border);
        UITools::CenterText(name);
        UI::EndChild();
        UI::PopStyleColor(2);

        if (UI::IsItemClicked()) {
            MatchConfig.selection = mapmode;
        }

        if (UI::IsItemHovered()) {
            HoveredTrackSelect = id;
        } else if (wasHoveredLastFrame) {
            HoveredTrackSelect = "";
        }
    }
}
