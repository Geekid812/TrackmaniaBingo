
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

    [Setting hidden]
    string TeamEditorStorage = GetDefaultTeams();

    string GetDefaultTeams() {
        Json::Value@ teams = Json::Array();

        teams.Add(Team::Serialize(Team(0, "Red", vec3(0.97,0.07,0.08))));
        teams.Add(Team::Serialize(Team(0, "Green", vec3(0.55,0.76,0.29))));
        teams.Add(Team::Serialize(Team(0, "Blue", vec3(0.00,0.58,1.00))));
        teams.Add(Team::Serialize(Team(0, "Cyan", vec3(0.30,0.82,0.88))));
        teams.Add(Team::Serialize(Team(0, "Pink", vec3(0.88,0.29,0.50))));
        teams.Add(Team::Serialize(Team(0, "Yellow", vec3(1.00,1.00,0.00))));

        return Json::Write(teams);
    }

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

        // TeamEditorStorage
        LoadTeamEditor();
    }

    void LoadTeamEditor() {
        try {
            Json::Value@ presetTeams = Json::Parse(TeamEditorStorage);
            for (uint i = 0; i < presetTeams.Length; i++) {
                TeamPresets.InsertLast(Team::Deserialize(presetTeams[i]));
            }
        } catch {
            warn("[PersistantStorage::LoadItems] Deserialize of {TeamEditorStorage} failed (" + getExceptionInfo() + ")");
        }
    }

    void SaveTeamEditor() {
        auto jsonStoage = Json::Array();

        for (uint i = 0; i < TeamPresets.Length; i++)
            jsonStoage.Add(Team::Serialize(TeamPresets[i]));

        string textJson = Json::Write(jsonStoage);
        PersistantStorage::TeamEditorStorage = textJson;
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
