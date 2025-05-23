// const { ethers } = require("hardhat");

// async function main() {
//   console.log("Deploying contract...");

//   const [deployer] = await ethers.getSigners();
//   console.log("Deployer address:", deployer.address);

//   const Healthcare = await ethers.getContractFactory("Healthcare");
//   const healthcare = await Healthcare.deploy();

//   await healthcare.waitForDeployment(); // dùng cho ethers v6+

//   const address = await healthcare.getAddress(); // ethers v6+
//   console.log("Contract address:", address);
// }

// main().catch((error) => {
//   console.error(error);
//   process.exitCode = 1;
// });
const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying contract...");

  const [deployer] = await ethers.getSigners();
  console.log("Deployer address:", deployer.address);

  const Healthcare = await ethers.getContractFactory("Healthcare");
  const healthcare = await Healthcare.deploy();

  await healthcare.waitForDeployment();

  const address = await healthcare.getAddress();
  console.log("Contract address:", address);

  // Gọi getUser cho chính deployer (admin mặc định)
  const user = await healthcare.getUser(deployer.address);
  console.log("User info:");
  console.log("Full Name:", user[0]);
  console.log("Email:", user[1]);
  console.log("Role:", user[2]);        // enum Role: 0 = NONE, 1 = PATIENT, 2 = DOCTOR, 3 = ADMIN
  console.log("Is Verified:", user[3]);
  console.log("IPFS Hash:", user[4]);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
