
namespace Net::Extra {

    /* Generic error handler for HTTP requests. Returns whether an error occured. */
    bool RequestRaiseError(const string&in ns, Net::HttpRequest@ req) {
        if (req.ResponseCode() == 0) {
            error("[" +  ns + "] Request to '" + req.Url + "' failed with error message: " + req.Error());
            return true;
        }

        if (req.ResponseCode() != 200) {
            error("[" + ns + "] Request to '" + req.Url + "' failed with status code " + req.ResponseCode() + ".\n" + req.String());
            return true;
        }

        return false;
    }

}
