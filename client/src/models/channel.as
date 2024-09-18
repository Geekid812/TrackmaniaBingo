
/* Room parameters set by the host. */
class ChannelConfiguration {
    string name;
    bool public;
    ChannelConfiguration() {}
}
namespace ChannelConfiguration {
    Json::Value@ Serialize(ChannelConfiguration cls) {
        auto value = Json::Object();
        value["name"] = cls.name;
        value["public"] = cls.public;

        return value;
    }

    ChannelConfiguration Deserialize(Json::Value@ value) {
        auto cls = ChannelConfiguration();
        cls.name = value["name"];
        cls.public = value["public"];

        return cls;
    }
}

enum AuthenticationMethod {
    None = 0,
    Openplanet = 1
}