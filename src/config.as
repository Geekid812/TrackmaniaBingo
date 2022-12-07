
namespace Config {
    string StatusMessage;
    bool CanPlay;
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
        LastUpdate = Time::Now;
        trace("Config: Update was successful.");
    }
}