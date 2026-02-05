// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Powers } from "../Powers.sol";
import { PowersTypes } from "../interfaces/PowersTypes.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { MandateUtilities } from "../libraries/MandateUtilities.sol";

/// @title Powers Factory
/// @notice Factory contract to deploy configured Powers instances.
/// @dev This factory manages a list of mandate initialization data used to constitute new Powers deployments.
/// @author 7Cedars
interface IPowersFactory is PowersTypes { 
    function addMandates(MandateInitData[] memory _mandateInitData) external;
    function replaceMandate(uint256 index, MandateInitData memory _mandateInitData) external;
    function getMandate(uint256 index) external view returns (MandateInitData memory);
    function createPowers() external returns (address);
    function getLatestDeployment() external view returns (address);
}

contract PowersFactory is IPowersFactory, Ownable {
    string public name;
    string public uri;
    MandateInitData[] public mandateInitData;
    uint256 public immutable maxCallDataLength;
    uint256 public immutable maxReturnDataLength;
    uint256 public immutable maxExecutionsLength;
    address public latestDeployment;

    /// @notice Initializes the factory with maximum limits for Powers contracts.
    /// @param _maxCallDataLength The maximum length of call data allowed in the Powers contract.
    /// @param _maxReturnDataLength The maximum length of return data allowed in the Powers contract.
    /// @param _maxExecutionsLength The maximum number of executions allowed in a single proposal.
    constructor(
        string memory _name,
        string memory _uri, 
        uint256 _maxCallDataLength,
        uint256 _maxReturnDataLength,
        uint256 _maxExecutionsLength
    ) Ownable(msg.sender) {
        // set immutable variables. note for now data not validated. 
        name = _name;
        uri = _uri;

        maxCallDataLength = _maxCallDataLength;
        maxReturnDataLength = _maxReturnDataLength;
        maxExecutionsLength = _maxExecutionsLength;
    }

    /// @notice Adds a list of mandates to the factory's storage.
    /// @dev Can only be called by the owner.
    /// @param _mandateInitData An array of MandateInitData structs to be added.
    function addMandates(MandateInitData[] memory _mandateInitData) external onlyOwner {
        for (uint256 i = 0; i < _mandateInitData.length; i++) {
            mandateInitData.push(_mandateInitData[i]);
        }
    }

    /// @notice Replaces a mandate at a specific index.
    /// @dev Can only be called by the owner.
    /// @param index The index of the mandate to replace.
    /// @param _mandateInitData The new MandateInitData struct.
    function replaceMandate(uint256 index, MandateInitData memory _mandateInitData) external onlyOwner {
        mandateInitData[index] = _mandateInitData;
    }

    /// @notice Retrieves a mandate at a specific index.
    /// @param index The index of the mandate to retrieve.
    /// @return The MandateInitData struct at the specified index.
    function getMandate(uint256 index) external view returns (MandateInitData memory) {
        return mandateInitData[index];
    } 

    /// @notice Deploys a new Powers contract and constitutes it with the stored mandates.
    /// @dev The newly deployed Powers contract becomes the admin of the deployed Powers contract.
    /// @return The address of the deployed Powers contract.
    function createPowers() external onlyOwner returns (address) {
        Powers powers = new Powers(name, uri, maxCallDataLength, maxReturnDataLength, maxExecutionsLength);

        powers.constitute(mandateInitData); // set the Powers address as the initial deployer and set as the admin!
        powers.closeConstitute(address(powers)); // admin set to the address that called the factory.

        latestDeployment = address(powers);

        return address(powers);
    }
    
    /// @notice Returns the address of the latest deployed Powers contract.
    /// @return The address of the latest deployment.
    function getLatestDeployment() external view returns (address) {
        return latestDeployment;
    }
}
