/* Reference to an image, it may not yet be loaded. */
class Image {
    string resourceUrl;
    UI::Texture @_data;

    Image(const string& in resourceUrl) {
        this.resourceUrl = resourceUrl;
        @ this._data = LocalStorage::GetTextureResource(resourceUrl);

        if (@ this._data is null)
            DownloadManager::AddToQueue(resourceUrl, AssetType::Image);
    }

    UI::Texture @get_Data() {
        if (@ this._data is null)
            @ this._data = LocalStorage::GetTextureResource(this.resourceUrl);
        return @ this._data;
    }
}

namespace LocalStorage {

    /* Return a local path to a map for the provided resource URL if it was locally cached.
     * Otherwise returns the resource URL itself. */
    string GetMapResource(const string& in resourceUrl) {
        string localPath;
        if (__internal::mapLocalStorage.Get(resourceUrl, localPath))
            return localPath;
        return resourceUrl;
    }

    /* Add a map resource to the local storage cache. */
    void AddMapResource(const string& in resourceUrl, const string& in localPath) {
        __internal::mapLocalStorage.Set(resourceUrl, localPath);
    }

    /* Return whether a map resource is stored in local cache. */
    bool IsMapInStorage(const string& in resourceUrl) {
        return __internal::mapLocalStorage.Exists(resourceUrl);
    }

    /* Return a cached texture from an image resource. */
    UI::Texture @GetTextureResource(const string& in resourceUrl) {
        UI::Texture @texture;
        __internal::textureLocalStorage.Get(resourceUrl, @texture);
        return texture;
    }

    /* Add a texture resource to the local storage cache. */
    void AddTextureResource(const string& in resourceUrl, UI::Texture @texture) {
        __internal::textureLocalStorage.Set(resourceUrl, @texture);
    }

    /* Return whether a texture resource is stored in local cache. */
    bool IsTextureInStorage(const string& in resourceUrl) {
        return __internal::textureLocalStorage.Exists(resourceUrl);
    }

    /* Debug helper: print all resource URLs in local cache. */
    void DebugEnumerateTextureStorage() {
        array<string> keys = __internal::textureLocalStorage.GetKeys();
        for (uint i = 0; i < keys.Length; i++) {
            UI::Texture @value;
            __internal::textureLocalStorage.Get(keys[i], @value);

            print("[LocalStorage::DebugEnumerateTextureStorage] Cache resource: " + keys[i] +
                  " -> " + (value is null ? "null" : "UI::Texture@"));
        }
    }

    namespace __internal {
        dictionary mapLocalStorage = {};
        dictionary textureLocalStorage = {};
    }
}
