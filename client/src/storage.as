
namespace PersistantStorage {
    [Setting hidden]
    string ClientToken = "";

    [Setting hidden]
    string LocalProfile = "";

    [Setting hidden]
    float MapListUiScale = 1.0f;

    void LoadPersistentItems() {
        try {
            if (LocalProfile != "") {
                @Profile = PlayerProfile::Deserialize(Json::Parse(LocalProfile));
            }
        } catch {
            warn("LoadPersistentItems: Deserialize of LocalProfile failed (" + getExceptionInfo() + ")");
        }
    }
}
