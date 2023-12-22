
namespace UIPlayers {
    void PlayerTable(array<Team>@ teams, array<Player>@ players, Team@ ownTeam = null, bool hideTeams = false, bool canSwitch = false, bool canCreate = false, bool canDelete = false) {
        UI::BeginTable("Bingo_PlayerTable", hideTeams ? 4 : teams.Length + (canCreate ? 1 : 0), UI::TableFlags::None, vec2(), UI::GetWindowContentRegionWidth());

        if (hideTeams) {
            for (uint i = 0; i < players.Length; i++) {
                UI::TableNextColumn();
                Player player = players[i];
                PlayerLabel(player, i);
            }
        } else {
            for (uint i = 0; i < teams.Length; i++) {
                UI::TableNextColumn();
                Team@ team = teams[i];

                float seperatorSize = UI::GetContentRegionMax().x - UI::GetCursorPos().x - 50;
                if (canDelete) {
                    UI::PushStyleColor(UI::Col::Text, UIColor::GetAlphaColor(team.color, .8));
                    UI::Text(Icons::MinusSquare);
                    if (UI::IsItemHovered()) {
                        UI::BeginTooltip();
                        UI::TextDisabled("Delete " + team.name + " Team");
                        UI::EndTooltip();
                    }
                    if (UI::IsItemClicked()) {
                        NetParams::DeletedTeamId = team.id;
                        startnew(Network::DeleteTeam);
                    }
                    UI::PopStyleColor();
                    UI::SameLine();
                }

                UI::BeginChild("bingoteamsep" + i, vec2(seperatorSize, UI::GetTextLineHeightWithSpacing() + 4));
                UI::PushFont(Font::Bold);
                UI::Text("\\$" + UIColor::GetHex(team.color) + team.name);
                UI::PopFont();

                UI::PushStyleColor(UI::Col::Separator, UIColor::GetAlphaColor(team.color, .8));
                UI::Separator();
                UI::PopStyleColor();
                UI::EndChild();

                if (UI::IsItemHovered()) {
                    UI::BeginTooltip();
                    UI::Text("\\$" + UIColor::GetHex(team.color) + team.name + " Team" + (canSwitch && team != ownTeam ? "  \\$888(Click to join)" : ""));
                    UI::EndTooltip();
                }

                if (canSwitch && UI::IsItemClicked()) {
                    startnew(function(ref@ team) { Network::JoinTeam(cast<Team>(team)); }, team);
                }
            }

            if (canCreate) {
                UI::TableNextColumn();
                if (UI::Button(Icons::PlusSquare + " Create team")) {
                    startnew(Network::CreateTeam);
                }
            }

            uint rowIndex = 0;
            while (true) {
                // Iterate forever until no players in any team remain
                UI::TableNextRow();
                uint finishedTeams = 0;
                for (uint i = 0; i < teams.Length; i++){
                    // Iterate through all teams
                    UI::TableNextColumn();
                    Player@ player = PlayerCell(players, teams[i], rowIndex);
                    if (player is null) { // No more players in this team
                        finishedTeams += 1;
                        continue;
                    }
                    else {
                        PlayerLabel(player, rowIndex);
                    }
                }
                if (finishedTeams == teams.Length) break;
                rowIndex += 1;
            }
        }
        UI::EndTable();
    }

    void PlayerLabel(Player player, uint index) {
        string titlePrefix = player.profile.title != "" ? "\\$" + player.profile.title.SubStr(0, 3) : "";
        UI::Text((player.IsSelf() ? "\\$ff8" : "") + titlePrefix + player.name);
        if (UI::IsItemHovered()) {
            UI::BeginTooltip();
            UIProfile::RenderProfile(player.profile, false);
            UI::EndTooltip();
        }
    }

    // Helper function to build the table
    Player@ PlayerCell(array<Player>@ players, Team team, int index) {
        int count = 0;
        for (uint i = 0; i < players.Length; i++) {
            auto player = players[i];
            if (player.team == team) {
                if (count == index) return player;
                else count += 1;
            }
        }
        return null; 
    }
}
