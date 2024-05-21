
namespace LoadManager {

    /* Queue a map for download. */
    void AddMapToDownloadQueue(const string&in key, const string&in filename) {
        __internal::MapData mapData(key, filename, Time::Now);
        __internal::mapsInQueue.InsertLast(mapData);

        Framework::DownloadMap(
            key,
            filename,
            __internal::OnDownloadCompleted,
            __internal::OnDownloadCancelled
        );
    }

    /* Return the number of maps waiting to be downloaded in the queue. */
    uint GetMapsInQueue() {
        return __internal::mapsInQueue.Length;
    }

    namespace __internal {
        class MapData {
            string key;
            string filename;
            int64 loadStartTime;

            MapData() {}
            MapData(const string&in key, const string&in filename, int64 loadStartTime) {
                this.key = key;
                this.filename = filename;
                this.loadStartTime = loadStartTime;
            }
        }

        array<MapData>@ mapsInQueue = {};

        void OnDownloadCompleted(const string&in key) {
            for (uint i = 0; i < mapsInQueue.Length; i++) {
                if (mapsInQueue[i].key == key) mapsInQueue.RemoveAt(i);
            }
        }

        void OnDownloadCancelled(const string&in key) {

        }
    }
}
