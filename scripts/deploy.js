// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const axios = require("axios");
const { ethers, upgrades } = require("hardhat");

const gasUrls = {
  polygon:  'https://gasstation.polygon.technology/v2', // Polygon Pos Mainet
  mumbai: 'https://gasstation-testnet.polygon.technology/v2' // Polygon Mumbai
}

const getFeeOption = async () => {
  const data =  (await axios(gasUrls[hre.network.name])).data
  return {
    maxFeePerGas: ethers.parseUnits(Math.ceil(data.fast.maxFee).toString(), 'gwei'),
    maxPriorityFeePerGas: ethers.parseUnits(Math.ceil(data.fast.maxPriorityFee).toString(), 'gwei')
  }
}

//wait for n blocks
const waitBlocks = async (n) => {
  const provider = ethers.provider;
  const currentBlock = await provider.getBlockNumber()
  const targetBlock = currentBlock + n
  return new Promise((resolve, reject) => {
    provider.on("block", (blockNumber) => {
      console.log("blockNumber: ", blockNumber)
      if (blockNumber == targetBlock) {
        provider.removeAllListeners("block");
        resolve();
      }
    })
  })
}

async function main() {
  Contract = await ethers.getContractFactory("Membership");
  Contract.runner.provider.getFeeData = async () => await getFeeOption()
  const [signer] = await ethers.getSigners();
  signer.provider.getFeeData = async () => await getFeeOption();
  Contract.connect(signer);

  //beacon proxy
  console.log('network: ', hre.network.name);
  const beacon = await upgrades.deployBeacon(Contract);
  await beacon.waitForDeployment();
  console.log('beacon contract deployed at ', await beacon.getAddress());
  const proxy = await upgrades.deployBeaconProxy(beacon, Contract, []);
  await proxy.waitForDeployment();
  console.log('proxy contract deployed at ', await proxy.getAddress());
  const implementation = await beacon.implementation()
  console.log('implementation contract deployed at ', implementation);
  await waitBlocks(5)
  if (hre.network.name != 'hardhat') {
    await hre.run("verify:verify", { address: implementation });
  }

}

async function upgrade(beaconAddr, proxyAddr) {
  const ContractV2 = await ethers.getContractFactory("MembershipV2");
  const beacon = await upgrades.upgradeBeacon(beaconAddr, ContractV2);
  const contract2 = ContractV2.attach(proxyAddr);
  console.log('New implementation address is ', await beacon.implementation());h
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

//npx hh run scripts/deploy.js --network mumbai


