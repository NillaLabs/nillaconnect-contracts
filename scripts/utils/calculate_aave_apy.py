import json

from brownie import network, interface
from brownie import AaveV2NillaLendingPool, ProxyAdminImpl, TransparentUpgradeableProxyImpl

from scripts.utils.utils import encode_function_data

network.priority_fee("2 gwei")
f_address = open('./scripts/constants/address.json',)

data_address = json.load(f_address)

deployer = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" # NOTE: Change address later
a_token = data_address['1']['AAVEV2_ATOKEN']["usdt".upper()]

impl = AaveV2NillaLendingPool.deploy({'from': deployer})
admin = ProxyAdminImpl.deploy({'from': deployer})

aave_v2_initilize_encoded = encode_function_data(
    impl.initialize,
    a_token,
    "WETH AAVE V2 LP",
    "naWETH",
    3,
    3
)

nilla = TransparentUpgradeableProxyImpl.deploy(
    impl,
    admin,
    aave_v2_initilize_encoded,
    {'from': deployer}
)
lending_pool = nilla.lendingPool()
pool = interface.IAaveLendingPool(lending_pool.address)
print(pool.getReserveData(a_token))
