
namespace MXTags {
    const string MX_GETTAGS_URL = "https://trackmania.exchange/api/tags/gettags";

    class Tag {
        int id;
        string name;

        Tag() {}

        Tag(int id, const string&in name) {
            this.id = id;
            this.name = name;
        }
    }

    array<Tag@> Tags = {};
    bool TagsRequested;

    bool TagsLoaded() {
        if (!TagsRequested) startnew(LoadTags);
        return Tags.Length > 0;
    }

    void LoadTags() {
        TagsRequested = true;
        trace("MXTags: Loading tags...");
        auto req = Net::HttpGet(MX_GETTAGS_URL);
        while (!req.Finished()) { yield(); }

        int code = req.ResponseCode();
        if (code != 200) {
            warn("MXTags: nonzero return code: " + code);
            return;
        }

        auto data = Json::Parse(req.String());
        Tags = {};
        for (uint i = 0; i < data.Length; i++) {
            Tags.InsertLast(Tag(data[i]["ID"], data[i]["Name"]));
        }
        trace("MXTags: Loaded " + Tags.Length + " tags.");
    }

    Tag GetTag(int id) {
        for (uint i = 0; i < Tags.Length; i++) {
            auto tag = Tags[i];
            if (tag.id == id) return tag;
        }
        
        throw("GetTag() returned null. Tags are maybe not initialized. (Requested tag " + id + ")");
        return Tag();
    }
}
