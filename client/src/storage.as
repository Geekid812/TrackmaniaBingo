
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
    string ReconnectChannelId = "";

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
                RoomConfig = ChannelConfiguration::Deserialize(configs["room"]);
                GameConfig = GameRules::Deserialize(configs["game"]);
                
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

    void SaveConfigurations() {
        Json::Value@ object = Json::Object();
        object["room"] = ChannelConfiguration::Serialize(RoomConfig);
        object["game"] = GameRules::Serialize(GameConfig);
        
        PersistantStorage::LastConfig = Json::Write(object);
    }
    
    void ResetConnectedMatch() {
        ReconnectChannelId = "";
        Meta::SaveSettings();
    }

    void ResetStorage() {
        warn("[PersistantStorage::ResetStorage] Resetting all items...");
        ClientToken = "";
        LocalProfile = "";
        MapListUiScale = 1.0f;
        LastConfig = "";
        ReconnectChannelId = "";
        DevelMapCache = "[]";
    }
}
