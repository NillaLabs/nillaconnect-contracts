/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  networks: {
    hardhat: {
      forking: {
        url: 'https://mainnet.optimism.io',
      },
      chainId: 10
    }
  },
};
