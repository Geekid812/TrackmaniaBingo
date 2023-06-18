
namespace Config {
    string StatusMessage;
    bool CanPlay;
    NewsItem[] News;
    FeaturedMappack[] FeaturedMappacks;
    uint64 LastUpdate;

    void FetchConfig() {
        string url = "https://openplanet.dev/plugin/trackmaniabingo/config/main-" + Meta::ExecutingPlugin().Version.SubStr(0, 1);
        trace("Config: Updating configuration: " + url);
        auto req = Net::HttpGet(url);
        while (!req.Finished()) {
            yield();
        }
        Json::Value json;
        try {
            json = Json::Parse(req.String());
        } catch {
            trace("Config: Response parse failed. Status code: " + req.ResponseCode() + " | Body: " + req.String());
        }

        try {
            //StatusMessage = json["message"];
        } catch {
            warn("Config: Invalid JSON message. That proably means you are not connected.");
            return;
        }
        CanPlay = json["canPlay"];

        News = {};
        for (uint i = 0; i < json["news"].Length; i++) {
            auto jsonItem = json["news"][i];
            string[] linkKeys = jsonItem["links"].GetKeys();
            string[] linkRefs;
            for (uint j = 0; j < linkKeys.Length; j++) {
                linkRefs.InsertLast(jsonItem["links"][linkKeys[j]]);
            }
            News.InsertLast(NewsItem(jsonItem["title"], jsonItem["content"], linkKeys, linkRefs, jsonItem["ts"]));
        }

        FeaturedMappacks = {};
        // string[] mappackNames = json["featuredMappacks"].GetKeys();
        // for (uint i = 0; i < mappackNames.Length; i++) {
        //     string packName = mappackNames[i];
        //     uint packId = json["featuredMappacks"][packName];
        //     featuredMappacks.InsertLast(FeaturedMappack(packName, packId));
        // }

        LastUpdate = Time::Now;
        trace("Config: Update was successful.");
    }

    class NewsItem {
        string title;
        string postinfo;
        string content;
        string[] linkNames;
        string[] linkHref;
        int64 timestamp;

        NewsItem() {}

        NewsItem(const string&in title, const string&in content, string[] linkNames, string[] linkHref, int64 timestamp) {
            this.title = title;
            this.content = content;
            this.linkNames = linkNames;
            this.linkHref = linkHref;
            this.timestamp = timestamp;
        }
    }

}

class FeaturedMappack {
    string name;
    uint tmxid;

    FeaturedMappack() {}

    FeaturedMappack(const string&in name, uint tmxid) {
        this.name = name;
        this.tmxid = tmxid;
    }
}