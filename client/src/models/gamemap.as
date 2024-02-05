enum MapType {
    TMX,
    Campaign
}

class GameMap {
    MapType type = MapType::TMX;
    int id;
    string uid;
    int userid;
    string authorLogin;
    string username;
    string trackName;
    string gbxName;
    int coppers;
    int authorTime;
    int uploadedTimestamp;
    int updatedTimestamp;
    string tags;
    string style;
}

namespace GameMap {
    MapType GetMapType(const string&in typeName) {
        if (typeName == "TMX") return MapType::TMX;
        return MapType::Campaign;
    }

    GameMap Deserialize(Json::Value@ value) {
        MapType type = GetMapType(value["type"]);
#if TMNEXT
        if (type == MapType::TMX) return DeserializeTMX(value);
#elif TURBO
        if (type == MapType::Campaign) return DeserializeCampaign(value);
#endif
        throw("GameMap: unknown map type '" + string(value["type"]) + "'.");
        return GameMap();
    }

    Json::Value SerializeTMX(GameMap map) {
        auto value = Json::Object();
        value["type"] = int(map.type);
        value["tmxid"] = map.id;
        value["uid"] = map.uid;
        value["userid"] = map.userid;
        value["author_login"] = map.authorLogin;
        value["username"] = map.username;
        value["track_name"] = map.trackName;
        value["gbx_name"] = map.gbxName;
        value["coppers"] = map.coppers;
        value["author_time"] = map.authorTime;
        value["uploaded_at"] = map.uploadedTimestamp;
        value["updated_at"] = map.updatedTimestamp;
        value["tags"] = map.tags;
        value["style"] = map.style;
        return value;
    }

    GameMap DeserializeTMX(Json::Value@ value) {
        auto map = GameMap();
        map.type = MapType::TMX;
        map.id = value["tmxid"];
        map.uid = value["uid"];
        map.userid = value["userid"];
        map.authorLogin = value["author_login"];
        map.username = value["username"];
        map.trackName = value["track_name"];
        map.gbxName = value["gbx_name"];
        map.coppers = value["coppers"];
        map.authorTime = value["author_time"];
        map.uploadedTimestamp = value["uploaded_at"];
        map.updatedTimestamp = value["updated_at"];
        if (value["tags"].GetType() != Json::Type::Null) map.tags = value["tags"];
        if (value["style"].GetType() != Json::Type::Null) map.style = value["style"];
        return map;
    }

#if TURBO
    GameMap DeserializeCampaign(Json::Value@ value) {
        GameMap map = GameMap();
        map.id = uint(value["map"]);
        map.uid = Turbo::GetCampaignMapUid(map.id);
        map.trackName = "#" + Text::Format("%03i", map.id);
        map.type = MapType::Campaign;
        
        if (map.id % 5 == 0 && !(map.id > 160 && map.id % 10 == 0))
            map.style = "MultiLap";
    
        return map;
    }
#endif
}
