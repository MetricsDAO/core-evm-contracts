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
    await metricToken.transfer(xmetricaddr3.address, utils.parseEther("1000"));
    await metricToken.connect(xmetricaddr1).approve(vault.address, utils.parseEther("30"));
  });

  describe("Vault", () => {
    it("should store funds in the vault", async () => {
      const tx = await costController.setActionCost(BN(actionCost.CREATE), utils.parseEther("1"));
      await tx.wait();

      await metricToken.transfer(xmetricaddr2.address, utils.parseEther("200"));
      await metricToken.connect(xmetricaddr2).approve(vault.address, utils.parseEther("1"));

      const questionIDtx = await questionAPI.connect(xmetricaddr2).createQuestion("ipfs//");
      await questionIDtx.wait();

      const vaultBalance = await vault.getMetricTotalLockedBalance();
      expect(vaultBalance).to.equal(utils.parseEther("1"));
    });

    it("should store funds in the vault", async () => {
      const tx = await costController.setActionCost(BN(actionCost.CREATE), utils.parseEther("1"));
      await tx.wait();

      await metricToken.transfer(xmetricaddr2.address, utils.parseEther("200"));
      await metricToken.connect(xmetricaddr2).approve(vault.address, utils.parseEther("1"));

      const questionIDtx = await questionAPI.connect(xmetricaddr2).createQuestion("ipfs//");
      await questionIDtx.wait();

      const vaultBalance = await vault.getMetricTotalLockedBalance();
      expect(vaultBalance).to.equal(utils.parseEther("1"));
    });
  });
});
