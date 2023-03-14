/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  networks: {
    hardhat: {
      forking: {
        url: 'https://mainnet.infura.io/v3/ffbc1eb152204fc6bfdc7fe1ca90d09a',
      },
      chainId: 1
    }
  },
};
