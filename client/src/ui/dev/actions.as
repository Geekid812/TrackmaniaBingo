
namespace UIDevActions {
    bool Visible;

    void Render() {
        if (!Visible) return;
        UI::Begin("\\$82a" + Icons::Th + " \\$zDeveloper Tools", Visible);

        ClientTokenControl();

        UI::End();
    }

    void ClientTokenControl() {
        PersistantStorage::ClientToken = UI::InputText("Client Token", PersistantStorage::ClientToken);
        UI::SameLine();
        if (UI::Button("Clear")) {
            PersistantStorage::ClientToken = "";
        };
    }
}
