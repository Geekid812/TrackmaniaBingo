
namespace UITeams {
    bool Visible;
    bool IsJoinContext;

    void Render() {
        Visible = Visible && (IsJoinContext || @Match !is null);
        if (!Visible)
            return;

        if (IsJoinContext)
            RenderInJoin();
        else
            RenderInMatch();
    }

    void RenderInJoin() {
        UI::PushStyleVar(UI::StyleVar::WindowMinSize, vec2(400., 200.));
        UI::Begin(Icons::Th + " Team Selection", Visible);

        JoinTeamsNotice();
        UI::BeginDisabled(Network::IsUISuspended());
        UIPlayers::PlayerTable(Room.teams, Room.players, null, false, true);
        UI::EndDisabled();

        UI::End();
        UI::PopStyleVar();
    }

    void RenderInMatch() {
        UI::PushStyleVar(UI::StyleVar::WindowMinSize, vec2(400., 200.));
        UI::Begin(Icons::Th + " Teams", Visible);

        UIPlayers::PlayerTable(Match.teams, Match.players);

        UI::End();
        UI::PopStyleVar();
    }

    void JoinTeamsNotice() {
        UI::PushStyleColor(UI::Col::ChildBg, vec4(.2, .2, .2, .9));
        UI::PushStyleVar(UI::StyleVar::ChildBorderSize, .5f);
        UI::BeginChild("###bingojoinnotice", vec2(0, 32), true);

        string noticeText = Icons::SignIn + " Joining an active Bingo match, select a team.";
        Layout::AlignText(noticeText, 0.5);
        UI::Text(noticeText);

        UI::EndChild();
        UI::PopStyleVar();
        UI::PopStyleColor();
    }

    void CloseContext() {
        Visible = false;
        IsJoinContext = false;
    }

    void SwitchToJoinContext() {
        Visible = true;
        IsJoinContext = true;
        UIMainWindow::Visible = false;
    }
}
