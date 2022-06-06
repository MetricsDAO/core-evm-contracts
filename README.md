# MetricsDAO Core-EVM-Contracts

This repo contains the smart contracts for the Metrics DAO implementatin running on EVM-compatible blockchains.


## Vesting Design [WIP]

Vesting leverages block-height based distribution of $METRIC based on a share distribution.  This mechanism is layered and therefore abstracted - so while there is a Vesting Contract which handles the primary vesting schedule and distribution, the Vesting Contract will distribute tokens to the Rewards-Payout contract which will also need to handle vesting schedules and distrubtions to the various mechanims for rewards payouts.

The abstraction invovles two actors:

An `Allocator` can distribute tokens to an `Allocation Group (AG)` at regular intervals.


an Allocation Group is a struct:
{
address : Address 
shares : uint8
distribution: enum [pull/push]
}

an Allocator is a smart contract implementation with the following functionality:

1.  Add Allocation Group
2.  Remove Allocation Group
3.  Retrieve Current Pending token Distribution for Group (pull only)
4.  Trigger Distribution
    1. foreach AG, apply distribution method
5. Get Total Shares across all AG

That is not an inclusive list, and there will be permissioned accounts to manage access to functionality.

With that abstraction, oversimplified, we can:

1.  every block, tag X $metric as UNLOCKED within the Alloctor.  These need to be calculated on-demand, as the code will not be executed every block.

2.  then get that amount of UNLOCKED metric at a given time, and distribute amongst shareholders based on their shares/total shares -- if it's push distribution, send it also - if it's poll distribution, lock it up and let it stack.


---------
## Chef and Top Chef
Heavily Inspired by Sushi's MasterChefv2 - but with a few changes:  
- We don't have a v1, so we don't need that wrapping  
- We don't have two layers (pools and users), so the concept of pools is flattened into the contract itself.  
^^ This is because METRIC is the only token this will ever work with.  

Read this: https://dev.sushi.com/sushiswap/contracts/masterchefv2  
Also read this: https://soliditydeveloper.com/sushi-swap  

 In sushi's master chef, the design allows the controller to submit LP contracts for yield farming, and then user's can stake their LP tokens.

 In this contract, there is no concept of a user staking their LP tokens - and instead of LP contract, the controller is submitting Allocation Groups.

So in sushi:  

1.  Every `x` blocks, calculate minted Sushi Tokens for each LP contract based on their (shares / total shares)
2.  Then, do the math to figure out how many rewards each LP token is worth (based on the total amount of LP tokens staked)
3.  Then, when a user requests their rewards, their claimable amount is based on how many tokens they have staked - and from the previous step, we know how many rewards each LP token gets.
4.  Historical withdrawals are tracked through "rewardDebt" - so subtract the amount of rewards they have already claimed from their total earned rewards.


This contract is a bit more simplified.  Basically there are no LP tokens - so those values are tracked at the top level.  

1.  whenever updateAccumulatedAllocations() is called, we look at how many blocks it's been since the last time it called and multiply that by the `METRIC_PER_BLOCK` value.
2.  Then we use that value to determine how much each current "share" is going to be earning, and save that as `_lifetimeShareValue`
3.  Then, when an Allocation Group calls Harvest, we figure out how much they've earned based on the `_lifetimeShareValue` and their current allocation.
4.  We track historical harvests through "debt" - an AG's Debt is how much they've already harvested, so we subtract that from their lifetime earned rewards to get current earned rewards.

- OR, Same thing different lens - 

1.  Every `x` blocks, calculate  METRIC Tokens for each AG based on their (shares / total shares)
2.  Then, do the math to figure out how many METRIC tokens will be distributed in total
3.  Then, when a user requests their rewards, their claimable amount is based on how many shares they have - and from the previous step, we know how many rewards each AG group gets.
4.  Historical withdrawals are tracked through "rewardDebt" - so subtract the amount of rewards they have already claimed from their total earned rewards.  

---------
# Project Setup
This project utilizes two of the popular smart contract development frameworks:
1. [Hardhat](https://hardhat.org/getting-started/) 
2. [Foundry](https://book.getfoundry.sh/index.html)

Why two frameworks?
Given how early we are (we know), some frameworks have significant strengths and significant weaknesses or gaps.

Hardhat is easier for developers from JS backgrounds to get up to speed and offers a wide set of plugins and tools.

Foundry is popular amongst smart contract devs for prioritizing solidity and allows devs to write tests in Solidity, which makes it easier to comprehensively test the projects contracts.

### How to get set up

#### Install Foundry on your machine
[Full Guide](https://book.getfoundry.sh/getting-started/installation.html)

Linux/Mac Users

```
curl -L https://foundry.paradigm.xyz | bash
```

Then run the following command

```
foundryup
```

#### Install project dependencies

(install npm if you haven't already)

Run the command below to install hardhat dependencies AND foundry dependencies

The foundry directory is titled `contracts` and some configuration has been done to allow hardhat and foundry to use the same contract files.
```
npm run setup

```

## Foundry

Foundry has a [cute guide](https://book.getfoundry.sh/index.html) that will help any questions, just remember that foundry specific commands like `forge test` will need to be run from within the `contracts/` directory.

## Hardhat

### Hardhat for deployments
We utilize a hardhat library called [hardhat deploy](https://github.com/wighawag/hardhat-deploy) to help us deploy and organize our deployments across test/prod networks.

You can run the base deployment to a test network with this command `npx hardhat deploy --network ropsten`

```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
npx hardhat help
REPORT_GAS=true npx hardhat test
npx hardhat coverage
npx hardhat run scripts/deploy.ts
TS_NODE_FILES=true npx ts-node scripts/deploy.ts
npx eslint '**/*.{js,ts}'
npx eslint '**/*.{js,ts}' --fix
npx prettier '**/*.{json,sol,md}' --check
npx prettier '**/*.{json,sol,md}' --write
npx solhint 'contracts/**/*.sol'
npx solhint 'contracts/**/*.sol' --fix
```

## Etherscan verification

To try out Etherscan verification, you first need to deploy a contract to an Ethereum network that's supported by Etherscan, such as Ropsten.

In this project, copy the .env.example file to a file named .env, and then edit it to fill in the details. Enter your Etherscan API key, your Ropsten node URL (eg from Alchemy), and the private key of the account which will send the deployment transaction. With a valid .env file in place, first deploy your contract:

```shell
hardhat run --network ropsten scripts/deploy.ts
```

Then, copy the deployment address and paste it in to replace `DEPLOYED_CONTRACT_ADDRESS` in this command:

```shell
npx hardhat verify --network ropsten DEPLOYED_CONTRACT_ADDRESS "Hello, Hardhat!"
```

## Performance optimizations

For faster runs of your tests and scripts, consider skipping ts-node's type checking by setting the environment variable `TS_NODE_TRANSPILE_ONLY` to `1` in hardhat's environment. For more details see [the documentation](https://hardhat.org/guides/typescript.html#performance-optimizations).
