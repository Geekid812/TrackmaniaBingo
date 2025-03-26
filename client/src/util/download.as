
namespace Framework {

    /* Download a remote file. */
    void Download(const string& in url,
                  __internal::DownloadCallbackSuccess @successCallback = null,
                  __internal::DownloadCallbackFailure @failureCallback = null) {
        trace("[Framework::Download] Downloading '" + url + "'");
        __internal::DownloadCoroutineData data(url, successCallback, failureCallback);
        startnew(__internal::DownloadCoroutine, data);
    }

    namespace __internal {
        /* Callback definition for the result of a Download call. */
        funcdef void DownloadCallbackSuccess(const string& in url, MemoryBuffer @buffer);
        funcdef void DownloadCallbackFailure(const string& in url);

        class DownloadCoroutineData {
            string url;
            DownloadCallbackSuccess @successCallback;
            DownloadCallbackFailure @failureCallback;

            DownloadCoroutineData() {}

            DownloadCoroutineData(const string& in url,
                                  DownloadCallbackSuccess @successCallback,
                                  DownloadCallbackFailure @failureCallback) {
                this.url = url;
                @ this.successCallback = successCallback;
                @ this.failureCallback = failureCallback;
            }

        }

        void
        DownloadCoroutine(ref @arg) {

            DownloadCoroutineData data = cast<DownloadCoroutineData>(arg);

            Net::HttpRequest @req = Net::HttpGet(data.url);
            while (!req.Finished()) {
                yield();
            }
            if (Extra::Net::RequestRaiseError("Framework::Download", req)) {
                if (@data.failureCallback !is null)
                    data.failureCallback(data.url);
                return;
            }

            trace("[Framework::Download] Download of '" + data.url +
                  "' completed. Total size: " + Extra::IO::FormatFileSize(req.Buffer().GetSize()));
            if (@data.successCallback !is null)
                data.successCallback(data.url, req.Buffer());
        }
    }
}
