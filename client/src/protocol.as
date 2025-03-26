// Implementation of a full TCP custom protocol, similar to websockets.
// It works by sending JSON messages back and forth on the server.
//
// The connection will time out automatically if the server receives no messages,
// so it is the client's responsability to send a ping message at least regularly to keep
// the connection alive.
class Protocol {
    Net::Socket @socket;
    ConnectionState state;
    int msgSize;

    Protocol() {
        @socket = null;
        state = ConnectionState::Closed;
        msgSize = 0;
    }

  private

    Json::Value @SendHandshakeRequest(Json::Value @message) {
        if (!InnerSend(Json::Write(message))) {
            trace("[Protocol::Connect] Failed sending handshake message.");
            Fail();
            return null;
        }

        string handshakeReply = BlockRecv(Settings::NetworkTimeout);
        if (handshakeReply == "") {
            trace("[Protocol::Connect] Handshake reply reception timed out after " +
                  Settings::NetworkTimeout + "ms.");
            Fail();
            return null;
        }

        try {
            return Json::Parse(handshakeReply);
        } catch {
            err("Protocol::Connect", "Received an invalid handshake response.");
            error("Got this message: " + handshakeReply);
            error("Error: " + getExceptionInfo());
            Fail();
            return null;
        }
    }

    int HandleHandshakeFailure(Json::Value @error) {
        HandshakeFailureIntentCode code = HandshakeFailureIntentCode(int(error["intent_code"]));
        string reason = string(error["reason"]);
        switch (code) {
        case HandshakeFailureIntentCode::ShowError:
            err("Protocol::Connect", "Connection to server failed: " + reason);
            return -2;
        case HandshakeFailureIntentCode::RequireUpdate:
            UI::ShowNotification(Icons::Upload + " Update Required!",
                                 "A new update is required: " + reason,
                                 vec4(.4, .4, 1., 1.),
                                 15000);
            print("[Protocol::Connect] New update required: " + reason);
            return -2;
        case HandshakeFailureIntentCode::Reauthenticate:
            print("[Protocol::Connect] Reauthenticating: " + reason);
            PersistantStorage::ClientToken = "";
            return -1;
        default:
            err("Protocol::Connect", "Unhandled handshake failure code: " + code);
            return -2;
        }
    }

    int Connect(const string& in host, uint16 port, HandshakeRequest handshake) {
        state = ConnectionState::Connecting;
        @socket = Net::Socket();
        msgSize = 0;

        // Socket Creation
        if (!socket.Connect(host, port)) {
            trace("[Protocol::Connect] Could not create socket to connect to " + host + ":" + port +
                  ".");
            Fail();
            return -1;
        }
        trace("[Protocol::Connect] Socket bound and ready to connect to " + host + ":" + port +
              ".");

        // Connection
        uint64 timeoutDate = Time::Now + Settings::NetworkTimeout;
        uint64 initialDate = Time::Now;
        while (!socket.IsReady() && Time::Now < timeoutDate) {
            yield();
        }
        if (!socket.IsReady()) {
            trace("[Protocol::Connect] Connection timed out after " + Settings::NetworkTimeout +
                  "ms.");
            Fail();
            return -1;
        }
        trace("[Protocol::Connect] Connected to server after " + (Time::Now - initialDate) + "ms.");

        // Exchange keys, if necessary
        if (handshake.token == "") {
            trace("[Protocol::Connect] Not logged in, exchanging authentication keys.");
            KeyExchangeRequest request;
            request.key = Login::GetExchangeToken();
            request.accountId = User::GetAccountId();
            request.displayName = User::GetLocalUsername();

            trace("[Protocol::Connect] Sending off key exchange request.");
            Json::Value @reply = SendHandshakeRequest(KeyExchangeRequest::Serialize(request));
            if (@reply is null)
                return -1;

            if (reply.HasKey("success") && !bool(reply["success"])) {
                return HandleHandshakeFailure(reply);
            }

            trace("[Protocol::Connect] Got new authentication token.");
            PersistantStorage::ClientToken = reply["token"];
            handshake.token = reply["token"];
        }

        // Opening Handshake
        trace("[Protocol::Connect] Sending opening handshake.");
        Json::Value @reply = SendHandshakeRequest(HandshakeRequest::Serialize(handshake));
        if (@reply is null)
            return -1;

        // Handshake Check
        bool success = false;
        try {
            success = reply["success"];
            if (!success) {
                Fail();
                return HandleHandshakeFailure(reply);
            }
            @Profile = PlayerProfile::Deserialize(reply["profile"]);
            PersistantStorage::LocalProfile = Json::Write(reply["profile"]);
        } catch {
            err("Protocol::Connect",
                "Could not connect to the server, received an invalid response.");
            error("Got this message: " + Json::Write(reply));
            error("Error: " + getExceptionInfo());
            Fail();
            return -2;
        }

        print("[Protocol::Connect] Handshake completed!");
        state = ConnectionState::Connected;
        return 0;
    }

  private

    bool InnerSend(const string& in data) {
        MemoryBuffer @buf = MemoryBuffer(4 + data.Length);
        buf.Write(data.Length);
        buf.Write(data);

        buf.Seek(0);
        return socket.Write(buf);
    }

    bool Send(const string& in data) {
        if (state != ConnectionState::Connected)
            return false;
        return InnerSend(data);
    }

    string BlockRecv(uint timeout) {
        uint timeoutDate = Time::Now + timeout;
        string message = "";
        while (message == "" && state != ConnectionState::Closed && Time::Now < timeoutDate) {
            yield();
            message = Recv();
        }
        return message;
    }

    string Recv() {
        if (state == ConnectionState::Closed)
            return "";

        if (msgSize == 0) {
            if (socket.Available() >= 4) {
                int Size = socket.ReadInt32();
                if (Size <= 0) {
                    trace("[Protocol::Recv] buffer size violation (got " + Size + ").");
                    Fail();
                    return "";
                }
                msgSize = Size;
            }
        }

        if (msgSize != 0) {
            if (socket.Available() >= msgSize) {
                string Message = socket.ReadRaw(msgSize);
                msgSize = 0;
                return Message;
            }
        }

        return "";
    }

    void Fail() {
        if (state == ConnectionState::Closed)
            return;
        trace("[Protocol::Fail] Connection fault. Closing.");
        if (@socket != null && socket.IsReady())
            socket.Close();

        state = ConnectionState::Closed;
        @socket = null;
        msgSize = 0;
    }
}

enum ProtocolFailure {
    SocketCreation,
    Timeout
}

enum HandshakeCode {
    Ok = 0,
    ParseError = 1,
    IncompatibleVersion = 2,
    AuthFailure = 3,
    AuthRefused = 4,
    CanReconnect = 5,
}

enum ConnectionState {
    Closed,
    Connecting,
    Connected,
}
