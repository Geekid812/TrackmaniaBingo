from . import common

angelscript_header = """\
// This file is automatically @generated by the `typegen` tool.
// Do not manually edit it! See `common/types.xml` for details.
"""

angelscript_class = """\
%s
class %s {
    %s;
    %s() {}
}
"""

angelscript_enum = """\
%s
enum %s {
    %s,
}
"""

angelscript_impl = """\
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

def snake_case_to_camel_case(snake: str) -> str:
    words = snake.split('_')
    return words[0] + ''.join(w.title() for w in words[1:])


def angelscript_typeof(m, datatypes) -> str:
    tname, optional, is_list, _ = common.parse_member(m)
    is_struct_type = False

    if tname in common.types:
        as_type = common.types[tname].angelscript
    elif tname in datatypes:
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


def as_serialize(struct: dict, schema: dict) -> str:
    """
    Generate Angelscript Type::Serialize() implementation
    """
    statements = []
    for m in struct['m']:
        tname, _, is_list, _ = common.parse_member(m)
        is_enum_type = tname in [e['@name'] for e in schema['enum']]
        is_struct_type = (not (tname in common.types)
                          and not is_enum_type)
        mname = snake_case_to_camel_case(m['@name'])
        if tname == 'rgbColor':
            tname = 'Color'
            is_struct_type = True

        cls = f"cls.{mname}"
        if is_struct_type:
            cls = f"{tname}::Serialize({cls}{'[i]' if is_list else ''})"
        if is_enum_type:
            cls = f"int({cls})"

        if is_list and (is_struct_type or is_enum_type):
            stmt = "array<Json::Value@> {0} = {{}};\n        for (uint i = 0; i < {1}.Length; i++) {{\n            {0}.InsertLast({2});\n        }}\n        value[\"{3}\"] = {0};".format(
                mname, f"cls.{mname}", cls, m['@name'])
        else:
            stmt = f"value[\"{m['@name']}\"] = {cls};"

        statements.append(stmt)

    return "\n        ".join(statements)


def as_deserialize(struct: dict, schema: dict) -> str:
    """
    Generate Angelscript Type::Deserialize() implementation
    """
    statements = []
    for m in struct['m']:
        tname, optional, is_list, _ = common.parse_member(m)
        is_enum_type = tname in [e['@name'] for e in schema['enum']]
        is_struct_type = (not (tname in common.types)
                          and not is_enum_type)
        mname = snake_case_to_camel_case(m["@name"])
        if tname == 'rgbColor':
            tname = 'Color'
            is_struct_type = True

        value = f"value[\"{m['@name']}\"]"
        if is_list:
            value += "[i]"
        if is_struct_type:
            value = f"{tname}::Deserialize({value})"
        if is_enum_type:
            value = f"{tname}(int({value}))"

        stmt = f"cls.{mname} = {value};"
        if is_list:
            stmt = "for (uint i = 0; i < value[\"{2}\"].Length; i++) {{\n            cls.{0}.InsertLast({1});\n        }}".format(
                mname, value, m['@name'])
        if optional:
            stmt = f"if (value[\"{m['@name']}\"].GetType() != Json::Type::Null) " + stmt
        statements.append(stmt)

    return "\n        ".join(statements)


def angelscript_as_member(m: dict, datatypes: list) -> str:
    tname, _, _, default = common.parse_member(m)
    member = f"{angelscript_typeof(m, datatypes)} {snake_case_to_camel_case(m['@name'])}"
    if default:
        if tname == "string":
            default = f"\"{default}\""
        member += f" = {default}"

    return member

def write_angelscript_bindings(schema: dict, path: str):
    print("Writing Angelscript bindings...", end=' ')

    with open(path, "w") as f:
        f.write(angelscript_header)

        datatypes = [struct['@name'] for struct in schema['struct'] + schema['enum']]
        for struct in schema['struct']:
            members = [
                angelscript_as_member(m, datatypes) for m in struct['m']]
            comment = f"\n/* {struct['comment']} */" if "comment" in struct else ""

            f.write(angelscript_class %
                    (comment, struct["@name"], ";\n    ".join(members), struct['@name']))

            serialize_impl = as_serialize(struct, schema)
            deserialize_impl = as_deserialize(struct, schema)
            f.write(angelscript_impl.replace(
                "@name", struct["@name"]) % (serialize_impl, deserialize_impl))

        for enum in schema['enum']:
            values = common.enum_list(enum)
            comment = f"\n/* {enum['comment']} */" if "comment" in enum else ""

            f.write(angelscript_enum %
                    (comment, enum['@name'], ",\n    ".join(values)))
        print("OK!")
