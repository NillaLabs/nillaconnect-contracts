from brownie import network, interface

network.priority_fee("2 gwei")

RAY = 10**27
SECONDS_PER_YEAR = 31536000

def main():
    asset = '0x6B175474E89094C44Da98b954EedeAC495271d0F' # DAI in V3
    pool = interface.IAaveLendingPool('0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2')
    [_, _, currentLiquidityRate, _, _, _, _,_, _, _, _, _, _, _, _] = pool.getReserveData(asset)
    depositAPR = currentLiquidityRate / RAY
    depositAPY = ((1 + (depositAPR / SECONDS_PER_YEAR)) ** SECONDS_PER_YEAR) - 1
    print("Deposit APY:", round(depositAPY * 100, 2))
