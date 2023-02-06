
namespace Config {
    string StatusMessage;
    bool CanPlay;
    NewsItem[] News;
    FeaturedMappack[] featuredMappacks;
    uint64 LastUpdate;

    void FetchConfig() {
        trace("Config: Updating configuration...");
        auto req = Net::HttpGet("https://openplanet.dev/plugin/trackmaniabingo/config/status");
        while (!req.Finished()) {
            yield();
        }
        Json::Value json;
        try {
            json = Json::Parse(req.String());
        } catch {
            trace("Config: Response parse failed. Status code: " + req.ResponseCode() + " | Body: " + req.String());
        }

        StatusMessage = json["message"];
        CanPlay = json["canPlay"];

        News = {};
        for (uint i = 0; i < json["news"].Length; i++) {
            auto jsonItem = json["news"][i];
            News.InsertLast(NewsItem(jsonItem["title"], jsonItem["postinfo"], jsonItem["content"]));
        }

        featuredMappacks = {};
        string[] mappackNames = json["featuredMappacks"].GetKeys();
        for (uint i = 0; i < mappackNames.Length; i++) {
            string packName = mappackNames[i];
            uint packId = json["featuredMappacks"][packName];
            featuredMappacks.InsertLast(FeaturedMappack(packName, packId));
        }

        LastUpdate = Time::Now;
        trace("Config: Update was successful.");
    }

    class NewsItem {
        string title;
        string postinfo;
        string content;

        NewsItem() {}

        NewsItem(const string&in title, const string&in postinfo, const string&in content) {
            this.title = title;
            this.postinfo = postinfo;
            this.content = content;
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