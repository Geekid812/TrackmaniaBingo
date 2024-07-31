#if TURBO
namespace Playground {

    class CoroutineData {
        int id;

        CoroutineData(int id) { this.id = id; }
    }
    
    /* FIXME: blocking sync */
    void InternalLoadMapCampaign(ref@ Data) {
        auto app = cast<CGameManiaPlanet>(GetApp());
        Playground::BackToMainMenu();

        // Wait until script API is available
        auto scriptAPI = app.ManiaTitleFlowScriptAPI;
        while (!scriptAPI.IsReady) yield();

        int mapId = cast<CoroutineData>(Data).id - 1;
        int difficultyId = mapId / 40;
        int enviId = (mapId % 40) / 10;
        array<string> enviNames = {"Canyon", "Valley", "Lagoon", "Stadium"};
        array<string> difficulties = {"White", "Green", "Blue", "Red", "Black"};
        
        string filename = "Campaigns\\" + Text::Format("%02i", difficultyId + 1)
        + "_" + difficulties[difficultyId] +"\\" + Text::Format("%02i", enviId + 1)
        + "_" + enviNames[enviId] + "\\" + Text::Format("%03i", mapId + 1) + ".Map.Gbx";
        string modeName = "TMC_CampaignSolo.Script.txt";

        scriptAPI.PlayMap(filename, modeName, "");
    }

    /* Get the currently loaded map's Challenge nod. */
    CGameCtnChallenge@ GetCurrentMap() {
        auto app = cast<CGameCtnApp>(GetApp());
        return app.Challenge;
    }

}
#endif
