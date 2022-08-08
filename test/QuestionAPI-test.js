const { expect } = require("chai");
const { ethers, network, deployments } = require("hardhat");
const { utils } = require("ethers");
const { BN, getContract } = require("./utils");

describe.only("Question API Contract", function () {
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
    // const VaultContract = await ethers.getContractFactory("Vault");
    // vault = await VaultContract.deploy(xmetric.address, questionStateController.address, treasury.address);

    // deploy Cost Controller
    costController = await getContract("ActionCostController");
    // const costContract = await ethers.getContractFactory("ActionCostController");
    // costController = await costContract.deploy(xmetric.address, vault.address);

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
      const state = await questionStateController.getState(0);
      expect(state).to.equal(new BN(0));

      await metricToken.connect(xmetricaddr1).approve(vault.address, ethers.utils.parseEther("10"));

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
      let votes = await questionStateController.getTotalVotes(0);
      expect(votes).to.equal(new BN(0));
      // // create question
      await metricToken.connect(xmetricaddr1).approve(vault.address, ethers.utils.parseEther("10"));
      await metricToken.connect(xmetricaddr2).approve(vault.address, ethers.utils.parseEther("10"));

      const questionIDtx = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz", 5);
      await questionIDtx.wait();
      // // question state should now be VOTING state
      const authorWithSeveralQuestions = await bountyQuestion.getAuthor(xmetricaddr1.address);

      const latestQuestionID = authorWithSeveralQuestions[authorWithSeveralQuestions.length - 1].tokenId;

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
      totalVotesForQuestion = await questionStateController.getTotalVotes(latestQuestionID);
      expect(totalVotesForQuestion).to.equal(1);
    });

    it("should set up a new mapping and a getter when initializing question in questionCostController", async () => {
      await metricToken.connect(xmetricaddr1).approve(vault.address, ethers.utils.parseEther("10"));

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
      await metricToken.connect(xmetricaddr1).approve(vault.address, ethers.utils.parseEther("30"));
      await metricToken.connect(xmetricaddr2).approve(vault.address, ethers.utils.parseEther("30"));
      await metricToken.connect(xmetricaddr3).approve(vault.address, ethers.utils.parseEther("30"));

      const questionIDtx = await questionAPI.connect(xmetricaddr1).createQuestion("metricsdao.xyz", 25);

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
