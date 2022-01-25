const { assert } = require("chai");
const MetricToken = artifacts.require("MetricToken");
const util = require("./TestUtil");

// Use .call when you care about the return value https://github.com/sc-forks/solidity-coverage/issues/146 
// Use .sendTransaction for non-view functions

contract('MetricToken', (accounts) => {
    describe("Advisor Mode", () => {

        it('should prevent accounts from transferring while advisor mode is on', async () => {
            const MetricTokenInstance = await MetricToken.deployed();

            // Make transaction from owner to account 1
            const amount = 100000;
            await util.seedAccounts(MetricTokenInstance, accounts, 1, amount);

            // Try to send from account 1 to account 2
            const firstAccount = accounts[1];
            const secondAccount = accounts[2];
            try{
                await MetricTokenInstance.transfer(secondAccount, amount, { from: firstAccount });
                assert.fail("Transfer should have failed!");
            }catch (error){
                assert.include(error.message, 'Only Admin Role can perform transfers during Advisor Mode');
            }

            // Get Account Balance of first and second accounts
            const firstBalance = await MetricTokenInstance.balanceOf.call(firstAccount);
            const secondBalance = await MetricTokenInstance.balanceOf.call(secondAccount);

            //ensure transfer did not go through
            assert.equal(firstBalance, amount, "Account 1 should not have sent tokens");
            assert.equal(secondBalance, 0, "Account 2 should not have receieved tokens");
            
        });

        it('should only allow owner to turn off advisor mode', async () => {
            const MetricTokenInstance = await MetricToken.deployed();

            //advisor mode should default to on
            const startingMode = await MetricTokenInstance.getAdvisorMode.call();
            assert.equal(startingMode, true, "Advisor mode should be on");

            //random account cannot disable advisor mode
            const firstAccount = accounts[1];
            try{
                await MetricTokenInstance.disableAdvisorMode({from: firstAccount });
                assert.fail("disableAdvisorMode should have failed!");
            }catch (error){
                assert.include(error.message, 'AccessControl');
            }

            //owner account can disable advisor mode
            const ownerAccount = accounts[0];
            disableTx = await MetricTokenInstance.disableAdvisorMode({ from: ownerAccount });

            //Ensure Event was fired
            log = util.getLatestEvent(disableTx);
            assert.equal(log.event, 'AdvisorModeOff');
            assert.equal(log.args.from.toString(), accounts[0].toString());
        
            //Ensure advisor mode is off 
            const endingMode = await MetricTokenInstance.getAdvisorMode.call();
            assert.equal(endingMode, false, "Advisor mode should be off");
        });

        it('should allow accounts to transfer when advisor mode is off', async () => {
            const MetricTokenInstance = await MetricToken.deployed();

            //owner account can disable advisor mode
            const ownerAccount = accounts[0];
            await MetricTokenInstance.disableAdvisorMode({ from: ownerAccount });

            // Make transaction from owner to account 1
            const amount = 100000;
            await util.seedAccounts(MetricTokenInstance, accounts, 1, amount);

            // Get starting balances of account 1 and account 2
            const firstAccount = accounts[1];
            const secondAccount = accounts[2];
            const firstAccountStartingBalance = (Number)(await MetricTokenInstance.balanceOf.call(firstAccount));
            const secondAccountStartingBalance = (Number)(await MetricTokenInstance.balanceOf.call(secondAccount));

            // Send from account 1 to account 2
            await MetricTokenInstance.transfer(secondAccount, amount, { from: firstAccount });
            
            // Get Account Balance of first and second accounts
            const firstAccountEndingBalance = await MetricTokenInstance.balanceOf.call(firstAccount);
            const secondAccountEndingBalance = await MetricTokenInstance.balanceOf.call(secondAccount);

            //ensure transfer did go through
            assert.equal(firstAccountEndingBalance, firstAccountStartingBalance - amount, "Account 1 should have sent tokens");
            assert.equal(secondAccountEndingBalance, secondAccountStartingBalance + amount, "Account 2 should have receieved tokens");
            
        });
    });
});
