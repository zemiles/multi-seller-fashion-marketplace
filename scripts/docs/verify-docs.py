"""Read-only contract/example validation; requires jsonschema >= 4.18."""
from pathlib import Path
import hashlib
import json
import re
from jsonschema import Draft202012Validator, FormatChecker

ROOT = Path(__file__).resolve().parents[2]
errors = []
counts = {"contracts": 0, "operations": 0, "examples": 0, "schemas": 0, "references": 0}


def require(condition, message):
    if not condition:
        errors.append(message)


def pointer(doc, value):
    require(value.startswith("#/"), f"External ref not supported: {value}")
    current = doc
    for segment in value.removeprefix("#/").split("/"):
        current = current[segment.replace("~1", "/").replace("~0", "~")]
    return current


requirements = "\n".join(p.read_text(encoding="utf-8") for p in (ROOT / "docs/requirements").glob("*.md"))
for file in sorted((ROOT / "contracts").glob("*.openapi.json")):
    doc = json.loads(file.read_text(encoding="utf-8"))
    counts["contracts"] += 1
    require(doc.get("openapi") == "3.1.0", f"{file.name}: OpenAPI version")
    seen = set()

    def walk(node):
        if isinstance(node, dict):
            if "$ref" in node:
                counts["references"] += 1
                try:
                    pointer(doc, node["$ref"])
                except (KeyError, TypeError):
                    errors.append(f"{file.name}: unresolved {node['$ref']}")
            if "schema" in node and "example" in node:
                counts["examples"] += 1
                schema = {"components": doc.get("components", {}), **node["schema"]}
                for error in Draft202012Validator(schema, format_checker=FormatChecker()).iter_errors(node["example"]):
                    errors.append(f"{file.name} {node['schema']}: example {list(error.path)} {error.message}")
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    walk(doc)
    for name, schema in doc.get("components", {}).get("schemas", {}).items():
        counts["schemas"] += 1
        try:
            Draft202012Validator.check_schema(schema)
        except Exception as error:
            errors.append(f"{file.name} {name}: {error}")
    for path, methods in doc["paths"].items():
        for method, op in methods.items():
            if method not in {"get", "post", "put", "patch", "delete", "options", "head", "trace"}:
                continue
            counts["operations"] += 1
            label = f"{file.name} {method} {path}"
            require(op["operationId"] not in seen, f"{label}: duplicate operationId")
            seen.add(op["operationId"])
            params = [pointer(doc, p["$ref"]) if "$ref" in p else p for p in op.get("parameters", [])]
            pairs = [(p["in"], p["name"]) for p in params]
            require(len(pairs) == len(set(pairs)), f"{label}: duplicate parameters")
            require(set(re.findall(r"\{([^}]+)\}", path)) == {p["name"] for p in params if p["in"] == "path" and p.get("required")}, f"{label}: path parameter mismatch")
            for security in op.get("security", doc.get("security", [])):
                for name in security:
                    require(name in doc["components"]["securitySchemes"], f"{label}: unknown security {name}")
            for rid in op.get("x-requirements", []):
                require(rid in requirements, f"{label}: unknown requirement {rid}")
            require("x-implementation" in op, f"{label}: missing implementation status")

for mode in ["current", "target"]:
    model = json.loads((ROOT / f"docs/erd/{mode}/schema.json").read_text(encoding="utf-8"))
    require(len(model["tables"]) == len({t["id"] for t in model["tables"]}), f"{mode}: duplicate table")
    for source in model["sources"]:
        actual = hashlib.sha256((ROOT / source["path"]).read_bytes()).hexdigest()
        require(actual == source["sha256"], f"{mode}: stale migration hash {source['path']}")
    grouped = [t for g in model["groups"] for t in g["tableIds"]]
    require(len(grouped) == len(set(grouped)) == len(model["tables"]), f"{mode}: incomplete/duplicate diagram groups")
    require(all(len(g["tableIds"]) <= 16 for g in model["groups"]), f"{mode}: oversized ERD")

if errors:
    print("\n".join(errors))
    raise SystemExit(f"FAILED: {len(errors)} checks")
print("PASS: " + ", ".join(f"{v} {k}" for k, v in counts.items()))
print("PASS: source hashes, group coverage, references, path parameters, role schemes, requirement IDs, JSON Schema examples")
print("This does not execute HTTP APIs, migrations, concurrency or financial business rules.")
