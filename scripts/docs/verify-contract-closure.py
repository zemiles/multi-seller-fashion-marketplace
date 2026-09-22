"""Read-only v1 supplemental contract/model closure checks, not application tests."""
from pathlib import Path
from copy import deepcopy
import hashlib
import json
import re
from jsonschema import Draft202012Validator, FormatChecker

ROOT = Path(__file__).resolve().parents[2]
def load(p):
    return json.loads((ROOT / p).read_text(encoding="utf-8"))

expected = {
    "X-01": "quoteClaim",
    "X-02": "requestClaimReasonChange listMyClaimReasonChanges getSellerClaim listSellerClaimReasonChanges decideClaimReasonChange",
    "X-03": "recordReturnTracking correctShipment",
    "X-04": "listSellerVerificationReviews listProductReviewRequests listReviewModerationRequests listConceptTaxonomies listAccountChangeReviews queryTaxonomies",
    "X-05": "getSellerSettlementAccount listSellerAppeals getSellerAppeal getUploadStatus",
    "X-06": "listAdministrators getAdministrator requestAdminRoleChange executeAdminRoleChange requestAdminMfaRecovery executeAdminMfaRecovery getApproval",
    "X-07": "listEventQueues replayEventQueue getRecoveryJob queryLocalEventQueues replayLocalEventQueue queryLocalRecoveryJob",
    "X-08": "convertExchange",
    "X-09": "getOrderForSupport getClaimForSupport createClaimException",
    "X-10": "ingestServerBehavior",
    "X-11": "createSearchRebuild getSearchRebuild",
}
expected = {k: set(v.split()) for k, v in expected.items()}
contracts = {p.name: load(p.relative_to(ROOT)) for p in (ROOT / "contracts").glob("*.openapi.json")}
operations = {}
for filename, doc in contracts.items():
    for route, methods in doc["paths"].items():
        for method, op in methods.items():
            if "operationId" in op:
                operations[(filename, op["operationId"])] = (doc, route, method, op)
extensions = load("docs/implementation/contract-extensions.json")
assert len(extensions) == len(expected) == 11
negative_count = 0
for ext in extensions:
    group = ext["id"]
    actual = {op["operationId"] for _, _, _, op in operations.values() if op.get("x-contract-extension") == group}
    assert actual == expected[group], (group, actual ^ expected[group])
    assert {o["operationId"] for o in ext["operations"]} == actual
    assert ext["status"] == "SPECIFIED" and ext["runtimeStatus"] == "NOT_IMPLEMENTED"
    for record in ext["operations"]:
        doc, route, method, op = operations[(record["contract"], record["operationId"])]
        assert (record["path"], record["method"]) == (route, method.upper())
        assert op["x-implementation"] == "planned"
        assert op["x-authorized-roles"] and op["x-requirements"]
        assert set(op["x-error-codes"]) <= set(op["responses"])
        security = op.get("security", doc.get("security"))
        assert security
        if route.startswith("/internal/"):
            assert all("serviceJWT" in s and "csrfToken" not in s for s in security)
            assert op.get("x-service-scope")
        else:
            cookie = "adminCookie" if "/admin/" in route else "sessionCookie"
            assert all(cookie in s for s in security), (route, security)
            assert all(("csrfToken" in s) == (method != "get") for s in security)
        media = op.get("requestBody", {}).get("content", {}).get("application/json")
        if not media:
            continue
        validator = Draft202012Validator({"components": doc["components"], **media["schema"]}, format_checker=FormatChecker())
        example = media["example"]
        assert validator.is_valid(example), op["operationId"]
        schema = doc["components"]["schemas"][media["schema"]["$ref"].split("/")[-1]]
        assert schema["additionalProperties"] is False
        for field in schema["required"]:
            bad = deepcopy(example)
            del bad[field]
            assert not validator.is_valid(bad), (op["operationId"], "missing", field)
            negative_count += 1
        bad = {**example, "untrustedField": "injected"}
        assert not validator.is_valid(bad), op["operationId"]
        negative_count += 1
        if "expectedVersion" in schema["properties"]:
            assert not validator.is_valid({**example, "expectedVersion": -1})
            negative_count += 1

def schema_validator(filename, name):
    doc = contracts[filename]
    return Draft202012Validator({"components": doc["components"], "$ref": "#/components/schemas/" + name}, format_checker=FormatChecker())

