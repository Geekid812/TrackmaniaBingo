
namespace Config {
    string StatusMessage;
    bool CanPlay;

    void FetchConfig() {
        auto req = Net::HttpGet("https://openplanet.dev/plugin/trackmaniabingo/config/status");
        while (!req.Finished()) {
            yield();
        }
        auto json = Json::Parse(req.String());
        StatusMessage = json["message"];
        CanPlay = json["canPlay"];
    }
}