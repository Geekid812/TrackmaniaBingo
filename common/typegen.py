#!/usr/bin/python3

# -- Imports
import sys
from dataclasses import dataclass

try:
    import xmlschema
except ImportError:
    print("The package `xmlschema` was not found in the environment. Install it using pip to run this script.", file=sys.stderr)
    exit(1)


# -- Definitions
@dataclass
class TypeDef:
    angelscript: str
    rust: str


types = {
    "int": TypeDef("int", "i32"),
    "uint": TypeDef("uint", "u32"),
    "string": TypeDef("string", "String")
}


def parse_member(m: dict) -> (str, bool, bool):
    tname = m["@type"]
    optional = "@optional" in m and m["@optional"]
    is_list = tname.startswith("list[") and tname[-1] == "]"

    if is_list:
        tname = tname[5:-1]

    return tname, optional, is_list


# -- Load schema
with open("types.xsd", "r") as f:
    schema = xmlschema.XMLSchema(f)

with open("types.xml", "r") as f:
    try:
        xs = schema.to_dict("types.xml")
    except xmlschema.XMLSchemaDecodeError as e:
        print(e.msg, file=sys.stderr)
        exit(1)

# -- Write Rust bindings
print("Writing Rust bindings...", end=' ')

rust_header = """\
// This file is automatically @generated by the `typegen` tool.
// Do not manually edit it! See `common/types.xml` for details.
use serde::{Serialize, Deserialize};
"""

rust_struct = """
%s
#[derive(Serialize, Deserialize, Debug)]
pub struct %s {
    %s,
}
"""


def rust_typeof(m) -> str:
    tname, optional, is_list = parse_member(m)

    if tname in types:
        rust_type = types[tname].rust
    elif tname in [struct['@name'] for struct in xs['struct']]:
        rust_type = tname
    else:
        print("Failed")
        print(f"typegen: unknown type '{tname}'.", file=sys.stderr)
        exit(1)

    if is_list:
        rust_type = f"Vec<{rust_type}>"
    if optional:
        rust_type = f"Option<{rust_type}>"

    return rust_type


with open("../server/src/datatypes.rs", "w") as f:
    f.write(rust_header)

    for struct in xs['struct']:
        members = [
            f"pub {m['@name']}: {rust_typeof(m)}" for m in struct['m']]
        comment = f"\n/* {struct['comment']} */" if "comment" in struct else ""

        f.write(rust_struct %
                (comment, struct["@name"], ",\n    ".join(members)))

    print("OK!")

# -- Write Angelscript bindings
print("Writing Angelscript bindings...", end=' ')

angelscript_header = """\
// This file is automatically @generated by the `typegen` tool.
// Do not manually edit it! See `common/types.xml` for details.
"""

angelscript_class = """
%s
class %s {
    %s;
    %s() {}
}
"""

angelscript_impl = """
namespace @name {
    Json::Value@ Serialize(@name cls) {
        auto value = Json::Object();
        %s

        return value;
    }

    @name Deserialize(Json::Value@ value) {
        auto cls = @name();
        %s

        return cls;
    }
}
"""


def angelscript_typeof(m) -> str:
    tname, optional, is_list = parse_member(m)
    is_struct_type = False

    if tname in types:
        as_type = types[tname].angelscript
    elif tname in [struct['@name'] for struct in xs['struct']]:
        as_type = tname
        is_struct_type = True
    else:
        print("Failed")
        print(f"typegen: unknown type '{tname}'.", file=sys.stderr)
        exit(1)

    if is_list:
        as_type = f"array<{as_type}>"
    if optional and is_struct_type:
        as_type = f"{as_type}@"

    return as_type


def as_serialize(struct: dict) -> str:
    """
    Generate Angelscript Type::Serialize() implementation
    """
    statements = []
    for m in struct['m']:
        statements.append("value[\"{0}\"] = cls.{0};".format(m['@name']))

    return "\n        ".join(statements)


def as_deserialize(struct: dict) -> str:
    """
    Generate Angelscript Type::Deserialize() implementation
    """
    statements = []
    for m in struct['m']:
        tname, optional, is_list = parse_member(m)
        is_struct_type = not (tname in types)

        stmt = "cls.{0} = value[\"{0}\"];".format(m['@name'])
        if is_struct_type:
            stmt = "cls.{0} = {1}::Deserialize(value[\"{0}\"]);".format(
                m['@name'], tname)
        if is_list:
            deserialized_inner_type = f"value[\"{m['@name']}\"][i]"
            if is_struct_type:
                deserialized_inner_type = f"{tname}::Deserialize({deserialized_inner_type})"

            stmt = "for (uint i = 0; i < value[\"{0}\"].Length; i++) {{\n            cls.{0}.InsertLast({1});\n        }}".format(
                m['@name'], deserialized_inner_type)
        if optional:
            stmt = f"if (value[\"{m['@name']}\"].GetType() != Json::Type::Null) " + stmt
        statements.append(stmt)

    return "\n        ".join(statements)


with open("../client/src/datatypes.as", "w") as f:
    f.write(angelscript_header)

    for struct in xs['struct']:
        members = [
            f"{angelscript_typeof(m)} {m['@name']}" for m in struct['m']]
        comment = f"\n/* {struct['comment']} */" if "comment" in struct else ""

        f.write(angelscript_class %
                (comment, struct["@name"], ";\n    ".join(members), struct['@name']))

        serialize_impl = as_serialize(struct)
        deserialize_impl = as_deserialize(struct)
        f.write(angelscript_impl.replace(
            "@name", struct["@name"]) % (serialize_impl, deserialize_impl))

    print("OK!")

print(f"Generated bindings for {len(xs['struct'])} types.")
