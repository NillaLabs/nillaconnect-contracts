import json
import os
from dotenv import load_dotenv
from eth_account import Account
from brownie import Contract, accounts
from brownie import ProxyAdminImpl, YearnNillaVault, TransparentUpgradeableProxyImpl
from scripts.utils.utils import *

# network.gas_price("2 gwei")
# network.max_fee("4 gwei")

load_dotenv()

CHAIN_ID = set_network("optimism")

f_address = open(
    "./scripts/constants/address.json",
)

data_address = json.load(f_address)

aave_v3_address = data_address[CHAIN_ID]["AAVEV3_ATOKEN"]
yearn_address = data_address[CHAIN_ID]["YEARN_VAULT"]

# deployer = Account.from_mnemonic(
#     os.getenv("MNEMONIC"))  # NOTE: Change address later
# accounts.add(deployer.privateKey)
deployer = "0xC022E7Ab9BED4874B7879d5Beaa6De5e12160Fae"
WETH = data_address[CHAIN_ID]["WETH"]
AAVE_V3_POOL = data_address[CHAIN_ID]["AAVEV3_POOL"]
YEARN_PARTNER_TRACKER = data_address[CHAIN_ID]["YEARN_PARTNER_TRACKER"]

DEPOSIT_FEE_BPS = 3
WITHDRAW_FEE_BPS = 3
PERFORMANCE_FEE_BPS = 500  # 5%

MULTISIG_WALLET = "0x6f650AE486eFc27BeEFb8Dc84000F63acA99735f"  # OP's

accounts[0].transfer(deployer, "10 ethers")


def main():
    impl = YearnNillaVault.deploy({"from": deployer})
    admin = ProxyAdminImpl.at("0x85774d5Fc82EDC9633624c009F0edfAD2DDebA1C")
    for nyv_token in [
        "0x676CF057e8e275df4FCFc5d72e6a334336C28069",
        "0x6d399C5BFd8a269a218CB3c4979D92dd9b801AC7",
        "0x64a487DA2eDB8cB63e9b0E032DB4184C76efeec5",
        "0xA7da71d3F65ecf86697b32dD8890d53EF49Be6F2",
        "0x6273359be3030E1b2E14E3937af1017D6974350c",
    ]:
        nilla = YearnNillaVault.at(nyv_token)
        partner = nilla.PARTNER_ADDRESS()
        yv_token = nilla.yvToken()
        tracker = nilla.yearnPartnerTracker()
        base_token = nilla.baseToken()
        decimals = nilla.decimals()
        reserves = nilla.reserves(yearn_address["USDC"])
        deposit_fee = nilla.depositFeeBPS()
        withdraw_fee = nilla.withdrawFeeBPS()
        worker = nilla.worker()

        admin.upgrade(nyv_token, impl, {"from": deployer})

        assert partner == nilla.PARTNER_ADDRESS()
        assert yv_token == nilla.yvToken()
        assert tracker == nilla.yearnPartnerTracker()
        assert base_token == nilla.baseToken()
        assert decimals == nilla.decimals()
        assert reserves == nilla.reserves(yearn_address["USDC"])
        assert deposit_fee == nilla.depositFeeBPS()
        assert withdraw_fee == nilla.withdrawFeeBPS()
        assert worker == nilla.worker()
        assert nilla.performanceFeeBPS() == 0
        assert nilla.principals(deployer) == 0

        nilla.setPerformanceFeeBPS(PERFORMANCE_FEE_BPS, {"from": deployer})
