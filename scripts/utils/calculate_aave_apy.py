from brownie import network, interface

network.priority_fee("2 gwei")

RAY = 10**27
SECONDS_PER_YEAR = 31536000

def main():
    asset = '0xdAC17F958D2ee523a2206206994597C13D831ec7' # USDT in V3
    pool = interface.IAaveLendingPool('0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2')
    [_, _, _, currentLiquidityRate, currentVariableBorrowRate, _, _,_, _, _, _, _] = pool.getReserveData(asset)
    depositAPR = currentLiquidityRate/RAY
    variableBorrowAPR = currentVariableBorrowRate/RAY
    stableBorrowAPR = currentVariableBorrowRate/RAY

    depositAPY = ((1 + (depositAPR / SECONDS_PER_YEAR)) ^ SECONDS_PER_YEAR) - 1
    variableBorrowAPY = ((1 + (variableBorrowAPR / SECONDS_PER_YEAR)) ^ SECONDS_PER_YEAR) - 1
    stableBorrowAPY = ((1 + (stableBorrowAPR / SECONDS_PER_YEAR)) ^ SECONDS_PER_YEAR) - 1

    print("Deposit APY:", depositAPY)
    print("Variable Borrow APY:", variableBorrowAPY)
    print("Stable Borrow APY:", stableBorrowAPY)
