
namespace UIDevMapCache {
    array<string> COLUMN_HEADERS = {"TMX", "Name", "Author Time"};
    const float CACHE_SLIDER_WIDTH = 200.;
    const float TMX_COLUMN_WIDTH = 50.;
    const string MAP_REQUEST_TMX_URL =
        "https://trackmania.exchange/mapsearch2/search?api=on&random=1&maptype=TM_Race";

    int InputCacheLoadAmount = 10;

    void RenderCacheTable() {
        if (UI::BeginTable("bingodevmapcache", COLUMN_HEADERS.Length)) {
            for (uint i = 0; i < COLUMN_HEADERS.Length; i++) {
                bool isTmxColumn = COLUMN_HEADERS[i] == "TMX";
                UI::TableSetupColumn(COLUMN_HEADERS[i],
                                     isTmxColumn ? UI::TableColumnFlags::WidthFixed
                                                 : UI::TableColumnFlags::None,
                                     isTmxColumn ? TMX_COLUMN_WIDTH : 0.);
            }
            UI::TableHeadersRow();

            UIColor::Cyan();
            for (uint i = 0; i < MapCache.Length; i++) {
                GameMap map = MapCache[i];

                UI::TableNextColumn();
                if (UI::Button(Icons::ArrowCircleRight)) {
                    OpenBrowserURL("https://trackmania.exchange/maps/" + map.id);
                }

                UI::TableNextColumn();
                UI::Text(map.trackName);

                UI::TableNextColumn();
                UI::Text(Time::Format(map.authorTime));
            }
            UIColor::Reset();

            UI::EndTable();
        }
    }

    void RenderCacheControl() {
        UI::Text("\\$ff5" + MapCache.Length + " \\$zmaps stored in local cache.");
        UI::NewLine();

        UI::SetNextItemWidth(CACHE_SLIDER_WIDTH);
        InputCacheLoadAmount = UI::SliderInt("new maps to load", InputCacheLoadAmount, 0, 50);

        UIColor::DarkGreen();
        UI::SameLine();
        if (UI::Button(Icons::Download + " Load")) {
            startnew(function() { LoadTMXMapsCoroutine(InputCacheLoadAmount); });
        }
        UIColor::Reset();

        UIColor::DarkRed();
        UI::SameLine();
        if (UI::Button(Icons::Trash + " Clear")) {
            MapCache = {};
            PersistantStorage::SaveDevMapCache();
        }
        UIColor::Reset();
    }

    void RenderCache() {
        RenderCacheControl();

        UI::Separator();

        UI::BeginChild("bingodevcachescroll");
        RenderCacheTable();
        UI::EndChild();
    }

    void LoadTMXMapsCoroutine(int amount) {
        int originalAmount = amount;

        while (amount > 0) {
            trace("[UIDevMapCache::LoadTMXMapsCoroutine] Fetching new map... (" + amount +
                  " remaining)");

            Net::HttpRequest @req = Net::HttpGet(MAP_REQUEST_TMX_URL);
            while (!req.Finished())
                yield();

            amount -= 1;
            if (Extra::Net::RequestRaiseError("UIDevMapCache::LoadTMXMapsCoroutine", req))
                continue;

            Json::Value @body = req.Json();
            body = body["results"][0];
            GameMap map();

            // Ad-hoc parsing of TMX results
            map.id = int(body["TrackID"]);
            map.uid = body["TrackUID"];
            map.authorLogin = body["AuthorLogin"];
            map.authorTime = int(body["AuthorTime"]);
            map.gbxName = body["GbxMapName"];
            map.coppers = int(body["DisplayCost"]);
            map.trackName = body["Name"];
            map.type = MapType::TMX;
            map.userid = int(body["UserID"]);

            if (body.HasKey("StyleName") && body["StyleName"].GetType() != Json::Type::Null)
                map.style = body["StyleName"];
            if (body.HasKey("Tags") && body["Tags"].GetType() != Json::Type::Null)
                map.tags = body["Tags"];

            MapCache.InsertLast(map);
        }

        print("[UIDevMapCache::LoadTMXMapsCoroutine] Loaded " + originalAmount +
              " new maps in local cache.");
        PersistantStorage::SaveDevMapCache();
    }

}
