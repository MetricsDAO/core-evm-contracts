const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const { utils } = require("ethers");
const { mineBlocks, BN } = require("./utils");

describe("xMETRIC", async function () {
  let xMetric;

  let owner;
  let bob;
  let alice;
  let frank;
  let judy;
  let topChef;
  let topChefSigner;
  let signers;
  let questionAPI;
  let questionApiSigner;
  let bountyQuestion;
  let claimController;
  let questionStateController;
  let costController;

  const topChefAllocation = 100000;

  beforeEach(async function () {
    const provider = new ethers.providers.JsonRpcProvider();
    signers = await ethers.getSigners();
    // Set To TRUE as tests are based on hardhat.config
    await network.provider.send("evm_setAutomine", [true]);

    // deploy METRIC
    const xMetricContract = await ethers.getContractFactory("Xmetric");
    xMetric = await xMetricContract.deploy();

    [owner, bob, alice, judy, frank, topChefSigner] = signers;

    await xMetric.transfer(bob.address, BN(2000).div(10));
    await xMetric.transfer(judy.address, BN(topChefAllocation));

    // deploy Bounty Question
    const questionContract = await ethers.getContractFactory("BountyQuestion");
    bountyQuestion = await questionContract.deploy();

    // deploy Claim Controller
    const claimContract = await ethers.getContractFactory("ClaimController");
    claimController = await claimContract.deploy();

    // deploy State Controller
    const stateContract = await ethers.getContractFactory("QuestionStateController");
    questionStateController = await stateContract.deploy();

    // deploy Cost Controller
    const costContract = await ethers.getContractFactory("ActionCostController");
    costController = await costContract.deploy(xMetric.address);

    // deploy Factory
    const factoryContract = await ethers.getContractFactory("QuestionAPI");
    questionAPI = await factoryContract.deploy(
      xMetric.address,
      bountyQuestion.address,
      questionStateController.address,
      claimController.address,
      costController.address
    );

    signers.push(questionAPI);

    questionApiSigner = signers[20];

    // set factory to be owner
    await bountyQuestion.transferOwnership(questionAPI.address);
    await claimController.transferOwnership(questionAPI.address);
    await questionStateController.transferOwnership(questionAPI.address);
    await costController.transferOwnership(questionAPI.address);
  });

  it("should have the correct symbol and decimals and owner", async function () {
    expect(await xMetric.symbol()).to.equal("xMETRIC");
    expect(await xMetric.decimals()).to.equal(18);
    expect(await xMetric.owner()).to.equal(owner.address);
  });

  it("should send the right amount of tokens to Bob", async function () {
    const bobBalance = await xMetric.balanceOf(bob.address);
    expect(BN(bobBalance)).to.equal("200");
  });

  it("should get and set transactor privilages", async function () {
    const isTransactor = await xMetric.isTransactor(bob.address);
    expect(isTransactor).to.equal(false);

    await xMetric.setTransactor(alice.address, true);
    const isAliceTransactor = await xMetric.isTransactor(alice.address);
    expect(isAliceTransactor).to.equal(true);
  });

  it("should not let bob transfer as he is not a transactor", async function () {
    await expect(xMetric.connect(bob).transfer(alice.address, BN(2000).div(10))).to.be.revertedWith("AddressCannotTransact()");
  });

  it("should allow to pause and unpause contract", async function () {
    // test normal transaction
    await xMetric.transfer(alice.address, BN(5000).div(10));
    const aliceBalance = await xMetric.balanceOf(alice.address);
    expect(aliceBalance).to.equal("500");

    await xMetric.pause();
    await expect(xMetric.transfer(frank.address, BN(1000).div(10))).to.be.reverted;

    await xMetric.unPause();
    await xMetric.transfer(frank.address, BN(4000));
    const frankBalance = await xMetric.balanceOf(frank.address);
    expect(frankBalance).to.equal("4000");
  });

  it("should allow topChef to harvest to allocation groups", async function () {
    // set top chef to be transactor

    await xMetric.setTransactor(questionApiSigner.address, true);
    // await xMetric.setTransactor(topChefSigner.address, true);
    // judy can now approve top Chef
    await xMetric.connect(judy).approve(questionApiSigner.address, BN(topChefAllocation));

    // await xMetric.setTransactor(judy.address, true);

    // await xMetric.connect(judy).transferFrom(judy.address, questionAPI.address, BN(topChefAllocation));

    // await xMetric.setTransactor(judy.address, false);

    // const questionAPIBalance = await xMetric.balanceOf(questionAPI.address);
    // expect(questionAPIBalance).to.equal("100000");

    // await topChef.toggleRewards(true);
    // await topChef.addAllocationGroup(allocationGroup1.address, 1, true);

    // await mineBlocks(2);
    // await topChef.connect(allocationGroup1).claim(0);

    // const balance1 = await xMetric.balanceOf(allocationGroup1.address);
    // expect(balance1).to.equal(utils.parseEther("4"));
  });
});

// Can we set up a time next week and it's more of an ask of @Titus and @Addison as well to do an internal lunch and learn for writing tests in foundry we could invite others something very basic just sort of going over the lines of tests and how it works
