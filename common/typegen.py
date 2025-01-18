#!/usr/bin/python3

import sys

try:
    import xmlschema
except ImportError:
    print("The package `xmlschema` was not found in the environment. Install it using pip to run this script.", file=sys.stderr)
    exit(1)

from targets import angelscript, rust

# -- Load schema
with open("schema/types.xsd", "r") as f:
    schema = xmlschema.XMLSchema(f)

with open("types.xml", "r") as f:
    try:
        xs = schema.to_dict("types.xml")
    except xmlschema.XMLSchemaDecodeError as e:
        print(e.msg, file=sys.stderr)
        exit(1)

# -- Write Rust bindings
rust.write_rust_bindings(xs, "../server/src/datatypes.rs")

# -- Write Angelscript bindings
angelscript.write_angelscript_bindings(xs, "../client/src/datatypes.as")

print(f"Generated bindings for {len(xs['struct'])} types.")
