const { ethers, deployments } = require("hardhat");

function BN(input) {
  return ethers.BigNumber.from(input);
}

async function mineBlocks(n) {
  for (let index = 0; index < n; index++) {
    await ethers.provider.send("evm_mine");
  }
}

const add = (first, second) => {
  const firstBig = ethers.BigNumber.from(first.toString());
  const secondBig = ethers.BigNumber.from(second.toString());
  return ethers.BigNumber.from(firstBig.add(secondBig));
};

const closeEnough = (first, second) => {
  return Math.abs(first - second) < 1e-13;
};

const getContract = async (name) => {
  const deployment = await deployments.get(name);
  return await ethers.getContractAt(name, deployment.address);
};

module.exports = {
  add,
  BN,
  mineBlocks,
  closeEnough,
  getContract,
};
