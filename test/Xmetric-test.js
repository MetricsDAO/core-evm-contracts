const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const { BN } = require("./utils");

describe("xMETRIC", async function () {
  let xMetric;

  let owner;
  let bob;
  let alice;
  let frank;
  let judy;
  let treasury;
  let signers;
  let questionAPI;
  let bountyQuestion;
  let claimController;
  let questionStateController;
  let costController;

  const questionAPIAllocation = 100000;

  beforeEach(async function () {
    signers = await ethers.getSigners();
    // Set To TRUE as tests are based on hardhat.config
    await network.provider.send("evm_setAutomine", [true]);

    // deploy METRIC
    const xMetricContract = await ethers.getContractFactory("Xmetric");
    xMetric = await xMetricContract.deploy();

    [owner, bob, alice, judy, frank, treasury] = signers;

    await xMetric.transfer(bob.address, BN(2000).div(10));
    await xMetric.transfer(judy.address, BN(questionAPIAllocation));

    // deploy Bounty Question
    const questionContract = await ethers.getContractFactory("BountyQuestion");
    bountyQuestion = await questionContract.deploy();

    // deploy Claim Controller
    const claimContract = await ethers.getContractFactory("ClaimController");
    claimController = await claimContract.deploy();

    // deploy State Controller
    const stateContract = await ethers.getContractFactory("QuestionStateController");
    questionStateController = await stateContract.deploy();

    const VaultContract = await ethers.getContractFactory("Vault");
    const vault = await VaultContract.deploy(treasury.address);

    // deploy Cost Controller
    const costContract = await ethers.getContractFactory("ActionCostController");
    costController = await costContract.deploy(vault.address);

    // deploy Factory
    const factoryContract = await ethers.getContractFactory("QuestionAPI");
    questionAPI = await factoryContract.deploy(
      bountyQuestion.address,
      questionStateController.address,
      claimController.address,
      costController.address,
      xMetric.address,
      vault.address
    );
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

  it("should allow judy to approve Frank to transferFrom Judy to question api contract", async function () {
    // set frank to be transactor
    await xMetric.setTransactor(frank.address, true);
    // judy can now approve question api
    await xMetric.connect(judy).approve(frank.address, BN(questionAPIAllocation));

    await xMetric.connect(frank).transferFrom(judy.address, questionAPI.address, BN(questionAPIAllocation));

    const questionAPIBalance = await xMetric.balanceOf(questionAPI.address);
    expect(questionAPIBalance).to.equal("100000");
  });
});
