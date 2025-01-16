
namespace Color {
    vec3 Deserialize(Json::Value@ value) {
        return vec3(float(value['red']) / 255., float(value['green']) / 255., float(value['blue']) / 255.);
    }

    Json::Value@ Serialize(vec3 cls) {
        auto value = Json::Object();
        value['red'] = int(cls.x * 255.);
        value['green'] = int(cls.y * 255.);
        value['blue'] = int(cls.z * 255.);
        return value;
    }
}