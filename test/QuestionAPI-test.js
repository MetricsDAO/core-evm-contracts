const { expect } = require("chai");
const { ethers, network, deployments } = require("hardhat");
const { utils } = require("ethers");
const { BN, getContract } = require("./utils");

describe("Question API Contract", function () {
  let metricToken;
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

  const questionState = {
    UNINIT: 0,
    VOTING: 1,
    PENDING: 2,
    PUBLISHED: 3,
    DISQUALIFIED: 4,
    COMPLETED: 5,
  };

  const vaultStage = {
    CREATE_AND_VOTE: 0,
    UNVOTE: 1,
    CLAIM_AND_ANSWER: 2,
    RELEASE_CLAIM: 3,
    REVIEW: 4,
  };

  const actionCost = {
    CREATE: 0,
    VOTE: 1,
    CLAIM: 2,
    CHALLENGE_BURN: 3,
    CHALLENGE_CREATE: 4,
  };

  beforeEach(async function () {
    [owner, metricaddr1, xmetricaddr1, xmetricaddr2, xmetricaddr3] = await ethers.getSigners();
    // Set To TRUE as tests are based on hardhat.config
    await network.provider.send("evm_setAutomine", [true]);

    await deployments.fixture(["MVP1"]);

    // deploy Metric
    const whichMetric = process.env.metric === "metric" ? "MetricToken" : "Xmetric";
    metricToken = await getContract(whichMetric);

    // deploy Bounty Question
    bountyQuestion = await getContract("BountyQuestion");

    // deploy Claim Controller
    claimController = await getContract("ClaimController");

    // deploy State Controller
    questionStateController = await getContract("QuestionStateController");

    // deploy Vault
    vault = await getContract("Vault");

    // deploy Cost Controller
    costController = await getContract("ActionCostController");

    // deploy Question API
    questionAPI = await getContract("QuestionAPI");

    if (whichMetric === "Xmetric") {
      await metricToken.setTransactor(costController.address, true);
      await metricToken.setTransactor(vault.address, true);
    }
    await metricToken.transfer(metricaddr1.address, BN(2000));
    await metricToken.transfer(xmetricaddr2.address, utils.parseEther("20"));
    await metricToken.transfer(xmetricaddr3.address, utils.parseEther("1000")); // https://www.youtube.com/watch?v=oTZETtLCZZ0
    await metricToken.connect(xmetricaddr1).approve(vault.address, utils.parseEther("30"));
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      // sanity check permissions
      expect(await questionAPI.owner()).to.equal(owner.address);
      expect(await questionAPI.owner()).to.not.equal(metricaddr1.address);

      const metricaddr1Balance = await metricToken.balanceOf(metricaddr1.address);

      expect(metricaddr1Balance).to.equal("2000");
    });
  });

  describe("Creating questions", function () {
    it("the factory should create questions", async function () {
      // create question
      await metricToken.connect(xmetricaddr2).approve(vault.address, ethers.utils.parseEther("30"));

      const questionIDtx = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");
      await questionIDtx.wait();

      const questionIDtx1 = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");
      await questionIDtx1.wait();

      const questionIDtx2 = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");
      await questionIDtx2.wait();

      const authorWithSeveralQuestions = await bountyQuestion.getAuthor(xmetricaddr1.address);
      expect(authorWithSeveralQuestions.length).to.equal(3);
      expect(authorWithSeveralQuestions[2].questionId).to.equal(3);
    });

    it("the factory should setup State Controller when creating a question", async function () {
      // question state should be uninit
      const state = await questionStateController.getState(0);
      expect(state).to.equal(new BN(0));

      await metricToken.connect(xmetricaddr1).approve(vault.address, ethers.utils.parseEther("10"));

      const questionIDtx = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");
      await questionIDtx.wait();

      const questionIDtx2 = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");
      await questionIDtx2.wait();

      const authorWithSeveralQuestions = await bountyQuestion.getAuthor(xmetricaddr1.address);

      const latestQuestionID = authorWithSeveralQuestions[authorWithSeveralQuestions.length - 1].questionId;

      const questionStateLatestQuestion = await questionStateController.getState(latestQuestionID);
      expect(questionStateLatestQuestion).to.equal(new BN(questionState.VOTING));
    });

    it("the factory should enable voting once a question is created", async () => {
      // no votes
      let votes = await questionStateController.getTotalVotes(0);
      expect(votes).to.equal(new BN(0));
      // // create question
      await metricToken.connect(xmetricaddr1).approve(vault.address, ethers.utils.parseEther("10"));
      await metricToken.connect(xmetricaddr2).approve(vault.address, ethers.utils.parseEther("10"));

      const questionIDtx = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");
      await questionIDtx.wait();
      // // question state should now be VOTING state
      const authorWithSeveralQuestions = await bountyQuestion.getAuthor(xmetricaddr1.address);

      const latestQuestionID = authorWithSeveralQuestions[authorWithSeveralQuestions.length - 1].questionId;

      const questionStateLatestQuestion = await questionStateController.getState(latestQuestionID);
      expect(questionStateLatestQuestion).to.equal(new BN(questionState.VOTING));

      // still no votes
      votes = await questionStateController.getTotalVotes(0);
      expect(votes).to.equal(new BN(0));

      // address 2 votes with 1 xmetric
      await questionAPI.connect(xmetricaddr2).upvoteQuestion(latestQuestionID);

      // address 2 cant vote twice
      await expect(questionAPI.connect(xmetricaddr2).upvoteQuestion(latestQuestionID)).to.be.revertedWith("HasAlreadyVotedForQuestion()");

      const amountOfVotesArray = await questionStateController.getTotalVotes(latestQuestionID);
      const votersArray = await questionStateController.getVoters(latestQuestionID);
      expect(amountOfVotesArray).to.equal(2);
      expect(votersArray[0]).to.equal(xmetricaddr2.address);

      // unvoting
      await questionAPI.connect(xmetricaddr2).unvoteQuestion(latestQuestionID);
      const totalVotesForQuestion = await questionStateController.getTotalVotes(latestQuestionID);
      expect(totalVotesForQuestion).to.equal(1);
    });

    it("should set up a new mapping and a getter when initializing question in questionCostController", async () => {
      await metricToken.connect(xmetricaddr1).approve(vault.address, ethers.utils.parseEther("10"));

      const questionIDtx = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");
      await questionIDtx.wait();

      const questionIDtx1 = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");
      await questionIDtx1.wait();

      const questionIDtx2 = await questionAPI.connect(xmetricaddr1).callStatic.createQuestion("metricsdao.xyz");

      expect(questionIDtx2).to.equal(3);
    });

    it("should set up a new way to get all questions by state", async () => {
      await metricToken.connect(xmetricaddr1).approve(vault.address, ethers.utils.parseEther("30"));
      await metricToken.connect(xmetricaddr2).approve(vault.address, ethers.utils.parseEther("30"));
      await metricToken.connect(xmetricaddr3).approve(vault.address, ethers.utils.parseEther("30"));

      const questionIDtx = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");

      await questionIDtx.wait();

      const questionIDtx1 = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");
      await questionIDtx1.wait();

      const questionIDtxbad = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");
      await questionIDtxbad.wait();

      const questionIDtx2 = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");
      await questionIDtx2.wait();

      const authorWithSeveralQuestions = await bountyQuestion.getAuthor(xmetricaddr1.address);

      const latestQuestionID = authorWithSeveralQuestions[authorWithSeveralQuestions.length - 1].questionId;

      await questionAPI.connect(xmetricaddr3).upvoteQuestion(latestQuestionID);
      await questionAPI.connect(xmetricaddr2).upvoteQuestion(latestQuestionID);

      const latestQuestion = await bountyQuestion.getMostRecentQuestion();

      await questionAPI.disqualifyQuestion(new BN(3));

      const allquestionsByState = await questionStateController.getQuestionsByState(new BN(questionState.VOTING), latestQuestion, new BN(1000));

      expect(allquestionsByState[0].totalVotes).to.equal(3);
    });

    it("should get latest based on offset", async () => {
      const allquestionsbyLength = 8;
      const allquestionsbyLengthAgain = 5;

      const questionIDtx = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");
      await questionIDtx.wait();

      const questionIDtx1 = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");
      await questionIDtx1.wait();

      const questionIDtx2 = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");
      await questionIDtx2.wait();

      const questionIDtx3 = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");
      await questionIDtx3.wait();

      const questionIDtx4 = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");
      await questionIDtx4.wait();

      const questionIDtx5 = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");
      await questionIDtx5.wait();

      const questionIDtx6 = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");
      await questionIDtx6.wait();

      const questionIDtx7 = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");
      await questionIDtx7.wait();

      const latestQuestion = await bountyQuestion.getMostRecentQuestion();

      const allquestionsByState = await questionStateController.getQuestionsByState(new BN(questionState.VOTING), latestQuestion, new BN(1000));
      expect(allquestionsByState.length).to.equal(allquestionsbyLength);

      const allquestionsByStateAgain = await questionStateController.getQuestionsByState(new BN(questionState.VOTING), latestQuestion, new BN(4));
      expect(allquestionsByStateAgain.length).to.equal(allquestionsbyLengthAgain);
    });

    it("should enable unvoting and refund metric after a question has been upvoted", async () => {
      let tx = await costController.setActionCost(BN(actionCost.CREATE), utils.parseEther("1"));
      await tx.wait();

      tx = await costController.setActionCost(BN(actionCost.VOTE), utils.parseEther("1"));
      await tx.wait();

      await metricToken.transfer(xmetricaddr1.address, utils.parseEther("200"));

      const questionIDtx = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz");
      await questionIDtx.wait();

      const latestQuestion = await bountyQuestion.getMostRecentQuestion();
      await metricToken.connect(xmetricaddr2).approve(vault.address, utils.parseEther("30"));
      await questionAPI.connect(xmetricaddr2).upvoteQuestion(latestQuestion);

      const balance = await metricToken.balanceOf(xmetricaddr2.address);
      expect(balance).to.equal(utils.parseEther("19"));

      await questionAPI.connect(xmetricaddr2).unvoteQuestion(latestQuestion);

      const balanceTwo = await metricToken.balanceOf(xmetricaddr2.address);
      expect(balanceTwo).to.equal(utils.parseEther("20"));
    });

    it("should allow you to publish a question", async () => {
      let tx = await costController.setActionCost(BN(actionCost.CREATE), utils.parseEther("1"));
      await tx.wait();

      tx = await costController.setActionCost(BN(actionCost.VOTE), utils.parseEther("1"));
      await tx.wait();

      await metricToken.transfer(xmetricaddr1.address, utils.parseEther("200"));

      const PseudoAuthNFT = await ethers.getContractFactory("PseudoAuthNFT");
      const mockNFT = await PseudoAuthNFT.deploy("AuthAdmin", "AuthAdmin");

      const ADMIN_ROLE = utils.keccak256(utils.toUtf8Bytes("ADMIN_ROLE"));

      await questionAPI.addHolderRole(ADMIN_ROLE, mockNFT.address);

      await mockNFT.mintTo(xmetricaddr2.address);

      const questionIDtx = await questionAPI.connect(xmetricaddr1).createQuestion("ipfs//");
      await questionIDtx.wait();

      const latestQuestion = await bountyQuestion.getMostRecentQuestion();

      await questionAPI.connect(xmetricaddr2).publishQuestion(latestQuestion, BN(25), utils.parseEther("1"));

      const questionStateLatestQuestion = await questionStateController.getState(latestQuestion);
      expect(questionStateLatestQuestion).to.equal(questionState.PUBLISHED);
    });
  });

  describe("Challenges", () => {
    it("should bypass question creation and propose challenge to a pending state", async () => {
      await metricToken.transfer(xmetricaddr1.address, utils.parseEther("5000"));
      // Challenge Burn cost 1000 token
      await metricToken.connect(xmetricaddr1).approve(vault.address, utils.parseEther("1000"));
      const challengeTx = await questionAPI.connect(xmetricaddr1).proposeChallenge("QmZqHJRZRmPwFJ5MgqPVfKCtseUNspSUDJXbvgU5uBVpB3");
      await challengeTx.wait();

      const latestQuestion = await bountyQuestion.getMostRecentQuestion();
      expect(latestQuestion).to.equal(BN("1"));

      const balanceAfterQuestion = await metricToken.balanceOf(xmetricaddr1.address);
      expect(balanceAfterQuestion).to.equal(utils.parseEther("4000"));

      const questionStateLatestQuestion = await questionStateController.getState(latestQuestion);
      expect(questionStateLatestQuestion).to.equal(questionState.PENDING);
    });

    it("should allow gated program managers to publish a challenge into a published state ", async () => {
      const tx = await costController.setActionCost(BN(actionCost.CHALLENGE_CREATE), utils.parseEther("1"));
      await tx.wait();

      const PseudoAuthNFT = await ethers.getContractFactory("PseudoAuthNFT");
      const mockNFT = await PseudoAuthNFT.deploy("ProgramManager", "ProgramManager");

      const PROGRAM_MANAGER_ROLE = utils.keccak256(utils.toUtf8Bytes("PROGRAM_MANAGER_ROLE"));

      await questionAPI.addHolderRole(PROGRAM_MANAGER_ROLE, mockNFT.address);

      await mockNFT.mintTo(xmetricaddr2.address);

      await metricToken.connect(xmetricaddr2).approve(vault.address, utils.parseEther("1"));
      await questionAPI.connect(xmetricaddr2).createChallenge("QmZqHJRZRmPwFJ5MgqPVfKCtseUNspSUDJXbvgU5uBVpB3", BN(25), utils.parseEther("1"));

      const latestQuestion = await bountyQuestion.getMostRecentQuestion();
      expect(latestQuestion).to.equal(BN("1"));

      const balance = await metricToken.balanceOf(xmetricaddr2.address);
      console.log("balance", utils.formatEther(balance));

      const balanceAfterQuestion = await metricToken.balanceOf(xmetricaddr2.address);
      // Should not cost metric to create challenge
      expect(balanceAfterQuestion).to.equal(utils.parseEther("19"));

      const questionStateLatestQuestion = await questionStateController.getState(latestQuestion);
      expect(questionStateLatestQuestion).to.equal(questionState.PUBLISHED);
    });
  });
});
