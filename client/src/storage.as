
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

    [Setting hidden]
    int LastConnectedMatchTeamId = -1;

    void LoadItems() {
        try {
            if (LocalProfile != "") {
                @Profile = PlayerProfile::Deserialize(Json::Parse(LocalProfile));
            }
        } catch {
            warn("[PersistantStorage::LoadItems] Deserialize of LocalProfile failed (" + getExceptionInfo() + ")");
        }

        try {
            if (LastConfig != "") {
                Json::Value@ configs = Json::Parse(LastConfig);
                RoomConfig = RoomConfiguration::Deserialize(configs["room"]);
                MatchConfig = MatchConfiguration::Deserialize(configs["game"]);
            }
        } catch {
            warn("[PersistantStorage::LoadItems] Deserialize of LastConfig failed (" + getExceptionInfo() + ")");
        }
    }

    void ResetConnectedMatch() {
        LastConnectedMatchId = "";
        LastConnectedMatchTeamId = -1;
        Meta::SaveSettings();
    }

    void ResetStorage() {
        warn("PersistantStorage: Resetting all items...");
        ClientToken = "";
        LocalProfile = "";
        MapListUiScale = 1.0f;
        LastConfig = "";
        SubscribeToRoomUpdates = false;
        LastConnectedMatchId = "";
        LastConnectedMatchTeamId = -1;
    }
}
