
namespace PersistantStorage {
    [Setting hidden]
    string ClientToken = "";

    [Setting hidden]
    string LocalProfile = "";

    [Setting hidden]
    float MapListUiScale = 1.0f;

    [Setting hidden]
    string LastConfig = "";

    [Setting hidden]
    bool SubscribeToRoomUpdates = false;

    [Setting hidden]
    string LastConnectedMatchId = "";

    void LoadPersistentItems() {
        try {
            if (LocalProfile != "") {
                @Profile = PlayerProfile::Deserialize(Json::Parse(LocalProfile));
            }
        } catch {
            warn("LoadPersistentItems: Deserialize of LocalProfile failed (" + getExceptionInfo() + ")");
        }

        try {
            if (LastConfig != "") {
                Json::Value@ configs = Json::Parse(LastConfig);
                RoomConfig = RoomConfiguration::Deserialize(configs["room"]);
                MatchConfig = MatchConfiguration::Deserialize(configs["game"]);
            }
        } catch {
            warn("LoadPersistentItems: Deserialize of LastConfig failed (" + getExceptionInfo() + ")");
        }
    }
}
