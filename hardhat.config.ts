import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";

dotenv.config();

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

const deployerKey = process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [];

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000
          }
        },
      },
    ],
  },
  networks: {
    mainnet: {
      url: process.env.MAINET_URL || "",
      chainId: 1,
      accounts: deployerKey,
    },
    goerli: {
      url: process.env.GOERLI_URL || "",
      chainId: 5,
      accounts: deployerKey,
      gasPrice: 5000000000
    },
    bsc: {
      url: process.env.BSC_URL || "",
      chainId: 56,
      accounts: deployerKey,
    },
    bsctest: {
      url: process.env.BSCTEST_URL || "",
      chainId: 97,
      accounts: deployerKey,
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: {
      mainnet: "22IKRNZQHZYMSZVQ51FVFYV6323NXIHK85",
      goerli: "22IKRNZQHZYMSZVQ51FVFYV6323NXIHK85",
      bsc: "JKZU6KYRFPF7NTRAJAFGADBPSBUTI1MR3M",
      bscTestnet: "JKZU6KYRFPF7NTRAJAFGADBPSBUTI1MR3M",
    },
  }
};

export default config;