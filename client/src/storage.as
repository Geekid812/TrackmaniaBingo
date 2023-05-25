
namespace PersistantStorage {
    [Setting hidden]
    string ClientToken = "";

    [Setting hidden]
    string LocalProfile = "";

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
