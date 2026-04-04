
namespace MXTags {
    const string MX_GETTAGS_URL = "https://trackmania.exchange/api/tags/gettags";
    const int TAG_MAX_ID = 39;
    const array<string> BANNED_TAGS = {"Race", "ZrT", "Offroad", "Press Forward", "Stunt", "Scenery", "Kacky", "Slow Motion", "Minigame", "Obstacle", "Transitional", "Signature"};

    class Tag {
        int id;
        string name;

        Tag() {}

        Tag(int id, const string& in name) {
            this.id = id;
            this.name = name;
        }
    }

    array<Tag @>
        Tags = {};

    bool TagsRequested;

    bool TagsLoaded() {
        if (!TagsRequested)
            startnew(LoadTags);
        return Tags.Length > 0;
    }

    void LoadTags() {
        TagsRequested = true;
        logtrace("[MXTags::LoadTags] Loading tags...");
        auto req = Net::HttpGet(MX_GETTAGS_URL);
        while (!req.Finished()) {
            yield();
        }
        if (Extra::Net::RequestRaiseError("MXTags::LoadTags", req))
            return;

        auto data = Json::Parse(req.String());
        Tags = {};
        for (uint i = 0; i < data.Length; i++) {
            string name = data[i]["Name"];
            int id = data[i]["ID"];
            if (id > TAG_MAX_ID || BANNED_TAGS.Find(name) != -1) {
                continue;
            }

            Tags.InsertLast(Tag(id, name));
        }
        logtrace("[MXTags::LoadTags] Loaded " + Tags.Length + " tags.");
    }

    Tag GetTag(int id) {
        for (uint i = 0; i < Tags.Length; i++) {
            auto tag = Tags[i];
            if (tag.id == id)
                return tag;
        }

        return Tag();
    }
}