public = contracts["commerce-public.openapi.json"]["components"]["schemas"]
assert "expectedVersion" in public["ClaimCreate"]["required"]
assert "quoteId" not in public["ClaimCreate"]["required"]
assert len(public["Approval"]["properties"]["actionType"]["enum"]) == 11
for name in ["createApproval", "listApprovals", "decideApproval", "getApproval"]:
    op = operations[("commerce-public.openapi.json", name)][3]
    assert set(op["x-approval-role-map"]) == set(public["Approval"]["properties"]["actionType"]["enum"])
    assert set(op["x-authorized-roles"]) == {"ADMIN_FINANCE", "ADMIN_RISK", "ADMIN_IAM", "ADMIN_SUPPORT"}

v = schema_validator("commerce-public.openapi.json", "UploadCreate")
image = {"purpose": "PRODUCT_IMAGE", "contentType": "image/png", "sizeBytes": 5242880, "sha256": "a" * 64}
assert v.is_valid(image)
assert not v.is_valid({**image, "sizeBytes": 5242881})
negative_count += 1
for filename, operation_id, changes in [
    ("commerce-public.openapi.json", "quoteClaim", {"type": "EXCHANGE"}),
    ("commerce-public.openapi.json", "replayEventQueue", {"queueType": "INBOX"}),
    ("commerce-public.openapi.json", "requestAdminRoleChange", {"roles": ["SUPERADMIN"]}),
    ("discovery-internal.openapi.json", "ingestServerBehavior", {"type": "CART_ADD"}),
    ("discovery-internal.openapi.json", "ingestServerBehavior", {"analyticsOptIn": False}),
]:
    doc, _, _, op = operations[(filename, operation_id)]
    media = op["requestBody"]["content"]["application/json"]
    v = Draft202012Validator({"components": doc["components"], **media["schema"]}, format_checker=FormatChecker())
    assert not v.is_valid({**media["example"], **changes}), operation_id
    negative_count += 1

trace = load("docs/implementation/traceability.json")
assert all(r["contractStatus"] == "SPECIFIED" for r in trace["requirements"])
assert all(r["additionalTest"]["status"] == "NOT_RUN" for r in trace["requirements"])
target = load("docs/erd/target/schema.json")
tables = {t["id"]: t for t in target["tables"]}
assert any(c["name"] == "gross_net_amount" and not c["nullable"] for c in tables["settlement.settlement"]["columns"])
assert any("gross_net_amount - hold_amount" in c for c in tables["settlement.settlement"]["constraints"])
ledger = tables["settlement.seller_ledger_entry"]
assert ["reversal_of_entry_id"] not in ledger["unique"]
assert ["source_key"] in ledger["unique"]
assert any(not i["unique"] and "reversal_of_entry_id" in i["sql"] for i in ledger["indexes"])
for suffix in ["run", "receipt", "discrepancy"]:
    assert "settlement.bank_reconciliation_" + suffix in tables
for owner in ["commerce", "payment", "settlement", "discovery"]:
    assert owner + ".event_recovery_job" in tables
    assert ["entry_id"] in tables[owner + ".consumer_inbox"]["unique"]
for fk in target["fks"]:
    assert tables[fk["from"]]["service"] == tables[fk["to"]]["service"]
manifest = load("docs/ddl/manifest.json")
assert len(manifest) == 12
for file in manifest:
    model = load(f'docs/erd/{file["model"]}/schema.json')
    local = [t for t in model["tables"] if t["service"] == file["service"]]
    assert file["applied"] is False and file["purpose"] == "EMPTY_ISOLATED_DB_ONLY"
    assert file["tables"] == len(local)
    assert file["sha256"] == hashlib.sha256((ROOT / file["path"]).read_bytes()).hexdigest()
    assert file["foreignKeys"] == sum(f["from"] in {t["id"] for t in local} for f in model["fks"])
for delta in load("docs/implementation/migration-manifest.json")["policyDeltas"]:
    assert delta["modelStatus"] == "SPECIFIED" and delta["migrationStatus"] == "NOT_APPLIED"
    assert (ROOT / delta["ddl"]).is_file()
screens = (ROOT / "docs/implementation/05-screens.md").read_text(encoding="utf-8")
public_ops = {k[1] for k in operations if k[0] == "commerce-public.openapi.json"}
for screen, cell in re.findall(r"^\| ((?:SF|SE|AD)-\d+) [^|]+\| ([^|]+) \|", screens, re.M):
    assert set(cell.strip().split(", ")) <= public_ops, screen
print(f"PASS: 11 specified extension groups / {sum(map(len, expected.values()))} operations, {negative_count} HTTP schema rejection checks; 55 requirement statuses, 4 M4 deltas, 12 DDL hashes and screen operation references.")
print("Schema/contract evidence only; authentication execution, cross-row balances and all AT/DT remain runtime tests.")
