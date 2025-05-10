namespace __Serializable {
    enum ModeSet {
        Unset,
        Serialize,
        Deserialize
    }
}

interface JsonSerial {
    Json::Value@ ToJSON();
    void FromJSON(Json::Value@ jsObject);
}

mixin class Serializable: JsonSerial {
    __Serializable::ModeSet _mode;
    Json::Value@ _jsObject;

    string Field(const string&in name, string&in value) {
        if (_mode == __Serializable::ModeSet::Serialize) _jsObject[name] = value;
        else if (_mode == __Serializable::ModeSet::Deserialize) value = _jsObject[name];
        else _SerialError();
        
        return value;
    }

    int Field(const string&in name, int&in value) {
        if (_mode == __Serializable::ModeSet::Serialize) _jsObject[name] = value;
        else if (_mode == __Serializable::ModeSet::Deserialize) value = _jsObject[name];
        else _SerialError();
        
        return value;
    }

    bool Field(const string&in name, bool&in value) {
        if (_mode == __Serializable::ModeSet::Serialize) _jsObject[name] = value;
        else if (_mode == __Serializable::ModeSet::Deserialize) value = _jsObject[name];
        else _SerialError();
        
        return value;
    }

    void Field(const string&in name, JsonSerial& value) {
        if (_mode == __Serializable::ModeSet::Serialize) _jsObject[name] = value.ToJSON();
        else if (_mode == __Serializable::ModeSet::Deserialize) value.FromJSON(_jsObject[name]);
        else _SerialError();
    }

    void Field(const string&in name, array<int>& value) {
        if (_mode == __Serializable::ModeSet::Serialize) {
            Json::Value jsArray = Json::Array();
            for (uint i = 0; i < value.Length; i++) {
                jsArray.Add(value[i]);
            }
            _jsObject[name] = jsArray;
        } else if (_mode == __Serializable::ModeSet::Deserialize) {
            for (uint i = 0; i < _jsObject[name].Length; i++) {
                value.InsertLast(_jsObject[name][i]);
            }
        }
    }

    void ArrayWriteItem(const string&in name, Json::Value@ value) {
        if (_mode == __Serializable::ModeSet::Unset) _SerialError();

        if (_mode == __Serializable::ModeSet::Serialize) {            
            if (!_jsObject.HasKey(name)) {
                _jsObject[name] = Json::Array();
            }
            _jsObject[name].Add(value);
        }
    }

    uint ArrayLength(const string&in name) {
        if (_mode == __Serializable::ModeSet::Unset) _SerialError();

        if (_mode == __Serializable::ModeSet::Serialize) return 0;

        return _jsObject[name].Length;
    }

    Json::Value@ ArrayReadItem(const string&in name, uint index) {
        if (_mode != __Serializable::ModeSet::Deserialize) _SerialError();
        return _jsObject[name][index];
    }

    void _SerialReset() {
        @_jsObject = null;
        _mode = __Serializable::ModeSet::Unset;
    }

    void _SerialError() {
        if (_mode != __Serializable::ModeSet::Unset) throw("Serializable internal error.");

        throw("Serializable internal error: mode is unset! Field() should not be called directly.");
    } 

    Json::Value@ ToJSON() {
        _mode = __Serializable::ModeSet::Serialize;
        @_jsObject = Json::Object();
        
        DataObject();
        Json::Value@ result = _jsObject;

        _SerialReset();
        return result; 
    }

    void FromJSON(Json::Value@ jsObject) {
        _mode = __Serializable::ModeSet::Deserialize;
        @_jsObject = jsObject;

        DataObject();

        _SerialReset();
    }
}

#if SIG_DEVELOPER
class MyFooClass: Serializable {
    string name;
    int age;
    Container box;
    array<int> favoriteNumbers;
    array<Container> favoriteBoxes;

    void DataObject() {
        this.name = Field("name", this.name);
        this.age = Field("age", this.age);
        Field("box", this.box);
        Field("favoriteNumbers", this.favoriteNumbers);
        _FieldFavoriteBoxes();
    }

    void _FieldFavoriteBoxes() {
        for (uint i = 0; i < this.favoriteBoxes.Length; i++) {
            ArrayWriteItem("favoriteBoxes", this.favoriteBoxes[i].ToJSON());
        }
        this.favoriteBoxes.Resize(ArrayLength("favoriteBoxes"));
        for (uint i = 0; i < this.favoriteBoxes.Length; i++) {
            this.favoriteBoxes[i].FromJSON(ArrayReadItem("favoriteBoxes", i));
        }
    }
}

class Container: Serializable {
    bool theTruth;


    Container() {}
    Container(bool truth) {
        this.theTruth = truth;
    }

    void DataObject() {
        this.theTruth = Field("theTruth", this.theTruth);
    }
}

void _testSerial() {
    MyFooClass myFoo();
    myFoo.name = "Barry";
    myFoo.age = 21;
    myFoo.favoriteNumbers = {1, 2, 42};

    Container myBox(true);
    myFoo.box = myBox;

    myFoo.favoriteBoxes = {Container(true), Container(false), Container(true)};

    Json::Value@ json = myFoo.ToJSON();
    print(Json::Write(json));

    MyFooClass myBar();
    myBar.FromJSON(json);

    print(myBar.name);
    print(myBar.age);
    print(myBar.box.theTruth);

    for (uint i = 0; i < myBar.favoriteNumbers.Length; i++) {
        print("favoriteNumber ["+ i +"] "+myBar.favoriteNumbers[i]);
    }


    for (uint i = 0; i < myBar.favoriteBoxes.Length; i++) {
        print("favoriteBox ["+ i +"] "+myBar.favoriteBoxes[i].theTruth);
    }
}
#endif
