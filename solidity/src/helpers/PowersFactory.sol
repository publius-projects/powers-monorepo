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
    function createPowers(string memory name, string memory uri) external returns (address);
    function getLatestDeployment() external view returns (address);
}

contract PowersFactory is IPowersFactory, Ownable {
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
        uint256 _maxCallDataLength,
        uint256 _maxReturnDataLength,
        uint256 _maxExecutionsLength
    ) Ownable(msg.sender) {
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
    /// @dev The factory owner becomes the initial owner of the deployed Powers contract.
    /// @param name The name of the Powers contract.
    /// @param uri The URI for the Powers contract metadata.
    /// @return The address of the deployed Powers contract.
    function createPowers(string memory name, string memory uri) external onlyOwner returns (address) {
        Powers powers = new Powers(name, uri, maxCallDataLength, maxReturnDataLength, maxExecutionsLength);

        powers.constitute(mandateInitData); // set the Powers address as the initial deployer and set as the admin!
        powers.closeConstitute(msg.sender); 

        latestDeployment = address(powers);

        return address(powers);
    }

    /// @notice Returns the address of the latest deployed Powers contract.
    /// @return The address of the latest deployment.
    function getLatestDeployment() external view returns (address) {
        return latestDeployment;
    }
}
