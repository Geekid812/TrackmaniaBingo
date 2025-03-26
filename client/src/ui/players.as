
namespace UIPlayers {
    void PlayerTable(array<Team> @teams,
                     array<Player> @players,
                     Team @ownTeam = null,
                     bool hideTeams = false,
                     bool canSwitch = false,
                     bool canCreate = false,
                     bool canDelete = false,
                     bool canDragPlayers = false,
                     Player @draggedPlayer = null) {
        UI::BeginTable("Bingo_PlayerTable",
                       hideTeams ? 4 : teams.Length + (canCreate ? 1 : 0),
                       UI::TableFlags::None,
                       vec2(),
                       UI::GetWindowContentRegionWidth());

        if (hideTeams) {
            for (uint i = 0; i < players.Length; i++) {
                UI::TableNextColumn();
                Player player = players[i];
                PlayerLabel(player, i);
            }
        } else {
            for (uint i = 0; i < teams.Length; i++) {
                UI::TableNextColumn();
                Team @team = teams[i];

                if (@draggedPlayer !is null) {
                    float cursorX = UI::GetMousePos().x;
                    float lowerX = UI::GetCursorScreenPos().x;
                    float higherX = lowerX + UI::GetContentRegionMax().x;

                    if (cursorX >= lowerX && cursorX <= higherX) {
                        draggedPlayer.team = team;
                    }
                }

                float seperatorSize = UI::GetContentRegionMax().x - UI::GetCursorPos().x - 50;
                if (canDelete) {
                    UI::PushStyleColor(UI::Col::Text, UIColor::GetAlphaColor(team.color, .8));
                    UI::Text(Icons::MinusSquare);
                    if (UI::IsItemHovered()) {
                        UI::BeginTooltip();
                        UI::TextDisabled("Delete " + team.name);
                        UI::EndTooltip();
                    }
                    if (UI::IsItemClicked()) {
                        NetParams::DeletedTeamId = team.id;
                        startnew(Network::DeleteTeam);
                    }
                    UI::PopStyleColor();
                    UI::SameLine();
                }

                UI::BeginChild("bingoteamsep" + i,
                               vec2(seperatorSize, UI::GetTextLineHeightWithSpacing() + 4));
                UI::Text("\\$" + UIColor::GetHex(team.color) + team.name);

                UI::PushStyleColor(UI::Col::Separator, UIColor::GetAlphaColor(team.color, .8));
                UI::Separator();
                UI::PopStyleColor();
                UI::EndChild();

                if (UI::IsItemHovered()) {
                    UI::BeginTooltip();
                    UI::Text("\\$" + UIColor::GetHex(team.color) + team.name +
                             (canSwitch && (ownTeam is null || team != ownTeam)
                                  ? "  \\$888(Click to join)"
                                  : ""));
                    UI::EndTooltip();
                }

                if (canSwitch && UI::IsItemClicked()) {
                    startnew(function(ref @team) { Network::JoinTeam(cast<Team>(team)); }, team);

                    if (UITeams::IsJoinContext) {
                        NetParams::MatchJoinTeamId = team.id;
                        startnew(Network::JoinMatch);
                    }
                }
            }

            if (canCreate) {
                UI::TableNextColumn();

                bool teamPresetAvailable = UITeamEditor::HasAnyUninstantiatedTeam();
                UI::BeginDisabled(!teamPresetAvailable);
                UIColor::DarkGreen();
                if (UI::Button(Icons::PlusSquare + " Create Team")) {
                    UITeamEditor::InstantiateAnyNewTeam();
                }
                UIColor::Reset();
                UI::EndDisabled();

                if (!teamPresetAvailable)
                    UI::SetItemTooltip("Not enough team presets are available to create a new "
                                       "team.\nCreate a new team in the Teams Editor.");
            }

            uint rowIndex = 0;
            while (true) {
                // Iterate forever until no players in any team remain
                UI::TableNextRow();
                uint finishedTeams = 0;
                for (uint i = 0; i < teams.Length; i++) {
                    // Iterate through all teams
                    UI::TableNextColumn();
                    Player @player = PlayerCell(players, teams[i], rowIndex, draggedPlayer);
                    if (player is null) { // No more players in this team
                        finishedTeams += 1;
                        continue;
                    } else {
                        if (!(UITeams::IsJoinContext && player.IsSelf()))
                            PlayerLabel(player, rowIndex, canDragPlayers);
                    }
                }

                if (rowIndex == 0 && canCreate) {
                    UI::TableNextColumn();
                    UIColor::Gray();
                    if (UI::Button(Icons::Bookmark + " Edit Teams")) {
                        UITeamEditor::Visible = !UITeamEditor::Visible;
                    }
                    UIColor::Reset();
                }

                if (finishedTeams == teams.Length)
                    break;
                rowIndex += 1;
            }
        }
        UI::EndTable();
    }

    void PlayerLabel(Player player, uint index, bool canBeSelected = false) {
        string titlePrefix =
            player.profile.title != "" ? "\\$" + player.profile.title.SubStr(0, 3) : "";
        UI::Text((player.IsSelf() ? "\\$ff8" : "") + titlePrefix + player.name);
        if (UI::IsItemHovered()) {
            UI::BeginTooltip();
            UIProfile::RenderProfile(player.profile, false);
            UI::EndTooltip();
            UIGameRoom::PlayerLabelHovered = true;
        }
        if (canBeSelected && UI::IsItemClicked()) {
            @UIGameRoom::DraggedPlayer = player;
        }
    }

    // Helper function to build the table
    Player @PlayerCell(array<Player> @players, Team team, int index, Player @draggedPlayer = null) {
        int count = 0;
        for (uint i = 0; i < players.Length; i++) {
            auto player = players[i];
            bool isNotDraggedPlayer =
                @draggedPlayer is null || player.profile.uid != draggedPlayer.profile.uid;

            if (player.team == team && isNotDraggedPlayer) {
                if (count == index)
                    return player;
                else
                    count += 1;
            }
        }
        if (@draggedPlayer !is null && draggedPlayer.team.id == team.id && count == index) {
            return draggedPlayer;
        }
        return null;
    }
}
