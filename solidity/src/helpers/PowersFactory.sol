// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Powers } from "../Powers.sol";
import { PowersTypes } from "../interfaces/PowersTypes.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { MandateUtilities } from "../libraries/MandateUtilities.sol";

/// @title Powers Factory
/// @notice Factory contract to deploy specific types of Powers implementations
/// @dev This factory deploys a _static_ list of init data for mandates to be used in each Powers deployment. As such, the deployments are not dynamic.
/// @author 7Cedars
interface IPowersFactory is PowersTypes { 
    function createPowers(string memory name, string memory uri) external returns (address);
    function getLatestDeployment() external view returns (address);
}

contract PowersFactory is IPowersFactory, Ownable {
    MandateInitData[] public mandateInitData;
    uint256 public immutable maxCallDataLength;
    uint256 public immutable maxReturnDataLength;
    uint256 public immutable maxExecutionsLength;
    address public latestDeployment;

    constructor( 
        uint256 _maxCallDataLength,
        uint256 _maxReturnDataLength,
        uint256 _maxExecutionsLength
    ) Ownable(msg.sender) {
        maxCallDataLength = _maxCallDataLength;
        maxReturnDataLength = _maxReturnDataLength;
        maxExecutionsLength = _maxExecutionsLength;
    }

    function setMandateInitData(MandateInitData[] memory _mandateInitData) external onlyOwner {
        delete mandateInitData;
        for (uint256 i = 0; i < _mandateInitData.length; i++) {
            mandateInitData.push(_mandateInitData[i]);
        }
    }

    function createPowers(string memory name, string memory uri) external onlyOwner returns (address) {
        Powers powers = new Powers(name, uri, maxCallDataLength, maxReturnDataLength, maxExecutionsLength);

        powers.constitute(mandateInitData); // set the Powers address as the initial deployer and set as the admin!
        powers.closeConstitute(msg.sender); 

        latestDeployment = address(powers);

        return address(powers);
    }

    function getLatestDeployment() external view returns (address) {
        return latestDeployment;
    }
}
