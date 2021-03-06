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
  let vault;

  let owner;
  let metricaddr1;
  let xmetricaddr1;
  let xmetricaddr2;
  let xmetricaddr3;
  let treasury;
  let addrs;

  const questionState = {
    UNINIT: 0,
    VOTING: 1,
    PUBLISHED: 2,
    COMPLETED: 3,
    DISQUALIFIED: 4,
  };

  beforeEach(async function () {
    [owner, metricaddr1, xmetricaddr1, xmetricaddr2, xmetricaddr3, treasury, ...addrs] = await ethers.getSigners();
    // Set To TRUE as tests are based on hardhat.config
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

    const VaultContract = await ethers.getContractFactory("Vault");
    vault = await VaultContract.deploy(xmetric.address, questionStateController.address, treasury.address);

    // deploy Cost Controller
    const costContract = await ethers.getContractFactory("ActionCostController");
    costController = await costContract.deploy(xmetric.address, vault.address);

    await vault.setCostController(costController.address);

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
    await xmetric.setTransactor(vault.address, true);

    await xmetric.transfer(xmetricaddr2.address, utils.parseEther("20"));

    await xmetric.transfer(xmetricaddr3.address, utils.parseEther("1000")); // https://www.youtube.com/watch?v=oTZETtLCZZ0

    await metric.transfer(metricaddr1.address, BN(2000));
    await xmetric.transfer(xmetricaddr1.address, utils.parseEther("40"));
    await xmetric.connect(xmetricaddr1).approve(vault.address, utils.parseEther("30"));
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      // sanity check permissions
      expect(await questionAPI.owner()).to.equal(owner.address);
      expect(await questionAPI.owner()).to.not.equal(metricaddr1.address);

      const metricaddr1Balance = await metric.balanceOf(metricaddr1.address);
      const xmetricaddr1Balance = await xmetric.balanceOf(xmetricaddr1.address);

      expect(metricaddr1Balance).to.equal("2000");
      expect(xmetricaddr1Balance).to.equal("40000000000000000000");
    });
  });

  describe("Creating questions", function () {
    it("the factory should create questions", async function () {
      // create question
      await xmetric.connect(xmetricaddr1).approve(vault.address, ethers.utils.parseEther("30"));

      const questionIDtx = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz", 10);
      await questionIDtx.wait();

      const questionIDtx1 = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz", 10);
      await questionIDtx1.wait();

      const questionIDtx2 = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz", 10);
      await questionIDtx2.wait();

      const authorWithSeveralQuestions = await bountyQuestion.getAuthor(xmetricaddr1.address);
      expect(authorWithSeveralQuestions.length).to.equal(3);
      expect(authorWithSeveralQuestions[2].tokenId).to.equal(3);
    });

    it("the factory should setup Claim Controller when creating a question", async function () {
      // claim limit should be 0
      const claimLimits = await claimController.claimLimits(0);
      expect(claimLimits).to.equal(new BN(0));
      // no claims
      const claims = await claimController.getClaims(0);
      expect(claims.length).to.equal(new BN(0));

      // create question
      const limit = 10;

      const questionIDtx = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz", limit);
      await questionIDtx.wait();

      const authorWithQuestion = await bountyQuestion.getAuthor(xmetricaddr1.address);

      const claimlimit = await claimController.getClaimLimit(authorWithQuestion[authorWithQuestion.length - 1].tokenId);
      expect(claimlimit).to.equal(new BN(10));

      const claimLimitsAgain = await claimController.claimLimits(1); // 1 is the id
      expect(claimLimitsAgain).to.equal(BN(limit));
    });

    it("the factory should setup State Controller when creating a question", async function () {
      // question state should be uninit
      const state = await questionStateController.state(0);
      expect(state).to.equal(new BN(0));

      await xmetric.connect(xmetricaddr1).approve(vault.address, ethers.utils.parseEther("10"));

      const questionIDtx = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz", 5);
      await questionIDtx.wait();

      const questionIDtx2 = await questionAPI.connect(xmetricaddr1).createQuestion("ipfs://", 5);
      await questionIDtx2.wait();

      const authorWithSeveralQuestions = await bountyQuestion.getAuthor(xmetricaddr1.address);

      const latestQuestionID = authorWithSeveralQuestions[authorWithSeveralQuestions.length - 1].tokenId;

      const questionStateLatestQuestion = await questionStateController.getState(latestQuestionID);
      expect(questionStateLatestQuestion).to.equal(new BN(questionState.VOTING));
    });

    it("the facotry should enable voting once a question is created", async () => {
      // no votes
      let votes = await questionStateController.getVotes(0);
      expect(votes.length).to.equal(new BN(0));
      // // create question
      await xmetric.connect(xmetricaddr1).approve(vault.address, ethers.utils.parseEther("10"));

      const questionIDtx = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz", 5);
      await questionIDtx.wait();
      // // question state should now be VOTING state
      const authorWithSeveralQuestions = await bountyQuestion.getAuthor(xmetricaddr1.address);

      const latestQuestionID = authorWithSeveralQuestions[authorWithSeveralQuestions.length - 1].tokenId;

      const questionStateLatestQuestion = await questionStateController.getState(latestQuestionID);
      expect(questionStateLatestQuestion).to.equal(new BN(questionState.VOTING));

      // still no votes
      votes = await questionStateController.getVotes(0);
      expect(votes.length).to.equal(new BN(0));

      // address 2 votes with 1 xmetric
      await questionAPI.connect(xmetricaddr2).upvoteQuestion(latestQuestionID, utils.parseEther("1"));

      // address 2 cant vote twice
      await expect(questionAPI.connect(xmetricaddr2).upvoteQuestion(latestQuestionID, utils.parseEther("1"))).to.be.revertedWith(
        "HasAlreadyVotedForQuestion()"
      );

      let amountOfVotesArray = await questionStateController.getVotes(latestQuestionID);
      expect(amountOfVotesArray.length).to.equal(1);
      expect(amountOfVotesArray[0][0]).to.equal(xmetricaddr2.address);
      expect(amountOfVotesArray[0].voter).to.equal(xmetricaddr2.address);

      await questionAPI.connect(xmetricaddr3).upvoteQuestion(latestQuestionID, utils.parseEther("12"));
      let totalMetricForQuestion = await questionStateController.getTotalVotes(latestQuestionID);

      // lucky 13 - 12 + 1
      expect(totalMetricForQuestion).to.equal(utils.parseEther("13"));

      // unvoting
      await questionAPI.connect(xmetricaddr2).unvoteQuestion(latestQuestionID);
      totalMetricForQuestion = await questionStateController.getTotalVotes(latestQuestionID);
      expect(totalMetricForQuestion).to.equal(utils.parseEther("12"));

      amountOfVotesArray = await questionStateController.getVotes(latestQuestionID);
      // when user unvotes we just update value but don't remove entry from array
      expect(amountOfVotesArray.length).to.equal(2);
    });

    it("should set up a new mapping and a getter when initializing question in questionCostController", async () => {
      await xmetric.connect(xmetricaddr1).approve(vault.address, ethers.utils.parseEther("10"));

      const questionIDtx = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz", 5);
      await questionIDtx.wait();

      const questionIDtx1 = await questionAPI
        .connect(xmetricaddr1)
        .createQuestion("https://ipfs.io/ipfs/Qma89pKr7G8CpMeWa1rS7SRWLyqmyAheihoZMovQXkWoid", 5);
      await questionIDtx1.wait();

      const questionIDtx2 = await questionAPI.connect(xmetricaddr1).callStatic.createQuestion("ipfs://", 5);

      expect(questionIDtx2).to.equal(3);

    });

    it("should set up a new way to get all questions by state", async () => {
      const questionIDtx = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz", 5);
      await questionIDtx.wait();

      const questionIDtx1 = await questionAPI
        .connect(xmetricaddr1)
        .createQuestion("https://ipfs.io/ipfs/Qma89pKr7G8CpMeWa1rS7SRWLyqmyAheihoZMovQXkWoid", 5);
      await questionIDtx1.wait();

      const questionIDtxbad = await questionAPI.connect(xmetricaddr1).createQuestion("badquestion", 12);
      await questionIDtxbad.wait();

      const questionIDtx2 = await questionAPI.connect(xmetricaddr1).createQuestion("ipfs://", 5);
      await questionIDtx2.wait();

      const authorWithSeveralQuestions = await bountyQuestion.getAuthor(xmetricaddr1.address);

      const latestQuestionID = authorWithSeveralQuestions[authorWithSeveralQuestions.length - 1].tokenId;

      await questionAPI.connect(xmetricaddr3).upvoteQuestion(latestQuestionID, utils.parseEther("12"));
      await questionAPI.connect(xmetricaddr2).upvoteQuestion(latestQuestionID, utils.parseEther("7"));

      const latestQuestion = await bountyQuestion.getMostRecentQuestion();

      await questionAPI.disqualifyQuestion(new BN(3));

      const allquestionsByState = await questionStateController.getQuestionsByState(new BN(questionState.VOTING), latestQuestion, new BN(1000));

      expect(allquestionsByState[0].totalVotes).to.equal(utils.parseEther("19"));
    });

    it("should get latest based on offset", async () => {
      const allquestionsbyLength = 8;
      const allquestionsbyLengthAgain = 5;

      const questionIDtx = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz", 1);
      await questionIDtx.wait();

      const questionIDtx1 = await questionAPI
        .connect(xmetricaddr1)
        .createQuestion("https://ipfs.io/ipfs/Qma89pKr7G8CpMeWa1rS7SRWLyqmyAheihoZMovQXkWoid", 1);
      await questionIDtx1.wait();

      const questionIDtx2 = await questionAPI.connect(xmetricaddr1).createQuestion("ipfs://sixthtolast", 1);
      await questionIDtx2.wait();

      const questionIDtx3 = await questionAPI.connect(xmetricaddr1).createQuestion("ipfs://fifthtolast", 1);
      await questionIDtx3.wait();

      const questionIDtx4 = await questionAPI.connect(xmetricaddr1).createQuestion("ipfs://fourthtolast", 1);
      await questionIDtx4.wait();

      const questionIDtx5 = await questionAPI.connect(xmetricaddr1).createQuestion("ipfs://thirdtolast", 1);
      await questionIDtx5.wait();

      const questionIDtx6 = await questionAPI.connect(xmetricaddr1).createQuestion("ipfs://secondtoLast", 1);
      await questionIDtx6.wait();

      const questionIDtx7 = await questionAPI.connect(xmetricaddr1).createQuestion("ipfs://last", 1);
      await questionIDtx7.wait();

      const latestQuestion = await bountyQuestion.getMostRecentQuestion();

      const allquestionsByState = await questionStateController.getQuestionsByState(new BN(questionState.VOTING), latestQuestion, new BN(1000));
      expect(allquestionsByState.length).to.equal(allquestionsbyLength);

      const allquestionsByStateAgain = await questionStateController.getQuestionsByState(new BN(questionState.VOTING), latestQuestion, new BN(4));
      expect(allquestionsByStateAgain.length).to.equal(allquestionsbyLengthAgain);
    });
  });
});
