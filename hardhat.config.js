/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  networks: {
    hardhat: {
      forking: {
        url: 'https://endpoints.omniatech.io/v1/op/mainnet/public',
      },
      chainId: 10
    }
  },
};
