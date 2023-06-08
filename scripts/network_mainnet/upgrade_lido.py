import json
import os
from dotenv import load_dotenv
from eth_account import Account
from brownie import accounts
from brownie import (
    ProxyAdminImpl,
    LidoNillaLiquidityStaking,
)
from scripts.utils.utils import *

network.max_fee("36 gwei")
network.priority_fee("1 gwei")

load_dotenv()

deployer = Account.from_mnemonic(os.getenv("MNEMONIC"))  # NOTE: Change address later
accounts.add(deployer.privateKey)
deployer = accounts[0]
# deployer = "0x2C8F69a861eD3C6cB8548a3eD9971CF971E05C31"

nstETH = "0x7a8Cf63aAf9c78cF71C1A5ba4B2e42349Ac3dAAD"
lido_address = "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84"


def main():
    impl = LidoNillaLiquidityStaking.deploy(
        lido_address, {"from": deployer}, publish_source=True
    )

    admin = ProxyAdminImpl.at("0x23fd7cC7799c2Ab48B670f712636cA97D0b47723")
    # nilla = LidoNillaLiquidityStaking.at(nstETH)

    # st_eth = nilla.stETH()
    # decimals = nilla.decimals()
    # reserves = nilla.reserves(lido_address)
    # deposit_fee = nilla.depositFeeBPS()
    # withdraw_fee = nilla.withdrawFeeBPS()
    # performance_fee = nilla.performanceFeeBPS()
    # worker = nilla.worker()
    # swapRouter = nilla.swapRouter()

    # print("Decimals from proxy:", decimals)

    admin.upgrade(nstETH, impl, {"from": deployer})

    # print("New Decimals:", nilla.decimals())

    # assert st_eth == nilla.stETH()
    # assert decimals == 0
    # assert nilla.decimals() == 18
    # assert reserves == nilla.reserves(lido_address)
    # assert deposit_fee == nilla.depositFeeBPS()
    # assert withdraw_fee == nilla.withdrawFeeBPS()
    # assert performance_fee == nilla.performanceFeeBPS()
    # assert worker == nilla.worker()
    # assert swapRouter == nilla.swapRouter()

    # print("TEST PASSED")
