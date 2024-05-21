
namespace Playground {

    /* Load a map in the game playground. */
    void PlayMap(const string&in filePath, const string&in modeName = "") {
        if (!Permissions::PlayLocalMap()) {
            warn("[Playground::PlayMap] Aborting, player does not have required permissions!");
            return;
        }

        trace("[Playground::PlayMap] Loading map '" + filePath + "'...");
        __internal::PlayMapCoroutineData data(filePath, modeName);
        __internal::PlayMapCoroutine(data);
    }

    namespace __internal {
        class PlayMapCoroutineData {
            string filePath;
            string modeName;

            PlayMapCoroutineData() {}
            PlayMapCoroutineData(const string&in filePath, const string&in modeName) {
                this.filePath = filePath;
                this.modeName = modeName;
            }
        }

        void PlayMapCoroutine(ref@ arg) {
            PlayMapCoroutineData data = cast<PlayMapCoroutineData>(arg);
            auto app = cast<CTrackMania>(GetApp());
            BackToMainMenu(app);

            // Wait for the active module to be the main menu, and be ready. If getting back to the main menu fails, this will block until the user quits the map.
            while (app.Switcher.ModuleStack.Length == 0 || cast<CTrackManiaMenus>(app.Switcher.ModuleStack[0]) is null) {
                yield();
            }
            while (!app.ManiaTitleControlScriptAPI.IsReady) {
                yield();
            }

            app.ManiaTitleControlScriptAPI.PlayMap(data.filePath, data.modeName, "");
            trace("[Playground::PlayMap] Load coroutine completed.");
        }
    }
}