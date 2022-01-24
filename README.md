Core EVM Contracts
===============

Smart contracts and associated tooling for the Metrics DAO

Pre-Requisites
==============

* NodeJS 14 or higher
* [Ganache](http://trufflesuite.com/docs/ganache/quickstart)
    * Make sure you have a high enough gas price/limit ceiling in your Ganache workspace!
* Istanbul (or higher) Hard Fork config on Ganache

Getting Started
===============

1) Install dependencies

> `yarn install`

2) make a copy of `.secret.json.template` and name it `.secret.json`, and update your keys

```
cp .secret.json.template .secret.json
```

3) Compile the contracts

> `npx truffle compile`

4) Execute the unit tests

> `npx truffle test`

5) Deploy to Ganache

> `npx truffle migrate`
