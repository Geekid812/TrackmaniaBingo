/* Different possible asset types. */
enum AssetType {
    Map,
    Image
}

namespace DownloadManager {

    /* Queue a file URL for download. */
    void AddToQueue(const string&in url, AssetType type) {
        if (IsUrlQueued(url)) {
            return;
        }

        __internal::AssetData mapData(url, type, Time::Now);
        __internal::itemsInQueue.InsertLast(mapData);

        Framework::Download(
            url,
            __internal::OnDownloadCompleted,
            __internal::OnDownloadCancelled
        );
    }

    /* Return whether this URL is queued for download. */
    bool IsUrlQueued(const string&in url) {
        for (uint i = 0; i < __internal::itemsInQueue.Length; i++) {
            if (__internal::itemsInQueue[i].url == url) return true;
        }

        return false;
    }

    /* Return the number of items waiting to be downloaded in the queue. */
    uint GetItemsInQueue() {
        return __internal::itemsInQueue.Length;
    }

    /* Return the number of items of a specific type waiting to be downloaded in the queue. */
    uint GetItemTypeInQueue(AssetType type) {
        uint count = 0;
        for (uint i = 0; i < __internal::itemsInQueue.Length; i++) {
            if (__internal::itemsInQueue[i].type == type) count += 1;
        }
        return count;
    }

    namespace __internal {
        class AssetData {
            string url;
            AssetType type;
            int64 loadStartTime;

            AssetData() {}
            AssetData(const string&in url, AssetType type, int64 loadStartTime) {
                this.url = url;
                this.type = type;
                this.loadStartTime = loadStartTime;
            }
        }

        array<AssetData>@ itemsInQueue = {};

        void OnDownloadCompleted(const string&in url, MemoryBuffer@ buffer) {
            int assetType = -1;

            for (uint i = 0; i < itemsInQueue.Length; i++) {
                if (itemsInQueue[i].url == url) {
                    assetType = int(itemsInQueue[i].type);
                    itemsInQueue.RemoveAt(i);
                    break;
                }
            }

            if (assetType == -1) return;
            switch (AssetType(assetType)) {
                case AssetType::Map:
                    break;
                case AssetType::Image: {
                    UI::Texture@ texture = UI::LoadTexture(buffer);
                    if (texture.GetSize().x != 0 && @texture != null) {
                        LocalStorage::AddTextureResource(url, texture);
                    }
                    break;
                }
                default:
                    warn("[DownloadManager::OnDownloadCompleted] Unhandled AssetType " + assetType);
            }
        }

        void OnDownloadCancelled(const string&in url) {

        }
    }
}
