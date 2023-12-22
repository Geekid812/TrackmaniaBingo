#if TURBO
namespace Turbo {
    const string THUMBNAIL_TURBO_URL = "https://tmturbo-prod-pc-maps.s3.amazonaws.com/{}.jpg";

    string GetCampaignMapUid(uint mapId) {
        string name = Text::Format("%03i", mapId);
        auto challenges = cast<CGameCtnApp>(GetApp()).ChallengeInfos;

        string uid;
        for (uint i = 0; i < challenges.Length; i++) {
            if (challenges[i].Name == name) {
                uid = challenges[i].MapUid;
                break;
            }
        }

        return uid;
    }

    string GetCampaignThumbnailUrl(const string&in uid) {
        return THUMBNAIL_TURBO_URL.Replace("{}", uid);
    }
}
#endif
