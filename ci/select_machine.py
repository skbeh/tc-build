#!/usr/bin/env python3

import json
import sys

import requests


# Mostly core datacenters, ranked by latency from the maintainer's location
preferred_locations = (
    "sv15",
    "dfw2",
    "iad1",
    "ewr1",
    "nrt1",
    "ams1",
    "sin3",

    # Other facilities as fallbacks
    "am6",
    "ch3",
    "da11",
    "dc13",
    "fr2",
    "fra2",
    "hk2",
    "hkg1",
    "iad2",
    "la4",
    "lax1",
    "ld7",
    "mrs1",
    "ny5",
    "ny7",
    "pa4",
    "sea1",
    "sg1",
    "sjc1",
    "sl1",
    "sy4",
    "syd2",
    "tr2",
    "yyz1",
)

preferred_machines = (
    # (type, ondemand_price)
    ("m3.large.x86", 2),
    ("m2.xlarge.x86", 2),
    ("c2.medium.x86", 1),
    ("n2.xlarge.x86", 2.25),
    ("g2.large.x86", 5),
)

if len(sys.argv) > 1:
    token = sys.argv[1]
else:
    print("A Packet API token is required.")
    exit(1)

def check_locations(prices, max_price, locations):
    for loc in locations:
        # Not all machines are available in all locations
        if loc not in prices:
            continue

        # Intrinsic: $XX.01 == market full and request will not be fulfilled
        price_fract = prices[loc] - round(prices[loc])
        market_full = price_fract >= 0.0095 and price_fract <= 0.015

        if loc in prices and prices[loc] < max_price and not market_full:
            return loc, prices[loc]
    
    return (None, None)

def select_machine():
    for machine, ondemand_price in preferred_machines:
        with requests.get(f"https://api.packet.net/market/spot/prices?plan={machine}", headers={"X-Auth-Token": token}) as r:
            data = r.json()["spot_market_prices"]

        prices = {loc: list(matches.values())[0]["price"] for loc, matches in data.items()}
        # 10x == no spot market capacity available, but it's closer to 4x for g2.large (+ 0.01)
        max_price = ondemand_price * 4

        location, price = check_locations(prices, max_price, preferred_locations)
        if location:
            return {
                "type": machine,
                "location": location,
                "price": str(price * 1.2) # 20% margin to ensure we get enough time to run
                # Stringified because Terraform requires all external values to be strings
            }


result = select_machine()
if not result:
    print("No viable machines found!")
    exit(1)

print(json.dumps(result))
