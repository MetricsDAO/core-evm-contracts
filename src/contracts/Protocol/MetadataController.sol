//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@tableland/evm/contracts/ITablelandTables.sol";

// Modifiers
import "./modifiers/OnlyAPI.sol";

contract MetadataController is Ownable, OnlyApi {
    ITablelandTables private _tableland;

    uint256 private _tableId;

    //------------------------------------------------------ CONSTRUCTOR

    constructor(address tableland) {
        _tableland = ITablelandTables(tableland);

        _tableId = _tableland.createTable(address(this), "id int primary key, name text");
    }

    // ------------------------------------------------------ FUNCTIONS

    function writeToTableAndOtherStuff(uint256 id, string memory message) public payable {
        // INSERT INTO prefix_chainId_tableId (id, message) VALUES (id, message)
        _tableland.runSQL(
            address(this),
            _tableId,
            string.concat("INSERT INTO ", _tableId, " (id, message) VALUES (", Strings.toString(id), ", '", message, "')")
        );
        // Do other logic
    }
}
