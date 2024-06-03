
namespace UIDevActions {
    bool Visible;

    void Render() {
        if (!Visible) return;
        UI::Begin("\\$82a" + Icons::Th + " \\$zDeveloper Tools", Visible);

        ClientTokenControl();

        UI::End();
    }

    void ClientTokenControl() {
        UI::Text("Client Token: " + (Login::IsLoggedIn() ? PersistantStorage::ClientToken : "[NONE]"));
        UI::SameLine();
        if (UI::Button("Clear")) {
            PersistantStorage::ClientToken = "";
        };
    }
}
