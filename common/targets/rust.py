from . import common

rust_header = """\
// This file is automatically @generated by the `typegen` tool.
// Do not manually edit it! See `common/types.xml` for details.
#![allow(unused_imports)]
use chrono::{DateTime, Duration, Utc};
use derivative::Derivative;
use serde::{Deserialize, Serialize};
use serde_repr::{Deserialize_repr, Serialize_repr};
use serde_with::{serde_as, DurationMilliSeconds, TimestampSeconds};

use crate::core::util::Color;
"""

rust_struct = """\
%s
#[serde_as]
#[derive(Serialize, Deserialize, Debug, Clone, Derivative, PartialEq, Eq)]
#[derivative(Default)]
pub struct %s {
    %s,
}
"""

rust_enum = """\
%s
#[derive(Serialize_repr, Deserialize_repr, Debug, PartialEq, Eq, Copy, Clone, Default)]
#[repr(u8)]
pub enum %s {
    #[default]
    %s,
}
"""



def rust_typeof(m, datatypes) -> str:
    tname, optional, is_list, _ = common.parse_member(m)

    if tname in common.types:
        rust_type = common.types[tname].rust
    elif tname in datatypes:
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


def rust_as_member(m: dict, datatypes: list) -> str:
    tname, optional, _, default = common.parse_member(m)
    rtype = rust_typeof(m, datatypes)
    member = f"pub {m['@name']}: {rtype}"
    if rtype == "Duration":
        default = f"Duration::milliseconds({default if default is not None else 0})"

    if tname in common.types and common.types[tname].serde_as:
        member = f"#[serde_as(as = \"{common.types[tname].serde_as}\")]\n\t" + member
    if default:
        if optional:
            default = f"Some({default})"
        member = f"#[derivative(Default(value = \"{default}\"))]\n\t" + member

    return member

def write_rust_bindings(schema: dict, path: str):
    print("Writing Rust bindings...", end=' ')

    with open(path, "w") as f:
        f.write(rust_header)

        datatypes = [datatype['@name'] for datatype in schema['struct'] + schema['enum']]
        for struct in schema['struct']:
            members = [
                rust_as_member(m, datatypes) for m in struct['m']]
            comment = f"\n/* {struct['comment']} */" if "comment" in struct else ""

            f.write(rust_struct %
                    (comment, struct["@name"], ",\n    ".join(members)))

        for enum in schema['enum']:
            values = common.enum_list(enum)
            comment = f"\n/* {enum['comment']} */" if "comment" in enum else ""

            f.write(rust_enum %
                    (comment, enum['@name'], ",\n    ".join(values)))

        print("OK!")
