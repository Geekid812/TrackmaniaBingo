namespace UITeamEditor {
    bool Visible;
    vec3 CreateTeamColor;
    string CreateTeamName;

    void DisplayTeamPreset(uint i, Team @team) {
        UI::PushStyleColor(UI::Col::ChildBg, UIColor::GetAlphaColor(team.color, 0.4));
        UI::PushStyleVar(UI::StyleVar::ChildBorderSize, .5f);
        UI::BeginChild("###bingoteampreset" + i, vec2(0, 32), true, UI::WindowFlags::NoScrollbar);

        string innerText = team.name;
        UI::Text(innerText);

        UI::SameLine();

        string buttonText = Icons::Trash;
        Layout::AlignButton(buttonText, 1.0);
        UI::SetCursorPos(UI::GetCursorPos() - vec2(4, 4));
        UIColor::Gray();
        if (UI::Button(buttonText)) {
            TeamPresets.RemoveAt(i);
            PersistantStorage::SaveTeamEditor();
        }
        UIColor::Reset();

        if (@Room != null) {
            Team @teamInRoom = Room.GetTeamWithName(team.name);
            bool teamInstantiatedInRoom = @teamInRoom != null;

            UI::BeginDisabled(teamInstantiatedInRoom);

            if (teamInstantiatedInRoom) {
                buttonText = Icons::Check;
                UIColor::Gray();
            } else {
                buttonText = Icons::PlusSquare;
                UIColor::DarkGreen();
            }

            UI::SameLine();
            Layout::AlignButton(buttonText, 0.85);
            UI::SetCursorPos(UI::GetCursorPos() - vec2(0, 4));
            if (UI::Button(buttonText)) {
                InstantiatePresetTeam(i);
            }
            UIColor::Reset();
            UI::EndDisabled();
        }

        UI::EndChild();
        UI::PopStyleVar();
        UI::PopStyleColor();
    }

    void TeamsEnumerator() {
        for (uint i = 0; i < TeamPresets.Length; i++) {
            DisplayTeamPreset(i, TeamPresets[i]);
        }
    }

    void NewTeamCreateMenu() {
        CreateTeamColor = UI::InputColor3("Color##bingonewteamcolor", CreateTeamColor);
        CreateTeamName = UI::InputText("Name##bingonewteamname", CreateTeamName);

        UIColor::DarkGreen();
        if (UI::Button(Icons::Plus + " Create New Team")) {
            Team newTeam = Team(0, CreateTeamName, CreateTeamColor);
            TeamPresets.InsertLast(newTeam);
            PersistantStorage::SaveTeamEditor();

            CreateTeamColor = vec3();
            CreateTeamName = "";
        }
        UIColor::Reset();
    }

    void Render() {
        if (!Visible)
            return;
        UI::Begin(Icons::Th + " Teams Editor",
                  Visible,
                  UI::WindowFlags::NoCollapse | UI::WindowFlags::AlwaysAutoResize);

        UI::SeparatorText("Team Presets");
        TeamsEnumerator();

        UI::NewLine();
        UI::SeparatorText("Create a new team");
        NewTeamCreateMenu();

        UI::End();
    }

    void InstantiatePresetTeam(uint index) {
        NetParams::TeamCreatePreset = TeamPresets[index];
        startnew(Network::CreateTeam);
    }

    bool HasAnyUninstantiatedTeam() {
        if (@Room is null)
            return false;

        for (uint i = 0; i < TeamPresets.Length; i++) {
            if (@Room.GetTeamWithName(TeamPresets[i].name) == null)
                return true;
        }

        return false;
    }

    void InstantiateAnyNewTeam() {
        if (@Room is null) {
            logwarn("[UITeamEditor::InstantiateAnyNewTeam] Can't instantiate a new team when Room is "
                 "null.");
            return;
        }
        if (!HasAnyUninstantiatedTeam()) {
            logwarn("[UITeamEditor::InstantiateAnyNewTeam] All team presets are instantiated, cannot "
                 "create a new one.");
            return;
        }

        int index = -1;
        while (index < 0 || @Room.GetTeamWithName(TeamPresets[index].name) != null) {
            index = Math::Rand(0, TeamPresets.Length);
        }

        InstantiatePresetTeam(index);
    }
}
