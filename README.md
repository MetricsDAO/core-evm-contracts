# Core EVM Contracts



## Getting Started

1.  install depedencies with:

```
yarn install
```

2.  make a copy of `.secret.json.template` and name it `.secret.json`, and update your keys

```
cp .secret.json.template .secret.json
```


3.  now you can run truffle commands using npx:

```
npx truffle compile
```



{% note %}

**Note:** the /build/ directory is on github *on purpose* even though it's annoying.  Build artifacts include deployment metadata when deploying.

{% endnote %}



## Development