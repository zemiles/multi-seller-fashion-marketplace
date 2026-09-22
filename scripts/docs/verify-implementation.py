"""Read-only validation of design artifacts, not a running-service integration test."""
from pathlib import Path
import json
import re
from jsonschema import Draft202012Validator, FormatChecker

ROOT = Path(__file__).resolve().parents[2]
errors = []


def read(name):
    return (ROOT / name).read_text(encoding="utf-8")


def load(name):
    return json.loads(read(name))


def require(condition, message):
    if not condition:
        errors.append(message)


def business_errors(event):
    """Only payload-local invariants; ownership/receipts require real repositories."""
    problems = []

    def check(condition, name):
        if not condition:
            problems.append(name)

    def unique(rows, key, name):
        keys = [key(row) for row in rows]
        check(len(keys) == len(set(keys)), name)

    p, kind, stream = event["payload"], event["eventType"], event["aggregateType"]
    identity = {
        "PRODUCT": p.get("productId"), "PRODUCT_ANALYSIS": p.get("productId"),
        "ORDER": p.get("orderId"), "PAYMENT_FLOW": p.get("orderId"),
        "SETTLEMENT": p.get("settlementId"), "SELLER_CONTROL": p.get("sellerId"),
        "ORDER_SELLER": f'{p.get("orderId")}:{p.get("sellerId")}',
    }
    check(event["aggregateId"] == identity[stream], "aggregate/payload identity")
    if "priorFinancialVersion" in p:
        check(p["priorFinancialVersion"] == event["aggregateVersion"] - 1, "financial sequence")
    if "currency" in p and isinstance(p.get("amount"), dict):
        check(p["currency"] == p["amount"]["currency"], "currency consistency")
    if kind == "SellerSettlementHoldChanged":
        check(stream == ("ORDER_SELLER" if p.get("orderId") else "SELLER_CONTROL"), "hold stream")
    if kind == "PaymentApproved":
        check(p["merchantTxId"].startswith("mp-" + p["orderId"] + "-"), "merchant order identity")
        unique(p["items"], lambda x: x["orderItemId"], "duplicate item")
        unique(p["charges"], lambda x: x["orderChargeId"], "duplicate charge")
        unique(p["charges"], lambda x: x["sellerId"], "duplicate seller shipping charge")
        check(all(c["sellerId"] in {i["sellerId"] for i in p["items"]} for c in p["charges"]), "charge seller")
        check(sum(i["paidAmount"] for i in p["items"]) + sum(c["amount"] for c in p["charges"]) == p["amount"]["amount"], "approval total")
        for item in p["items"]:
            units = item["units"]
            check([u["unitOrdinal"] for u in units] == list(range(1, item["quantity"] + 1)), "ordered complete unit ordinals")
            check(item["paidAmount"] == item["productAmount"] - item["discountAmount"] + item["taxAmount"], "item arithmetic")
            for field in ("productAmount", "discountAmount", "paidAmount"):
                check(sum(u[field] for u in units) == item[field], "unit sum " + field)
            for unit in units:
                check(unit["paidAmount"] == unit["productAmount"] - unit["discountAmount"], "unit arithmetic")
                check(unit["commissionAmount"] <= unit["paidAmount"], "unit fee bound")
    if kind == "RefundSucceeded":
        unique(p["items"], lambda x: x["orderItemId"], "duplicate refund item")
        unique(p["charges"], lambda x: x["orderChargeId"], "duplicate refund charge")
        check(sum(i["refundAmount"] for i in p["items"]) + sum(c["amount"] for c in p["charges"]) == p["amount"]["amount"], "refund total")
        for item in p["items"]:
            check(item["refundAmount"] == item["productRefundAmount"] - item["discountReversalAmount"] + item["taxRefundAmount"], "refund arithmetic")
            check(item["unitOrdinals"] == sorted(item["unitOrdinals"]), "refund ordinal ordering")
    if kind == "PurchaseConfirmed":
        pairs = [(u["orderItemId"], u["unitOrdinal"]) for u in p["units"]]
        check(pairs == sorted(set(pairs)), "recognition ordering/uniqueness")
        check(all(u["commissionAmount"] <= u["paidAmount"] for u in p["units"]), "recognition fee bound")
    if kind == "ShipmentDelivered":
        pairs = [(i["orderItemId"], ordinal) for i in p["items"] for ordinal in i["unitOrdinals"]]
        check(len(pairs) == len(set(pairs)), "duplicate delivered unit")
    if kind == "SellerFinancialAdjusted":
        unique(p["adjustments"], lambda a: a["sourceUnitOrChargeId"], "duplicate adjustment source")
        for adjustment in p["adjustments"]:
            check(adjustment["signedRevenueAmount"] != 0 or adjustment["signedFeeAmount"] != 0, "zero adjustment")
            check(adjustment["signedFeeAmount"] <= -adjustment["signedRevenueAmount"], "reversal fee bound")
            if adjustment["sourceUnitOrChargeId"].startswith("CHARGE:"):
                check(adjustment["signedFeeAmount"] == 0, "shipping fee must be zero")
    return problems


