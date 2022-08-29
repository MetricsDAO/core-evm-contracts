import json


def run(chainId: str) -> None:
    """
    Parse useful deployment information from foundry run-latest.json.
    """
    useful_info = {"time": "", "deployer": "", "deployed_contracts": {}}

    with open(f"../broadcast/Mdao.s.sol/{chainId}/run-latest.json", "r+") as f:
        run_latest = json.load(f)

    useful_info["time"] = run_latest["timestamp"]
    useful_info["deployer"] = run_latest["transactions"][0]["transaction"]["from"]

    for transaction in run_latest["transactions"]:
        if transaction["transactionType"] == "CREATE":
            with open(
                f"../out/{transaction['contractName']}.sol/{transaction['contractName']}.metadata.json",
                "r+",
            ) as f:
                metadata = json.load(f)

            useful_info["deployed_contracts"][transaction["contractName"]] = {
                "address": transaction["contractAddress"],
                "tx_hash": transaction["hash"],
                "abi": metadata["output"]["abi"],
            }

    with open(f"../broadcast/Mdao.s.sol/{chainId}/parsed_run-latest.json", "w+") as f:
        json.dump(useful_info, f, indent=2)
        print(
            f"Parsed run-latest.json for chainId {chainId} to core-evm-contracts/broadcast/Mdao.s.sol/{chainId}/parsed_run-latest.json"
        )


if __name__ == "__main__":
    # 31337 anvil
    # 1 eth mainnet
    # 137 polygon mainnet
    run(137)
