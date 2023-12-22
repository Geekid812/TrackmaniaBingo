
namespace UITeams {
    bool Visible;

    void Render() {
        Visible = Visible && @Match !is null;
        if (!Visible) return;
        UI::PushStyleVar(UI::StyleVar::WindowMinSize, vec2(400., 200.));
        UI::Begin(Icons::Th + " Teams", Visible);
        
        UIPlayers::PlayerTable(Match.teams, Match.players);

        UI::End();
        UI::PopStyleVar();
    }
}
