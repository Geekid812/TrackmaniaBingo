from dataclasses import dataclass

# -- Definitions
@dataclass
class TypeDef:
    angelscript: str
    rust: str
    serde_as: str = None


types = {
    "int": TypeDef("int", "i32"),
    "uint": TypeDef("uint", "u32"),
    "string": TypeDef("string", "String"),
    "bool": TypeDef("bool", "bool"),
    "rgbColor": TypeDef("vec3", "Color"),
    "datetime": TypeDef("uint64", "DateTime<Utc>", serde_as="TimestampSeconds"),
    "duration": TypeDef("int64", "Duration", serde_as="DurationMilliSeconds<i64>"),
}

def parse_member(m: dict) -> (str, bool, bool, str):
    tname = m["@type"]
    optional = "@optional" in m and m["@optional"]
    is_list = tname.startswith("list[") and tname[-1] == "]"
    default = m["@default"] if "@default" in m else None

    if is_list:
        tname = tname[5:-1]

    return tname, optional, is_list, default


def enum_list(e: dict) -> list[str]:
    values = []
    for value in e['v']:
        if type(value) is dict and "@id" in value:
            value = f"{value['$']} = {value['@id']}"
        values.append(value)
    return values
