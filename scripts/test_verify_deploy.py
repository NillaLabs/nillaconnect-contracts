from brownie import network, interface, Contract, accounts
from brownie import OwnerTest
from dotenv import load_dotenv
from eth_account import Account
import os

load_dotenv()

network.priority_fee("2 gwei")

deployer = Account.from_key(os.getenv("TEST_PRIVATE_KEY"))
accounts.add(deployer.privateKey)
deployer = accounts[0]

OwnerTest.deploy({"from": deployer}, publish_source=True)
