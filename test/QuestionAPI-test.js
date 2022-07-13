const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const { utils } = require("ethers");
const { BN } = require("./utils");

describe("Question API Contract", function () {
  let metric;
  let xmetric;
  let questionAPI;
  let bountyQuestion;
  let claimController;
  let questionStateController;
  let costController;

  let owner;
  let metricaddr1;
  let xmetricaddr1;
  let addrs;

  beforeEach(async function () {
    [owner, metricaddr1, xmetricaddr1, ...addrs] = await ethers.getSigners();
    await network.provider.send("evm_setAutomine", [true]);

    // deploy Metric
    const metricContract = await ethers.getContractFactory("MetricToken");
    metric = await metricContract.deploy();

    // deploy Xmetric XMETRIC
    const xmetricContract = await ethers.getContractFactory("Xmetric");
    xmetric = await xmetricContract.deploy();

    // deploy Bounty Question
    const questionContract = await ethers.getContractFactory("BountyQuestion");
    bountyQuestion = await questionContract.deploy();

    // deploy Claim Controller
    const claimContract = await ethers.getContractFactory("ClaimController");
    claimController = await claimContract.deploy();

    // deploy State Controller
    const stateContract = await ethers.getContractFactory("QuestionStateController");
    questionStateController = await stateContract.deploy();

    // deploy Cost Controller with xMetric
    const costContract = await ethers.getContractFactory("ActionCostController");
    costController = await costContract.deploy(xmetric.address);

    // deploy Factory
    const factoryContract = await ethers.getContractFactory("QuestionAPI");
    questionAPI = await factoryContract.deploy(
      bountyQuestion.address,
      questionStateController.address,
      claimController.address,
      costController.address
    );

    bountyQuestion.setQuestionApi(questionAPI.address);
    questionStateController.setQuestionApi(questionAPI.address);
    claimController.setQuestionApi(questionAPI.address);
    costController.setQuestionApi(questionAPI.address);

    await xmetric.setTransactor(costController.address, true);
    await xmetric.setTransactor(xmetricaddr1.address, true);
    await metric.transfer(metricaddr1.address, BN(2000));
    await xmetric.transfer(xmetricaddr1.address, utils.parseEther("3"));
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      // sanity check permissions
      expect(await questionAPI.owner()).to.equal(owner.address);
      expect(await questionAPI.owner()).to.not.equal(metricaddr1.address);

      const metricaddr1Balance = await metric.balanceOf(metricaddr1.address);
      const xmetricaddr1Balance = await xmetric.balanceOf(xmetricaddr1.address);

      expect(metricaddr1Balance).to.equal("2000");
      expect(xmetricaddr1Balance).to.equal("3000000000000000000");
    });
  });

  describe("Creating questions", function () {
    it("the factory should create questions", async function () {
      // create question

      await xmetric.connect(xmetricaddr1).approve(costController.address, utils.parseEther("3"));
      const questionIDtx = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz", 10);
      await questionIDtx.wait();

      const questionIDtx1 = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz", 10);
      await questionIDtx1.wait();

      const questionIDtx2 = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz", 10);
      await questionIDtx2.wait();

      const authorWithSeveralQuestions = await bountyQuestion.getAuthor(xmetricaddr1.address);
      expect(authorWithSeveralQuestions.length).to.equal(3);
      expect(authorWithSeveralQuestions[2]).to.equal(2);
    });

    // it("the factory should setup Claim Controller when creating a question", async function () {
    //   // claim limit should be 0
    //   let claimLimit = await claimController.claimLimits(0);
    //   expect(claimLimit).to.equal(new BN(0));
    //   // no claims
    //   let claims = await claimController.getClaims(0);
    //   expect(claims.length).to.equal(new BN(0));

    //   // create question
    //   const limit = 10;
    //   await questionAPI.createQuestion("metricsdao.xyz", limit);

    //   // question state should now be draft
    //   claimLimit = await claimController.claimLimits(0);
    //   expect(claimLimit).to.equal(new BN(limit));

    //   // still no claims
    //   claims = await claimController.getClaims(0);
    //   expect(claims.length).to.equal(new BN(0));
    // });

    // it("the factory should setup State Controller when creating a question", async function () {
    //   // question state should be uninit
    //   let state = await questionStateController.state(0);
    //   expect(state).to.equal(new BN(0));
    //   // no votes
    //   let votes = await questionStateController.getVotes(0);
    //   expect(votes.length).to.equal(new BN(0));

    //   // create question
    //   await questionAPI.createQuestion("metricsdao.xyz", 10);

    //   // question state should now be draft
    //   state = await questionStateController.state(0);
    //   expect(state).to.equal(new BN(1));

    //   // still no votes
    //   votes = await questionStateController.getVotes(0);
    //   expect(votes.length).to.equal(new BN(0));
    // });
  });
});
