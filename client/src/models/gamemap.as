enum MapType {
    TMX,
    Campaign
}

class GameMap {
    MapType type = MapType::TMX;
    int id;
    string uid;
    string webservicesId;
    int userid;
    string username;
    string trackName;
    string gbxName;
    int authorTime;
    int goldTime;
    int silverTime;
    int bronzeTime;
    int uploadedTimestamp;
    int updatedTimestamp;
    string tags;
    string style;
}

namespace GameMap {

    MapType GetMapType(const string& in typeName) {
        if (typeName == "TMX")
            return MapType::TMX;
        return MapType::Campaign;
    }

    GameMap Deserialize(Json::Value @value) {
        MapType type = GetMapType(value["type"]);
        if (type == MapType::TMX)
            return DeserializeTMX(value);

        throw("GameMap: unknown map type '" + string(value["type"]) + "'.");
        return GameMap();
    }

    Json::Value SerializeTMX(GameMap map) {
        auto value = Json::Object();
        value["type"] = tostring(map.type);
        value["tmxid"] = map.id;
        value["uid"] = map.uid;
        value["webservices_id"] = map.webservicesId;
        value["userid"] = map.userid;
        value["username"] = map.username;
        value["track_name"] = map.trackName;
        value["gbx_name"] = map.gbxName;
        value["author_time"] = map.authorTime;
        value["gold_time"] = map.goldTime;
        value["silver_time"] = map.silverTime;
        value["bronze_time"] = map.bronzeTime;
        value["uploaded_at"] = map.uploadedTimestamp;
        value["updated_at"] = map.updatedTimestamp;
        value["tags"] = map.tags;
        value["style"] = map.style;
        return value;
    }

    GameMap DeserializeTMX(Json::Value @value) {
        auto map = GameMap();
        map.type = MapType::TMX;
        map.id = value["tmxid"];
        map.uid = value["uid"];
        if (value["webservices_id"].GetType() != Json::Type::Null)
            map.webservicesId = value["webservices_id"];

        map.userid = value["userid"];
        map.username = value["username"];
        map.trackName = value["track_name"];
        map.gbxName = value["gbx_name"];
        map.authorTime = value["author_time"];
        map.goldTime = value["gold_time"];
        map.silverTime = value["silver_time"];
        map.bronzeTime = value["bronze_time"];
        map.uploadedTimestamp = value["uploaded_at"];
        map.updatedTimestamp = value["updated_at"];
        if (value["tags"].GetType() != Json::Type::Null)
            map.tags = value["tags"];
        if (value["style"].GetType() != Json::Type::Null)
            map.style = value["style"];
        return map;
    }
}
