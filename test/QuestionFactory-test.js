const { expect } = require("chai");
const { Certificate } = require("crypto");
const { utils } = require("ethers");
const { ethers } = require("hardhat");
const { mineBlocks, add, BN } = require("./utils");

describe("Question Factory Contract", function () {
  let questionFactory;
  let bountyQuestion;
  let claimController;
  let questionStateController;

  let owner;
  let addr1;
  let addrs;

  beforeEach(async function () {
    [owner, addr1, ...addrs] = await ethers.getSigners();

    // deploy Metric

    // deploy Bounty Question
    const questionContract = await ethers.getContractFactory("BountyQuestion");
    bountyQuestion = await questionContract.deploy();

    // deploy Claim Controller
    const claimContract = await ethers.getContractFactory("ClaimController");
    claimController = await claimContract.deploy();

    // deploy State Controller
    const stateContract = await ethers.getContractFactory("QuestionStateController");
    questionStateController = await stateContract.deploy();

    // deploy Factory
    const factoryContract = await ethers.getContractFactory("QuestionFactory");
    questionFactory = await factoryContract.deploy(bountyQuestion.address, questionStateController.address, claimController.address);

    // set factory to be owner
    await bountyQuestion.transferOwnership(questionFactory.address);
    await claimController.transferOwnership(questionFactory.address);
    await questionStateController.transferOwnership(questionFactory.address);
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      // sanity check permissions
      expect(await questionFactory.owner()).to.equal(owner.address);
      expect(await questionFactory.owner()).to.not.equal(addr1.address);
      expect(await bountyQuestion.owner()).to.equal(questionFactory.address);
      expect(await claimController.owner()).to.equal(questionFactory.address);
      expect(await questionStateController.owner()).to.equal(questionFactory.address);
    });
  });

  describe("Creating questions", function () {
    it("the factory should create questions", async function () {
      let questionBalance = await bountyQuestion.totalSupply();
      expect(questionBalance).to.equal(new BN(0));
      // create question
      await questionFactory.createQuestion("metricsdao.xyz", 10);

      // check that the question is created
      questionBalance = await bountyQuestion.totalSupply();
      expect(questionBalance).to.equal(new BN(1));
      const userBalance = await bountyQuestion.balanceOf(owner.address);
      expect(userBalance).to.equal(new BN(1));
    });

    it("the factory should setup Claim Controller when creating a question", async function () {
      // claim limit should be 0
      let claimLimit = await claimController.claimLimits(0);
      expect(claimLimit).to.equal(new BN(0));
      // no claims
      let claims = await claimController.getClaims(0);
      expect(claims.length).to.equal(new BN(0));

      // create question
      const limit = 10;
      await questionFactory.createQuestion("metricsdao.xyz", limit);

      // question state should now be draft
      claimLimit = await claimController.claimLimits(0);
      expect(claimLimit).to.equal(new BN(limit));

      // still no claims
      claims = await claimController.getClaims(0);
      expect(claims.length).to.equal(new BN(0));
    });

    it("the factory should setup State Controller when creating a question", async function () {
      // question state should be uninit
      let state = await questionStateController.state(0);
      expect(state).to.equal(new BN(0));
      // no votes
      let votes = await questionStateController.getVotes(0);
      expect(votes.length).to.equal(new BN(0));

      // create question
      await questionFactory.createQuestion("metricsdao.xyz", 10);

      // question state should now be draft
      state = await questionStateController.state(0);
      expect(state).to.equal(new BN(1));

      // still no votes
      votes = await questionStateController.getVotes(0);
      expect(votes.length).to.equal(new BN(0));
    });
  });
});
