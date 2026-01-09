
namespace UIItemSettings {
    bool Visible;

    const float ITEM_SETTINGS_ALIGN_X = 100;

    void Render() {
        if (!Visible)
            return;
        UI::SetNextWindowSize(400, 400, UI::Cond::FirstUseEver);
        UI::Begin(Icons::Cog + " Item Settings", Visible);

        if (!PersistantStorage::HasDismissedItemSpoiler) {
            ShowItemSpoilerDisclaimer();
        } else {
            RenderItemSettings();
        }

        UI::End();
    }

    void ShowItemSpoilerDisclaimer() {
        UI::NewLine();
        Font::Set(Font::Style::Bold, Font::Size::Large);

        string header = "Spoiler alert!";
        Layout::AlignText(header, 0.5);
        UI::Text(header);

        Font::Unset();

        UI::NewLine();
        UI::TextWrapped(
            "This settings page allows you to tweak the activation of powerups for the Frenzy "
            "gamemode.\n\nAll of the new powerups will be revealed to you, it might be more fun to "
            "discover what they do during a Bingo game! We recommend leaving all powerups enabled "
            "for your first games, so no action is required right now.");

        UI::NewLine();
        if (UI::ButtonColored(Icons::ExclamationCircle + " Go back", 0.05)) {
            UIItemSettings::Visible = !UIItemSettings::Visible;
        }

        UI::SameLine();
        if (UI::Button(Icons::Eye + " Show All")) {
            PersistantStorage::HasDismissedItemSpoiler = true;
        }
    }

    void RenderItemSettings() {
        UITools::SectionHeader(Icons::Flask + " Item Appearance Settings");

        UI::NewLine();
        UI::Separator();
        UI::NewLine();

        MatchConfig.items.rowShift = ItemSetting("Row Shift", MatchConfig.items.rowShift);
        MatchConfig.items.columnShift = ItemSetting("Column Shift", MatchConfig.items.columnShift);
        MatchConfig.items.rally = ItemSetting("Rally", MatchConfig.items.rally);
        MatchConfig.items.jail = ItemSetting("Jail", MatchConfig.items.jail);
        MatchConfig.items.rainbow = ItemSetting("Rainbow Tile", MatchConfig.items.rainbow);
        MatchConfig.items.goldenDice = ItemSetting("Golden Dice", MatchConfig.items.goldenDice);


        UI::NewLine();
        UI::Separator();
        UI::NewLine();
        UI::TextWrapped("These settings only change the probabilties of drawing a specific item "
                        "after collecting a powerup. They do not affect the spawn rate of "
                        "items.\n\nCommon items are 3x more likely to be pulled than "
                        "Rare.\nFrequent items are 3x more likely to be pulled than Common.");


        UI::NewLine();

        UITools::SectionHeader(Icons::Flask + " Specific Item Settings");

        UI::NewLine();
        UI::Separator();
        UI::NewLine();

        MatchConfig.rallyLength = ItemNumber("Rally Length", MatchConfig.rallyLength);
        MatchConfig.jailLength = ItemNumber("Jail Length", MatchConfig.jailLength);

        UI::NewLine();
        UI::Separator();
        UI::NewLine();

        UIColor::Lime();
        if (UI::Button(Icons::CheckCircle + " Confirm")) {
            UIItemSettings::Visible = !UIItemSettings::Visible;
        }
        UIColor::Reset();
    }

    uint ItemSetting(const string& in itemLabel, uint value) {
        UITools::AlignedLabel(itemLabel);
        Layout::MoveTo(ITEM_SETTINGS_ALIGN_X * UI::GetScale());

        uint newValue = value;
        if (UI::ButtonColored(
                "Frequent##bingofreq1item" + itemLabel, .6, .8, (value == 9 ? .6 : .1))) {
            newValue = 9;
        }

        UI::SameLine();
        Layout::EndLabelAlign();
        if (UI::ButtonColored(
                "Common##bingofreq2item" + itemLabel, .45, .6, (value == 3 ? .6 : .1))) {
            newValue = 3;
        }

        UI::SameLine();
        Layout::EndLabelAlign();
        if (UI::ButtonColored("Rare##bingofreq3item" + itemLabel, .2, .6, (value == 1 ? .6 : .1))) {
            newValue = 1;
        }

        UI::SameLine();
        Layout::EndLabelAlign();
        if (UI::ButtonColored(
                "Disabled##bingofreq4item" + itemLabel, .05, .6, (value == 0 ? .6 : .1))) {
            newValue = 0;
        }

        return newValue;
    }

    uint64 ItemNumber(const string& in itemLabel, uint64 value){
        UITools::AlignedLabel(itemLabel);
        Layout::MoveTo(ITEM_SETTINGS_ALIGN_X * UI::GetScale());

        UI::SetNextItemWidth(50);
        uint newValue = value;
        newValue = Math::Max(UI::InputInt("##"+itemLabel, newValue, 0), 5);
        
        UI::SameLine();
        Layout::EndLabelAlign();
        UI::Text("seconds");
        return newValue;
    }
}
