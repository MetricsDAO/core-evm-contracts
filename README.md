Core EVM Contracts
===============

Smart contracts and associated tooling for the Metrics DAO

Pre-Requisites
==============

* NodeJS 14 or higher

Setup
===============

1) Install dependencies

> `yarn install`

2) make a copy of `.secret.json.template` and name it `.secret.json`, and update your keys

```
cp .secret.json.template .secret.json
```

Running Tests
===============

1) Run Ganache-CLI in it's own terminal

> `npx ganache-cli`


2)  Execute unit tests

> `npx truffle test`


Active Development
===============

1) Compile the contracts

> `npx truffle compile`

2) Deploy to Ganache

> `npx truffle migrate`