schema = load("contracts/events/v1/marketplace-events.schema.json")
Draft202012Validator.check_schema(schema)
validator = Draft202012Validator(schema, format_checker=FormatChecker())
event_names = {name.removeprefix("Event") for name in schema["$defs"] if name.startswith("Event")}
registry = set(re.findall(r"^\| ([A-Z][A-Za-z]+) / (?:catalog|order|seller-financial|payment|settlement|analysis) \|", read("docs/requirements/07-events-reliability.md"), re.M))
require(event_names == registry and len(event_names) == 19, "Event schema/registry coverage")
fixtures = list((ROOT / "contracts/events/v1/examples").glob("*.json"))
require({p.stem for p in fixtures} == event_names, "Normal fixture coverage")
for file in fixtures:
    event = json.loads(file.read_text(encoding="utf-8"))
    problems = list(validator.iter_errors(event))
    require(not problems, f"{file.name}: schema rejected: {[p.message for p in problems]}")
    if not problems:
        require(not business_errors(event), f"{file.name}: {business_errors(event)}")

# Resolve every local reference and require strict objects, including imported HTTP DTOs.
def walk(node):
    if isinstance(node, dict):
        if "$ref" in node:
            ref = node["$ref"]
            require(ref.startswith("#/$defs/") and ref.split("/")[-1] in schema["$defs"], "Unresolved ref: " + ref)
        if node.get("type") == "object":
            require(node.get("additionalProperties") is False, "Event object must reject unknown fields")
        for value in node.values():
            walk(value)
    elif isinstance(node, list):
        for value in node:
            walk(value)


walk(schema)
negatives = load("contracts/events/v1/invalid-examples.json")
require(len({n["id"] for n in negatives}) == len(negatives), "Duplicate rejection fixture ID")
for case in negatives:
    schema_problems = list(validator.iter_errors(case["data"]))
    if case["expected"] == "schema-reject":
        require(bool(schema_problems), case["id"] + ": invalid schema accepted")
    elif case["expected"] == "business-reject":
        require(not schema_problems, case["id"] + ": must first satisfy schema")
        if not schema_problems:
            require(bool(business_errors(case["data"])), case["id"] + ": invalid business arithmetic accepted")
    else:
        require(False, "Unknown rejection category: " + case["id"])

requirement_ids = set()
for file in (ROOT / "docs/requirements").glob("0[1-8]-*.md"):
    requirement_ids.update(re.findall(r"^## ([A-Z]+-\d+) ", file.read_text(encoding="utf-8"), re.M))
trace = load("docs/implementation/traceability.json")
require({r["id"] for r in trace["requirements"]} == requirement_ids and len(trace["requirements"]) == 55, "Requirement trace coverage")
model = load("docs/erd/target/schema.json")
table_ids = {t["id"] for t in model["tables"]}
actual_operations = {}
for file in (ROOT / "contracts").glob("*.openapi.json"):
    contract = json.loads(file.read_text(encoding="utf-8"))
    for route, methods in contract["paths"].items():
        for method, operation in methods.items():
            if isinstance(operation, dict) and "operationId" in operation:
                key = (file.name, operation["operationId"])
                require(key not in actual_operations, "Duplicate operationId: " + str(key))
                actual_operations[key] = (method.upper(), route, operation.get("x-requirements", []))
