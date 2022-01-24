module.exports = {

    async seedAccounts(MetricTokenInstance, accounts, index, amount) {

        const ownerAccount = accounts[0];
        const account = accounts[index];

        await MetricTokenInstance.transfer(account, amount, { from: ownerAccount });
        return account;
    }
    
}
