
namespace UIRoomSettings {
    const uint[] TimeLimitOptions = { 15, 30, 45, 60, 90, 120 };
    const uint GridSizeMin = 3;
    const uint GridSizeMax = 8;
    const float CheckboxesAlignX = 180;

    FeaturedMappack@ SelectedPack;

    void RoomNameInput() {
        UITools::AlignedLabel(Icons::Pencil + " Room Name");
        UI::SetNextItemWidth(220);
        RoomConfig.Name = UI::InputText("##bingoroomname", RoomConfig.Name);
        if (RoomConfig.Name == "" && LocalUsername != "") {
            RoomConfig.Name = LocalUsername + "'s Bingo Room";
        }
    }

    void PlayerLimitToggle() {
        UITools::AlignedLabel(Icons::User + " Enable Player Limit");
        LayoutTools::MoveTo(CheckboxesAlignX);
        RoomConfig.HasPlayerLimit = UI::Checkbox("##bingomaxplayers", RoomConfig.HasPlayerLimit);
    }

    void PlayerLimitInput() {
        UITools::AlignedLabel(Icons::Users + " Maximum");
        UI::SetNextItemWidth(200);
        RoomConfig.MaxPlayers = Math::Clamp(UI::InputInt(" players allowed", RoomConfig.MaxPlayers), 2, 1000);
    }

    void ChatToggle() {
        UITools::AlignedLabel(Icons::Comment + " In-Game Chat");
        LayoutTools::MoveTo(CheckboxesAlignX);
        RoomConfig.InGameChat = UI::Checkbox("##bingochat", RoomConfig.InGameChat);
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

    void SettingsView() {
        SettingsSection("Room Settings");
        RoomNameInput();
        UI::SameLine();
        AccessToggle();
        PlayerLimitToggle();
        ChatToggle();
        if (RoomConfig.HasPlayerLimit) {
            PlayerLimitInput();
        }

        // This doesn't exist... yet
        if (false) RoomConfig.RandomizeTeams = UI::Checkbox("Randomize Teams", RoomConfig.RandomizeTeams);

        SettingsSection("Game Settings");
        if (UI::BeginCombo("Grid Size", tostring(RoomConfig.GridSize) + "x" + tostring(RoomConfig.GridSize))) {
            
            for (uint i = GridSizeMin; i <= GridSizeMax; i++) {
                if (UI::Selectable(tostring(i) + "x" + tostring(i), RoomConfig.GridSize == i)) {
                    RoomConfig.GridSize = i;
                }
            }

            UI::EndCombo();
        }
        if (UI::BeginCombo("Map Selection", @SelectedPack != null ? SelectedPack.name : stringof(RoomConfig.MapSelection))) {
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

        if (RoomConfig.MapSelection == MapMode::Mappack) {
            UI::BeginDisabled(@SelectedPack != null);
            RoomConfig.MappackId = UI::InputInt("TMX Mappack ID", RoomConfig.MappackId, 0);
            UI::EndDisabled();
        }

        if (UI::BeginCombo("Target Medal", stringof(RoomConfig.TargetMedal))) {
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

        if (UI::BeginCombo("Time Limit", RoomConfig.MinutesLimit == 0 ? "Disabled" : tostring(RoomConfig.MinutesLimit) + " minutes")) {

            if (UI::Selectable("Disabled", RoomConfig.MinutesLimit == 0)) {
                RoomConfig.MinutesLimit = 0;
            }

            for (uint i = 0; i < TimeLimitOptions.Length; i++) {
                uint TimeOption = TimeLimitOptions[i];
                if (UI::Selectable(tostring(TimeOption) + " minutes", RoomConfig.MinutesLimit == TimeOption)) {
                    RoomConfig.MinutesLimit = TimeOption;
                }
            }

            UI::EndCombo();
        }
    }

    void SettingsSection(string&in text) {
        UI::NewLine();
        UI::PushFont(Font::Bold);
        UI::Text(text);
        UI::PopFont();
    }
}