require({(o["contract"], o["operationId"]) for o in trace["operations"]} == set(actual_operations) and len(trace["operations"]) == len(actual_operations), "Full operation trace coverage")
for operation in trace["operations"]:
    key = (operation["contract"], operation["operationId"])
    require((operation["method"], operation["path"], operation["requirements"]) == actual_operations.get(key), "Operation trace mismatch: " + str(key))
    require(bool(operation["requirements"]) and set(operation["requirements"]) <= requirement_ids, "Operation without valid requirement: " + str(key))
acceptance_ids = set(re.findall(r"^\| (AT-\d+) \|", read("docs/requirements/08-delivery-acceptance.md"), re.M))
require({a["id"] for a in trace["acceptance"]} == acceptance_ids and len(acceptance_ids) == 32, "AT coverage")
screens = read("docs/implementation/05-screens.md")
extensions = set(re.findall(r"^\| (X-\d+) \|", screens, re.M))
require(len(extensions) == 11, "Contract extension coverage")
for requirement in trace["requirements"]:
    rid = requirement["id"]
    require(set(requirement["tables"]) <= table_ids, rid + ": unknown table")
    require(set(requirement["events"]) <= event_names, rid + ": unknown event")
    require(set(requirement["acceptanceTests"]) <= acceptance_ids, rid + ": unknown AT")
    require(set(requirement["contractExtensions"]) <= extensions, rid + ": unknown extension")
    require(requirement["additionalTest"]["id"] == "DT-" + rid and requirement["additionalTest"]["status"] == "NOT_RUN", rid + ": DT claim")
    expected = {key for key, (_, _, ids) in actual_operations.items() if rid in ids}
    require({(a["contract"], a["operationId"]) for a in requirement["apis"]} == expected, rid + ": API mapping")
    for evidence in requirement["evidence"]:
        require((ROOT / evidence).exists(), rid + ": missing implementation evidence " + evidence)
for acceptance in trace["acceptance"]:
    require(bool(acceptance["requirements"]) and set(acceptance["requirements"]) <= requirement_ids, acceptance["id"] + ": invalid requirement")

screen_count = 0
public_operations = {key[1] for key in actual_operations if key[0] == "commerce-public.openapi.json"}
for match in re.finditer(r"^\| ((?:SF|SE|AD)-\d+) [^|]+\| ([^|]+) \|", screens, re.M):
    screen_count += 1
    ids = {operation.strip() for operation in match[2].split(",")}
    require(ids <= public_operations | extensions, match[1] + ": invalid screen operation " + str(ids - public_operations - extensions))
require(screen_count == 40, "Screen coverage")
manifest = load("docs/implementation/migration-manifest.json")
require(manifest["applied"] is False, "Migration manifest must not claim applied")
def canonical_change(change):
    return json.dumps({k: v for k, v in change.items() if k not in {"wave", "state", "actualMigration", "backfillEvidence"}}, sort_keys=True)
require(sorted(map(canonical_change, manifest["changes"])) == sorted(map(canonical_change, model["changes"])), "Migration manifest full target coverage")
for change in manifest["changes"]:
    require(change["wave"] in {"M1", "M2", "M3", "M4", "M5"} and change["state"] == "PLANNED" and change["actualMigration"] is None, change["table"] + ": incorrect migration state")
require({d["id"] for d in manifest["policyDeltas"]} == {"MIG-NET", "MIG-REVERSAL", "MIG-APPROVAL", "MIG-BANK"}, "Migration supplemental decision coverage")
if errors:
    for error in errors:
        print("FAIL:", error)
    raise SystemExit(1)
print(f"PASS: {len(fixtures)} event fixtures, {len(negatives)} rejection fixtures; {len(requirement_ids)} requirements, {len(actual_operations)} operations, {len(acceptance_ids)} AT references, {screen_count} screens, {len(extensions)} contract supplements, {len(manifest['changes'])} migration changes.")
print("Payload-local checks only; no database, runtime API, broker, migration application or end-to-end test performed.")
