from brownie import network, interface, Contract, accounts
from brownie import OwnerTest
from dotenv import load_dotenv
from eth_account import Account
import os

load_dotenv()

network.max_fee("130 gwei")
network.priority_fee("6 gwei")

# network.priority_fee("2 gwei")
acc = Account.from_key(os.getenv("TEST_PRIVATE_KEY"))
accounts.add(acc.privateKey)
deployer = accounts[0]


def main():
    OwnerTest.publish_source(
        OwnerTest.at("0xb22B6fD7e3ec8c764CeC2BC5B3159a85d7b41C1B"), {"from": deployer}
    )
