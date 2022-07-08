pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract onlyApi {
    address public questionApi;

    // ------------------------------- Setter
    /**
     * @notice Sets the address of the question API.
     * @param _newApi The new address of the question API.
     */
    function setQuestionApi(address _newApi) external onlyOwner {
        questionApi = _newApi;
    }

    // ------------------------ Modifiers
    modifier onlyApi() {
        if (msg.sender != questionApi) revert NotTheApi();
        _;
    }

    // ------------------------ Errors
    error NotTheApi();
}
