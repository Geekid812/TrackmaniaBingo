
namespace Framework {

    /* Callback definition for the result of a DownloadMap call. */
    funcdef void DownloadCallback(const string&in key);

    /* Download and save a map locally. */
    void DownloadMap(const string&in key, string&in filename = "", DownloadCallback@ successCallback = null, DownloadCallback@ failureCallback = null) {
        if (filename == "") filename = key;

        trace("[Framework::DownloadMap] Downloading map '" + filename + "'...");
        __internal::DownloadMapCoroutineData data(key, filename, successCallback, failureCallback);
        __internal::DownloadMapCoroutine(data);
    }

    namespace __internal {
        class DownloadMapCoroutineData {
            string key;
            string filename;
            DownloadCallback@ successCallback;
            DownloadCallback@ failureCallback;

            DownloadMapCoroutineData() {}
            DownloadMapCoroutineData(const string&in key, const string&in filename, DownloadCallback@ successCallback, DownloadCallback@ failureCallback) {
                this.key = key;
                this.filename = filename;
                @this.successCallback = successCallback;
                @this.failureCallback = failureCallback;
            }
        }

        void DownloadMapCoroutine(ref@ arg) {
            DownloadMapCoroutineData data = cast<DownloadMapCoroutineData>(arg);
            string url = URL_BASE + Settings::BackendAddress + Routes::MAPS_DOWNLOAD + "/" + data.key;

            Net::HttpRequest@ req = Net::HttpGet(url);
            while (!req.Finished()) yield();
            if (Net::Extra::RequestRaiseError("Framework::DownloadMap", req)) {
                if (@data.failureCallback !is null) data.failureCallback(data.key);
                return;
            }

            string filePath = IO::Extra::FromMapDownloadsFolder(data.filename);
            req.SaveToFile(filePath);

            trace("[Framework::DownloadMap] Downloading map '" + data.filename + "' completed.");    
            if (@data.successCallback !is null) data.successCallback(data.key);        
        }
    }
}
