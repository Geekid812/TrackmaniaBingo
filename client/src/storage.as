
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

    [Setting hidden]
    string DevelMapCache = "[]";

    void LoadItems() {
        // LocalProfile
        try {
            if (LocalProfile != "") {
                @Profile = PlayerProfile::Deserialize(Json::Parse(LocalProfile));
            }
        } catch {
            warn("[PersistantStorage::LoadItems] Deserialize of {LocalProfile} failed (" + getExceptionInfo() + ")");
        }

        // LastConfig
        try {
            if (LastConfig != "") {
                Json::Value@ configs = Json::Parse(LastConfig);
                RoomConfig = RoomConfiguration::Deserialize(configs["room"]);
                MatchConfig = MatchConfiguration::Deserialize(configs["game"]);
                
            }
        } catch {
            warn("[PersistantStorage::LoadItems] Deserialize of {LastConfig} failed (" + getExceptionInfo() + ")");
        }

        // DevelMapCache
        try {
            Json::Value@ mapCache = Json::Parse(DevelMapCache);
            for (uint i = 0; i < mapCache.Length; i++) {
                MapCache.InsertLast(GameMap::Deserialize(mapCache[i]));
            }
        } catch {
            warn("[PersistantStorage::LoadItems] Deserialize of {DevelMapCache} failed (" + getExceptionInfo() + ")");
        }
    }

    void SaveDevMapCache() {
        auto jsonCache = Json::Array();

        for (uint i = 0; i < MapCache.Length; i++)
            jsonCache.Add(GameMap::SerializeTMX(MapCache[i]));

        string textJson = Json::Write(jsonCache);
        PersistantStorage::DevelMapCache = textJson;
    }
    
    void ResetConnectedMatch() {
        LastConnectedMatchId = "";
        LastConnectedMatchTeamId = -1;
        Meta::SaveSettings();
    }

    void ResetStorage() {
        warn("[PersistantStorage::ResetStorage] Resetting all items...");
        ClientToken = "";
        LocalProfile = "";
        MapListUiScale = 1.0f;
        LastConfig = "";
        SubscribeToRoomUpdates = false;
        LastConnectedMatchId = "";
        LastConnectedMatchTeamId = -1;
        DevelMapCache = "[]";
    }
}
