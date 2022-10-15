# Docker Environment Instructions

## Prerequisites

Docker for desktop  
VS Code  
Dev Containers extension installed

Once the extension is installed  
Choose Command + Shift + P and type in open folder and type open folder and choose  
Devcontainers:Open folder in container choose core-evm  
you can also choose from bottom left hand screen green button and choose open folder in container This will open a new VS CODE window  
You'll notice you can directly work within the container and bottom green portion should say Dev container  
From here it should automatically install the necessary packages and run a hardhat node in vs code terminal  
Your deployment files should be created in deployments directory

## Consuming the contracts in your APP

1.  You can publish directly to NPM and have the app consume them
2.  You can publish them locally using a tool like Yalc and your seperate application can consume them automatically (Instructions below)

## Using Yalc with your dev container for local development

Create a directory on your mac in your home folder  
docker/volumes/yalc `mkdir -p ~/docker/volumes/yalc`  
In your devcontainer open a separate terminal and run

```
yalc publish --store-folder /yalc
```

The above command should publish your npm/yalc package to the host directory you created above  
You can change the directory if you wish in the devcontainer.json file under mounts

Now you can switch to the consumning application/repo and map core-evm-contracts to that package  
if you haven't already install yalc on your host machine  
`npm i yalc -g`  
and then link the package (dont forget to change you username - e.g. jamesdaly)

```
yalc link core-evm-contracts --store-folder /Users/${your-username}/docker/volumes2/yalc
```

the output should be something like
`Package core-evm-contracts@1.1.0 linked ==> /Users/jamesdaly/projects/xyz/node_modules/core-evm-contracts`

## Hardhat Docker Image/Container without using plugin

## Prerequisites

Docker for desktop

## WIP Not full functioning

Run the following commands
`docker build . -t hardhat-docker`
`docker run -it -d -p 8545:8545 --name hardhat-container hardhat-docker --mount type=bind, source=/Users/jamesdaly/docker/volumes2/yalc, target=/yalc`
