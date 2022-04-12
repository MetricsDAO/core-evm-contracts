# Design


## Core Assumptions


1.  Supply is fixed at 1B
2.  Rewards will never end


## Vesting contract
1.  Need CRUD operations on adding address to contract
2.  “Vesting group”
3.  This will need to be approved by the multi-sig
4.  Set up gnosis safe, that address is owner of the vesting contract
    1.  That is the only one that can perform actions on the contract
    2.  Open Zeppelin “update allocation role” – this will be assigned to the gnosis safe address
5.  Send function
    1.  Support both claimable and auto-send (this state will be fixed in advance)
    2.  Claimable: individual/investors
    3.  Autosend: rewards contract, treasury (?)
6.  Read functions
    1.  Understand what’s been distributed, last claim, current state
7.  Should we use % or # to define how much should be distributed at any point in time?
    1.  Leaning towards %
8.   What’s the vesting mechanism for unlocking?
     1.   We will use block height as our time interval
     2.   This can be changed by the multisig if needed


## Rewards

1.  Sets up a walled garden to experiment with diff types / schedules of rewards
2. Allows us to have diff push/pull distributions
3. What goes out to faucet, staking etc is a % of what’s in rewards
4.  Reuse the same code as the vesting contract (makes the audit cheaper/easier)
5.  Payment splitter – uses shares: https://docs.openzeppelin.com/contracts/2.x/api/payment 
6.  Define addresses and their number of shares, have a payment function that distributes


### Faucet

1.  Want faucet to have a balance
2.  Needs to be replenished
3.  Cron job triggers distribution from rewards contract daily?


### Staking:
Staking vault
Use block height instead of time
Copy from MasterChef contract


## Question contract:
* Question Asker address
* State
* Votes {address, timestamp, Metric locked}
* Voter address
* Question copy URL
* ID of the program
* Created at
* Question ID
* Launch time duration
* Vote up
* getVotes()
