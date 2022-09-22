//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@tableland/evm/contracts/ITablelandTables.sol";

// Modifiers
import "./modifiers/OnlyAPI.sol";

contract MetadataController is Ownable, OnlyApi {
    using Strings for uint256;

    ITablelandTables private _tableland;

    uint256 private _tableId;
    string private _tableName;
    string private _tablePrefix = "metricsdao";

    //------------------------------------------------------ CONSTRUCTOR

    address private tableland_address = address(0); //0xDA8EA22d092307874f30A1F277D1388dca0BA97a;

    constructor() {
        if (tableland_address != address(0)) {
            _tableland = ITablelandTables(tableland_address);

            _tableId = _tableland.createTable(
                address(this),
                string.concat("CREATE TABLE ", _tablePrefix, "_", Strings.toString(block.chainid), " (id int primary key, message text);")
            );

            _tableName = string.concat(_tablePrefix, "_", Strings.toString(block.chainid), "_", Strings.toString(_tableId));
        }
    }

    // ------------------------------------------------------ FUNCTIONS

    function writeMetadata(uint256 id, string memory message) external {
        _tableland.runSQL(
            address(this),
            _tableId,
            string.concat("INSERT INTO ", _tableName, " (id, message) VALUES (", Strings.toString(id), ", '", message, "')")
        );
    }

    function getAllMetaData() public view returns (string memory) {
        string memory base = "https://testnet.tableland.network/query?s=";
        return string.concat(base, "SELECT%20*%20FROM%20", _tableName);
    }

    // function claimTableLandNFt() public {
    // TODO get NFT from tableland, and transfer it to somewhere so that we can re-use the same tableland nft
    // }
}
