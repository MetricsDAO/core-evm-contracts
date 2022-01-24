const { assert } = require("chai");
const MetricToken = artifacts.require("MetricToken");
const util = require("./TestUtil");

// Use .call when you care about the return value https://github.com/sc-forks/solidity-coverage/issues/146 
// Use .sendTransaction for non-view functions

contract('MetricToken', (accounts) => {
    describe("Basic State Checks", () => {

        it('should put a billion MetricToken in the first account', async () => {
            const MetricTokenInstance = await MetricToken.deployed();
            
            // Get Owner Account Balance
            const balance = await MetricTokenInstance.balanceOf.call(accounts[0]);

            // Get number of decimals in Contract
            const decimals = await MetricTokenInstance.decimals.call()

            // We expect 1 Billion tokens
            const expected = 1000000000 * 10 ** decimals;
            assert.equal(balance, expected, "Inital mint wasn't in the first account");
        });

        it('should send coin correctly', async () => {
            const MetricTokenInstance = await MetricToken.deployed();

            // Get 2 accounts.
            const accountOne = accounts[0];
            const accountTwo = accounts[1];

            // Get initial balances of first and second account.
            const accountOneStartingBalance = (Number)(await MetricTokenInstance.balanceOf.call(accountOne));
            const accountTwoStartingBalance = (Number)(await MetricTokenInstance.balanceOf.call(accountTwo));

            // Make transaction from first account to second.
            const amount = 100000;
            util.seedAccounts(MetricTokenInstance, accounts, 1, amount);

            // Get balances of first and second account after the transactions.
            const accountOneEndingBalance = (Number)(await MetricTokenInstance.balanceOf.call(accountOne));
            const accountTwoEndingBalance = (Number)(await MetricTokenInstance.balanceOf.call(accountTwo));

            assert.equal(accountOneEndingBalance, accountOneStartingBalance - amount, "Amount wasn't correctly taken from the sender");
            assert.equal(accountTwoEndingBalance, accountTwoStartingBalance + amount, "Amount wasn't correctly sent to the receiver");
        });
    });
});
