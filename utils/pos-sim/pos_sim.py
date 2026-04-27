import argparse
import logging
import random
import sys
import time
from datetime import datetime, timezone

logging.basicConfig(
    stream=sys.stdout,
    level=logging.INFO,
    format="%(message)s",
)
logger = logging.getLogger("pos-sim")

PRODUCT_NAMES = [
    "Widget", "Gadget", "Gizmo", "Doohickey", "Thingamajig",
    "Sprocket", "Cog", "Bolt", "Nut", "Washer",
    "Cable", "Adapter", "Filter", "Sensor", "Module",
    "Pack", "Bundle", "Kit", "Set", "Unit",
]

PRODUCT_ADJECTIVES = [
    "Premium", "Standard", "Deluxe", "Basic", "Pro",
    "Ultra", "Lite", "Max", "Mini", "Plus",
]

# Invoice counter — monotonically increasing per process run
_invoice_counter = random.randint(100000, 999999)


def next_invoice() -> int:
    global _invoice_counter
    _invoice_counter += 1
    return _invoice_counter


def make_sku(sku_id: int) -> str:
    category = sku_id % 26
    return f"{chr(65 + category)}{sku_id:04d}"


def make_product_name(sku_id: int) -> str:
    adj = PRODUCT_ADJECTIVES[sku_id % len(PRODUCT_ADJECTIVES)]
    noun = PRODUCT_NAMES[sku_id % len(PRODUCT_NAMES)]
    return f"{adj} {noun}"


def generate_tlog_records(
    num_customers: int,
    num_skus: int,
    num_employees: int,
    num_stores: int,
) -> list[str]:
    """Return a CoPOS TLOG Header + Line record pair for one sale transaction."""
    now = datetime.now(timezone.utc)
    date_str = now.strftime("%m/%d/%Y")
    time_str = now.strftime("%-I:%M %p")   # e.g. 9:07 AM

    txn_type = random.choices(["S", "R"], weights=[92, 8])[0]  # mostly sales, some returns
    store_id = random.randint(1, num_stores)
    # 1-4 registers per store
    register_id = f"STR{store_id:03d}-REG{random.randint(1, 4):02d}"
    employee_id = f"{random.randint(1, num_employees):04d}"
    customer_id = random.randint(1, num_customers)
    sku_id = random.randint(1, num_skus)
    invoice = next_invoice()
    price = round(random.uniform(0.99, 499.99), 2)
    tax = round(price * 0.08, 2)
    total = round(price + tax, 2)
    tender = random.choices(["CASH", "CREDIT"], weights=[35, 65])[0]
    sku = make_sku(sku_id)
    product = make_product_name(sku_id)

    # sep = "\t"

    # # Header record: TxnType | H | RegisterID | Date | Time | EmployeeID | Invoice# | StoreID | CustomerID | Gross | Tax | Total | Tender
    # header = sep.join([
    #     txn_type, "H", register_id, date_str, time_str,
    #     employee_id, str(invoice),
    #     f"STR{store_id:03d}", f"CUST{customer_id:06d}",
    #     f"{price:.2f}", f"{tax:.2f}", f"{total:.2f}", tender,
    # ])

    # # Line record: TxnType | L | RegisterID | Date | Time | EmployeeID | Invoice# | SKU | ProductName | Qty | UnitPrice | Extension
    # line = sep.join([
    #     txn_type, "L", register_id, date_str, time_str,
    #     employee_id, str(invoice),
    #     sku, product, "1", f"{price:.2f}", f"{price:.2f}",
    # ])

    # return [header, line]

    return [f"[{now.isoformat()}] TXTYPE:{txn_type}, SKU:{sku}, CUST_ID:{customer_id}, EMPLY_ID:{employee_id}, REGISTR_ID:{register_id}, STOR_ID:{store_id}, PRICE:{price}, TAX:{tax}"]


def main():
    parser = argparse.ArgumentParser(description="Point-of-sale CoPOS TLOG simulator")
    parser.add_argument("--customers", type=int, default=10000, help="Number of unique customer IDs (default: 10000)")
    parser.add_argument("--skus", type=int, default=500, help="Number of unique SKUs (default: 500)")
    parser.add_argument("--employees", type=int, default=100, help="Number of unique employee IDs (default: 100)")
    parser.add_argument("--stores", type=int, default=10, help="Number of unique store IDs (default: 10)")
    parser.add_argument("--rate", type=float, default=1.0, help="Transactions per second (default: 1.0)")
    args = parser.parse_args()

    interval = 1.0 / args.rate if args.rate > 0 else 1.0

    while True:
        for record in generate_tlog_records(args.customers, args.skus, args.employees, args.stores):
            logger.info(record)
        time.sleep(interval)


if __name__ == "__main__":
    main()
