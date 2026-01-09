
namespace PersistantStorage {
    [Setting hidden] string ClientToken = "";

    [Setting hidden] string LocalProfile = "";

    [Setting hidden] float MapListUiScale = 1.0f;

    [Setting hidden] string LastConfig = "";

    [Setting hidden] bool SubscribeToRoomUpdates = false;

    [Setting hidden] string LastConnectedRoomCode = "";

    [Setting hidden] string LastConnectedMatchId = "";

    [Setting hidden] int LastConnectedMatchTeamId = -1;

    [Setting hidden] string DevelMapCache = "[]";

    [Setting hidden] string CustomTeamsStorage = "[]";

    [Setting hidden] bool HasDismissedItemSpoiler = false;

    array<Team@> GetDefaultTeams() {
        array<Team@> teams;

        teams.InsertLast(Team(0, "Red", vec3(0.90,0.10,0.10)));
        teams.InsertLast(Team(0, "Orange", vec3(0.95,0.55,0.15)));
        teams.InsertLast(Team(0, "Yellow", vec3(0.95,0.90,0.20)));
        teams.InsertLast(Team(0, "Green", vec3(0.20,0.85,0.25)));
        teams.InsertLast(Team(0, "Teal", vec3(0.10,0.70,0.65)));
        teams.InsertLast(Team(0, "Cyan", vec3(0.35,0.75,0.95)));
        teams.InsertLast(Team(0, "Blue", vec3(0.15,0.30,0.85)));
        teams.InsertLast(Team(0, "Purple", vec3(0.45,0.25,0.65)));
        teams.InsertLast(Team(0, "Magenta", vec3(0.85,0.25,0.65)));
        teams.InsertLast(Team(0, "Pink", vec3(0.95,0.55,0.75)));

        return teams;
    }

    void LoadItems() {
        // LocalProfile
        try {
            if (LocalProfile != "") {
                @Profile = PlayerProfile::Deserialize(Json::Parse(LocalProfile));
            }
        } catch {
            logwarn("[PersistantStorage::LoadItems] Deserialize of {LocalProfile} failed (" +
                 getExceptionInfo() + ")");
        }

        // LastConfig
        try {
            if (LastConfig != "") {
                Json::Value @configs = Json::Parse(LastConfig);
                RoomConfig = RoomConfiguration::Deserialize(configs["room"]);
                MatchConfig = MatchConfiguration::Deserialize(configs["game"]);
            }
        } catch {
            logwarn("[PersistantStorage::LoadItems] Deserialize of {LastConfig} failed (" +
                 getExceptionInfo() + ")");
        }

        // DevelMapCache
        try {
            Json::Value @mapCache = Json::Parse(DevelMapCache);
            for (uint i = 0; i < mapCache.Length; i++) {
                MapCache.InsertLast(GameMap::Deserialize(mapCache[i]));
            }
        } catch {
            logwarn("[PersistantStorage::LoadItems] Deserialize of {DevelMapCache} failed (" +
                 getExceptionInfo() + ")");
        }

        // CustomTeamsStorage
        LoadTeamEditor();
    }

    void LoadTeamEditor() {
        try {
            TeamPresets = GetDefaultTeams();
            Json::Value @presetTeams = Json::Parse(CustomTeamsStorage);
            for (uint i = 0; i < presetTeams.Length; i++) {
                TeamPresets.InsertLast(Team::Deserialize(presetTeams[i]));
            }
        } catch {
            logwarn("[PersistantStorage::LoadItems] Deserialize of {CustomTeamsStorage} failed (" +
                 getExceptionInfo() + ")");
        }
    }

    void SaveTeamEditor() {
        auto jsonStoage = Json::Array();

        for (uint i = GetDefaultTeams().Length; i < TeamPresets.Length; i++)
            jsonStoage.Add(Team::Serialize(TeamPresets[i]));

        string textJson = Json::Write(jsonStoage);
        PersistantStorage::CustomTeamsStorage = textJson;
    }

    void SaveDevMapCache() {
        auto jsonCache = Json::Array();

        for (uint i = 0; i < MapCache.Length; i++)
            jsonCache.Add(GameMap::SerializeTMX(MapCache[i]));

        string textJson = Json::Write(jsonCache);
        PersistantStorage::DevelMapCache = textJson;
    }

    void SaveConnectedMatch() {
        if (@Match !is null) {
            PersistantStorage::LastConnectedRoomCode = Match.joinCode;
        } else {
            PersistantStorage::LastConnectedRoomCode = "";
        }

        if (@Match !is null) {
            PersistantStorage::LastConnectedMatchId = Match.uid;

            auto self = Match.GetSelf();
            if (@self !is null)
                PersistantStorage::LastConnectedMatchTeamId = self.team.id;
        } else {
            PersistantStorage::LastConnectedMatchId = "";
            PersistantStorage::LastConnectedMatchTeamId = -1;
        }
        Meta::SaveSettings();
    }

    void ResetConnectedMatch() {
        LastConnectedRoomCode = "";
        LastConnectedMatchId = "";
        LastConnectedMatchTeamId = -1;
        Meta::SaveSettings();
    }

    void ResetStorage() {
        logwarn("[PersistantStorage::ResetStorage] Resetting all items...");
        ClientToken = "";
        LocalProfile = "";
        MapListUiScale = 1.0f;
        LastConfig = "";
        SubscribeToRoomUpdates = false;
        LastConnectedRoomCode = "";
        LastConnectedMatchId = "";
        LastConnectedMatchTeamId = -1;
        DevelMapCache = "[]";
        CustomTeamsStorage = "[]";
        HasDismissedItemSpoiler = false;
    }
}
