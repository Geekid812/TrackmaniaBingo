// Implementation of a full TCP custom protocol, similar to websockets
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
            trace("[Protocol] Could not create socket to connect to " + host + ":" + port + ".");
            Fail();
            return -1;
        }
        trace("[Protocol] Socket bound and ready to connect to " + host + ":" + port + ".");

        // Connection
        uint64 timeoutDate = Time::Now + Settings::NetworkTimeout;
        uint64 initialDate = Time::Now;
        while (!socket.CanWrite() && Time::Now < timeoutDate) { yield(); }
        if (!socket.CanWrite()) {
            trace("[Protocol] Connection timed out after " + Settings::NetworkTimeout + "ms.");
            Fail();
            return -1;
        }
        trace("[Protocol] Connected to server after " + (Time::Now - initialDate) + "ms.");

        // Opening Handshake
        if (!InnerSend(Json::Write(HandshakeRequest::Serialize(handshake)))) {
            trace("[Protocol] Failed sending opening handshake.");
            Fail();
            return -1;
        }
        trace("[Protocol] Opening handshake sent.");

        string handshakeReply = BlockRecv(Settings::NetworkTimeout);
        if (handshakeReply == "") {
            trace("[Protocol] Handshake reply reception timed out after " + Settings::NetworkTimeout + "ms.");
            Fail();
            return -1;
        }

        // Handshake Check
        int statusCode;
        try {
            Json::Value@ reply = Json::Parse(handshakeReply);
            statusCode = reply["code"];
            if (reply.HasKey("profile")) {
                @Profile = PlayerProfile::Deserialize(reply["profile"]);
                PersistantStorage::LocalProfile = Json::Write(reply["profile"]);
                LocalUsername = Profile.username;
            }
        } catch {
            trace("[Protocol] Handshake reply parse failed. Got: " + handshakeReply);
            Fail();
            return -1;
        }

        if (statusCode == 0 || statusCode == 5) {
            trace("[Protocol] Handshake reply validated. Connection has been established!");
            state = ConnectionState::Connected;
        } else {
            trace("[Protocol] Received non-zero code " + statusCode + " in handshake.");
            Fail();
        }
        return statusCode;
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
                    trace("[Protocol] buffer size violation (got " + Size + ").");
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
        trace("[Protocol] Connection fault. Closing.");
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
