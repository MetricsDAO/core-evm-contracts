//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IClaimController.sol";

contract ClaimController is Ownable, IClaimController {
    mapping(uint256 => uint256) private _claimLimit;
    mapping(uint256 => Claim[]) private _claims;

    //------------------------------------------------------ Structs

    struct Claim {
        address _claimer;
        Answer _answer;
    }

    struct Answer {
        address _author;
        string _url;
        // TODO grades, but what is a Grade?
        uint256 _finalGrade;
    }
}
