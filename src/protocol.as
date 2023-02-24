// Implementation of a full TCP custom protocol, similar to websockets
class HandshakeData {
    string ClientVersion;
    string AuthToken;

    Json::Value ToJSON() {
        auto object = Json::Object();
        object["version"] = ClientVersion;
        object["token"] = AuthToken;
        return object;
    }
}

class Protocol {
    Net::Socket@ Socket;
    ConnectionState State;
    int MsgSize;

    Protocol() {
        @Socket = null;
        State = ConnectionState::Closed;
        MsgSize = 0;
    }

    int Connect(const string&in host, uint16 port, HandshakeData handshake) {
        State = ConnectionState::Connecting;
        @Socket = Net::Socket();
        MsgSize = 0;
        
        // Socket Creation
        if (!Socket.Connect(host, port)) {
            trace("Protocol: Could not create socket to connect to " + host + ":" + port + ".");
            Fail();
            return -1;
        }
        trace("Protocol: Socket bound and ready to connect to " + host + ":" + port + ".");

        // Connection
        uint64 TimeoutDate = Time::Now + Settings::NetworkTimeout;
        uint64 InitialDate = Time::Now;
        while (!Socket.CanWrite() && Time::Now < TimeoutDate) { yield(); }
        if (!Socket.CanWrite()) {
            trace("Protocol: Connection timed out after " + Settings::NetworkTimeout + "ms.");
            Fail();
            return -1;
        }
        trace("Protocol: Connected to server after " + (Time::Now - InitialDate) + "ms.");

        // Opening Handshake
        if (!InnerSend(Json::Write(handshake.ToJSON()))) {
            trace("Protocol: Failed sending opening handshake.");
            Fail();
            return -1;
        }
        trace("Protocol: Opening handshake sent.");

        string HandshakeReply = BlockRecv(Settings::NetworkTimeout);
        if (HandshakeReply == "") {
            trace("Protocol: Handshake reply reception timed out after " + Settings::NetworkTimeout + "ms.");
            Fail();
            return -1;
        }

        // Handshake Check
        int StatusCode;
        try {
            Json::Value@ Reply = Json::Parse(HandshakeReply);
            StatusCode = Reply["code"];
            if (@Reply["username"] != null) {
                LocalUsername = Reply["username"];
            }
        } catch {
            trace("Protocol: Handshake reply parse failed. Got: " + HandshakeReply);
            Fail();
            return -1;
        }

        if (StatusCode == 0 || StatusCode == 5) {
            trace("Protocol: Handshake reply validated. Connection has been established!");
            State = ConnectionState::Connected;
        } else {
            trace("Protocol: Received non-zero code " + StatusCode + " in handshake.");
            Fail();
        }
        return StatusCode;
    }

    private bool InnerSend(const string&in data) {
        MemoryBuffer@ buf = MemoryBuffer(4);
        buf.Write(data.Length);
        buf.Seek(0);
        return Socket.WriteRaw(buf.ReadString(4) + data);
    }

    bool Send(const string&in data) {
        if (State != ConnectionState::Connected) return false;
        return InnerSend(data);
    }

    string BlockRecv(uint timeout) {
        uint TimeoutDate = Time::Now + timeout;
        string Message = "";
        while (Message == "" && State != ConnectionState::Closed && Time::Now < TimeoutDate) { yield(); Message = Recv(); }
        return Message;
    }

    string Recv() {
        if (State == ConnectionState::Closed) return "";

        if (MsgSize == 0) {
            if (Socket.Available() >= 4) {
                MemoryBuffer@ buf = MemoryBuffer(4);
                buf.Write(Socket.ReadRaw(4));
                buf.Seek(0);
                int Size = buf.ReadInt32();
                if (Size <= 0) {
                    trace("Protocol: buffer size violation (got " + Size + ").");
                    Fail();
                    return "";
                }
                MsgSize = Size;
                trace("Protocol: expecting size " + Size);
            }
        }

        if (MsgSize != 0) {
            if (Socket.Available() >= MsgSize) {
                string Message = Socket.ReadRaw(MsgSize);
                MsgSize = 0;
                return Message;
            }
        }

        return "";
    }

    void Fail() {
        if (State == ConnectionState::Closed) return;
        trace("Protocol: Connection fault. Closing.");
        if (@Socket != null && Socket.CanWrite()) Socket.Close();

        State = ConnectionState::Closed;
        @Socket = null;
        MsgSize = 0;
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
    Closing
}