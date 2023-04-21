## Testing

### Dependencies
- [foundry](https://book.getfoundry.sh/getting-started/installation)
- [brownie](https://eth-brownie.readthedocs.io/en/stable/install.html)
- [ganache](https://github.com/trufflesuite/ganache)

## Deploy Local (from root of the project)

1. Start Ganache mainnet-fork (with foundry mnemonic key)
```shell
ganache -f -m 'test test test test test test test test test test test junk' --chain.chainId 1
```

2. Fund USDC to your target account (run from another terminal)
```shell
brownie run scripts/utils/swap_eth_usdc.py
```

3. Deploy the smart contract
```shell
brownie run scripts/deploy_local.py
```
