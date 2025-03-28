#if TMNEXT
namespace Playground {

    /* Load a map in the game playground. */
    void PlayMap(const string& in filePath, const string& in modeName = "") {
        if (!Permissions::PlayLocalMap()) {
            warn("[Playground::PlayMap] Aborting, player does not have required permissions!");
            return;
        }

        trace("[Playground::PlayMap] Loading map '" + filePath + "'...");
        __internal::CurrentLoadingPath = filePath;
        __internal::PlayMapCoroutineData data(filePath, modeName);
        startnew(__internal::PlayMapCoroutine, data);
    }

    /* Get the currently loaded map's Challenge nod. */
    CGameCtnChallenge @GetCurrentMap() {
        auto app = cast<CTrackMania>(GetApp());
        return app.RootMap;
    }

    /* Set the visibility of the records leaderbaord manialink module. */
    void SetMapLeaderboardVisible(bool visible) {
        auto network = GetApp().Network;
        if (network is null)
            return;
        auto appPlayground = network.ClientManiaAppPlayground;
        if (appPlayground is null)
            return;
        auto uiLayers = appPlayground.UILayers;
        for (uint i = 0; i < uiLayers.Length; i++) {
            auto module = uiLayers[i];
            if (module !is null &&
                module.ManialinkPage.SubStr(0, 100).Contains("UIModule_Race_Record")) {
                module.IsVisible = visible;
            }
        }
    }

    namespace __internal {
        class PlayMapCoroutineData {
            string filePath;
            string modeName;

            PlayMapCoroutineData() {}

            PlayMapCoroutineData(const string& in filePath, const string& in modeName) {
                this.filePath = filePath;
                this.modeName = modeName;
            }

        }

        void
        PlayMapCoroutine(ref @arg) {

            PlayMapCoroutineData data = cast<PlayMapCoroutineData>(arg);

            Playground::BackToMainMenu();
            auto app = cast<CTrackMania>(GetApp());

            // Wait for the active module to be the main menu, and be ready. If getting back to the
            // main menu fails, this will block until the user quits the map.
            while (app.Switcher.ModuleStack.Length == 0 ||
                   cast<CTrackManiaMenus>(app.Switcher.ModuleStack[0]) is null) {
                if (__internal::CurrentLoadingPath != data.filePath) {
                    warn("[Playground::PlayMapCoroutine] A new map has been requested, aborting "
                         "previous load.");
                    return;
                }
                yield();
            }
            while (!app.ManiaTitleControlScriptAPI.IsReady) {
                if (__internal::CurrentLoadingPath != data.filePath) {
                    warn("[Playground::PlayMapCoroutine] A new map has been requested, aborting "
                         "previous load.");
                    return;
                }
                yield();
            }

            app.ManiaTitleControlScriptAPI.PlayMap(data.filePath, data.modeName, "");
            trace("[Playground::PlayMap] Load coroutine completed.");
        }
    }
}
#endif
