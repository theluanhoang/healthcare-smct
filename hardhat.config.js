require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      outputSelection: {
        "*": {
          "*": ["evm.bytecode", "evm.deployedBytecode"],
        },
      },
      viaIR: true,
      evmVersion: "paris",
      metadata: {
        useLiteralContent: true,
        bytecodeHash: "none",
      },
    },
  },
  networks: {
    ganache: {
      url: "http://127.0.0.1:7545",
      accounts: [
        "0xc45cfeced46202990343c0906daf91d338e48fec6df502559882032fe663d316",
        "0x1aa250e9ccbe63b5799a3b3a29e9006b82319e44fe4e33969be67beb5ca9c3da",
        "0xab942166d4c2c2a8c61825de405e8c1a9b5185625ae667e441dab326bfef9b7a",
        "0xcf4618f180e3de3c35e7772311f58880d4e292fa7e06e501e98e5fce218ffd3b",
        "0x128ea18c2808feeca145e15822b2e96b4e5ef99dabce94489a73438e882ef51d", // USED
        "0x4c179dd9bb891049d687ed2980581a43c27954cd171b6ff462a80ff4d2336066",
        "0xb5ebf0c9b044c3b5e5c1cb3d12d773c529e8ae62a259cb3152d1ab3976dd0add",
        "0x113f2438b408bc457110454c22970f9c7cf258ef0f1f91a578d443e0f9eabae0",
        "0xfbd5506f0d7de6c124aaf7513c0b3c26796d5c478f0317963ca2bfb2f7c31de4",
        "0x35a625ab6032be12a5af8a3cb865399043a59109d050aad271d606fab98823e7"
      ]
    }
  }
};