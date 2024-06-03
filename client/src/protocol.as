// Implementation of a full TCP custom protocol, similar to websockets.
// It works by sending JSON messages back and forth on the server.
//
// The connection will time out automatically if the server receives no messages,
// so it is the client's responsability to send a ping message at least regularly to keep
// the connection alive.
class Protocol {
    Net::Socket@ socket;
    ConnectionState state;
    int msgSize;

    Protocol() {
        @socket = null;
        state = ConnectionState::Closed;
        msgSize = 0;
    }

    int Connect(const string&in host, uint16 port, HandshakeRequest handshake) {
        state = ConnectionState::Connecting;
        @socket = Net::Socket();
        msgSize = 0;
        
        // Socket Creation
        if (!socket.Connect(host, port)) {
            trace("[Protocol::Connect] Could not create socket to connect to " + host + ":" + port + ".");
            Fail();
            return -1;
        }
        trace("[Protocol::Connect] Socket bound and ready to connect to " + host + ":" + port + ".");

        // Connection
        uint64 timeoutDate = Time::Now + Settings::NetworkTimeout;
        uint64 initialDate = Time::Now;
        while (!socket.IsReady() && Time::Now < timeoutDate) { yield(); }
        if (!socket.IsReady()) {
            trace("[Protocol::Connect] Connection timed out after " + Settings::NetworkTimeout + "ms.");
            Fail();
            return -1;
        }
        trace("[Protocol::Connect] Connected to server after " + (Time::Now - initialDate) + "ms.");

        // Opening Handshake
        if (!InnerSend(Json::Write(HandshakeRequest::Serialize(handshake)))) {
            trace("[Protocol::Connect] Failed sending opening handshake.");
            Fail();
            return -1;
        }
        trace("[Protocol::Connect] Opening handshake sent.");

        string handshakeReply = BlockRecv(Settings::NetworkTimeout);
        if (handshakeReply == "") {
            trace("[Protocol::Connect] Handshake reply reception timed out after " + Settings::NetworkTimeout + "ms.");
            Fail();
            return -1;
        }

        // Handshake Check
        bool success = false;
        try {
            Json::Value@ reply = Json::Parse(handshakeReply);
            success = reply["success"];
            if (!success) {
                HandshakeFailureIntentCode code = HandshakeFailureIntentCode(int(reply["intent_code"]));
                string reason = string(reply["reason"]);
                switch (code) {
                    case HandshakeFailureIntentCode::ShowError:
                        err("Protocol::Connect", "Connection to server failed: " + reason);
                        break;
                    case HandshakeFailureIntentCode::RequireUpdate:
                        UI::ShowNotification(Icons::Upload + " Update Required!", "A new update is required: " + reason, vec4(.4, .4, 1., 1.), 15000);
                        print("[Protocol::Connect] New update required: " + reason);
                        break;
                    case HandshakeFailureIntentCode::Reauthenticate:
                        print("[Protocol::Connect] Reauthenticating: " + reason);
                        Login::Login();
                        break;
                }
                Fail();
                return -1;
            }
        } catch {
            trace("[Protocol::Connect] Handshake reply parse failed. Got: " + handshakeReply);
            Fail();
            return -1;
        }

        trace("[Protocol::Connect] Handshake completed. Connection has been established!");
        state = ConnectionState::Connected;
        return 0;
    }

    private bool InnerSend(const string&in data) {
        MemoryBuffer@ buf = MemoryBuffer(4 + data.Length);
        buf.Write(data.Length);
        buf.Write(data);

        buf.Seek(0);
        return socket.Write(buf);
    }

    bool Send(const string&in data) {
        if (state != ConnectionState::Connected) return false;
        return InnerSend(data);
    }

    string BlockRecv(uint timeout) {
        uint timeoutDate = Time::Now + timeout;
        string message = "";
        while (message == "" && state != ConnectionState::Closed && Time::Now < timeoutDate) { yield(); message = Recv(); }
        return message;
    }

    string Recv() {
        if (state == ConnectionState::Closed) return "";

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
        if (state == ConnectionState::Closed) return;
        trace("[Protocol::Fail] Connection fault. Closing.");
        if (@socket != null && socket.CanWrite()) socket.Close();

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
