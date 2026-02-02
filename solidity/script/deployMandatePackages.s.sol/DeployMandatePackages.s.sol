// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// core protocol
import { Powers } from "@src/Powers.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Configurations } from "@script/Configurations.s.sol";

import { InitialisePowers } from "@script/InitialisePowers.s.sol";
import { MandatePackage } from "@src/packaged-mandates/MandatePackage.sol";
import { PowerLabs_Documentation } from "@src/packaged-mandates/PowersLabs_Documentation.sol";
import { PowerLabs_Frontend } from "@src/packaged-mandates/PowersLabs_Frontend.sol";
import { PowerLabs_Protocol } from "@src/packaged-mandates/PowersLabs_Protocol.sol";

// @dev this script deploys custom mandate packages to the chain.
contract DeployMandatePackages is Script {
    bytes32 salt = bytes32(abi.encodePacked("MandatePackageDeploymentSaltV1"));
    InitialisePowers initialisePowers;
    Configurations helperConfig;
    Configurations.NetworkConfig public config;
    Powers powers;

    // PowerLabsConfig
    function run() external returns (string[] memory packageNames, address[] memory packageAddresses) {
        initialisePowers = new InitialisePowers();
        initialisePowers.run();
        helperConfig = new Configurations();
        config = helperConfig.getConfig();

        (packageNames, packageAddresses) = deployPackages();
    }

    /// @notice Deploys all mandate contracts and uses 'serialize' to record their addresses.
    function deployPackages() internal returns (string[] memory names, address[] memory addresses) {
        names = new string[](3);
        addresses = new address[](3);
        bytes[] memory creationCodes = new bytes[](3);
        bytes[] memory constructorArgs = new bytes[](3);

        // PowerLabsConfig
        address[] memory mandateDependencies = new address[](5);
        mandateDependencies[0] = initialisePowers.getInitialisedAddress("StatementOfIntent");
        mandateDependencies[1] = initialisePowers.getInitialisedAddress("Safe_ExecTransaction");
        mandateDependencies[2] = initialisePowers.getInitialisedAddress("PresetActions_Single");
        mandateDependencies[4] = initialisePowers.getInitialisedAddress("RoleByTransaction");

        // PowerLabs_Documentation // no dependencies for now
        mandateDependencies = new address[](1);
        mandateDependencies[0] = initialisePowers.getInitialisedAddress("StatementOfIntent");
        names[0] = "PowerLabs_Documentation";
        creationCodes[0] = type(PowerLabs_Documentation).creationCode;
        constructorArgs[0] = abi.encode(
            config.BLOCKS_PER_HOUR,
            mandateDependencies, // empty array for now, will be set through a reform later.
            config.safeAllowanceModule // zero address for allowance module, will be set through a reform later.
        );

        // PowerLabs_Frontend
        names[1] = "PowerLabs_Frontend";
        creationCodes[1] = type(PowerLabs_Frontend).creationCode;
        constructorArgs[1] = abi.encode(
            config.BLOCKS_PER_HOUR,
            mandateDependencies, // empty array for now, will be set through a reform later.
            config.safeAllowanceModule // zero address for allowance module, will be set through a reform later.
        );

        // PowerLabs_Protocol
        names[2] = "PowerLabs_Protocol";
        creationCodes[2] = type(PowerLabs_Protocol).creationCode;
        constructorArgs[2] = abi.encode(
            config.BLOCKS_PER_HOUR,
            mandateDependencies, // empty array for now, will be set through a reform later.
            config.safeAllowanceModule // zero address for allowance module, will be set through a reform later.
        );

        for (uint256 i = 0; i < names.length; i++) {
            address mandateAddr = deployMandatePackage(creationCodes[i], constructorArgs[i]);
            addresses[i] = mandateAddr;
        }

        return (names, addresses);
    }

    /// @dev Deploys a mandate using CREATE2. Salt is derived from constructor arguments.
    function deployMandatePackage(bytes memory creationCode, bytes memory constructorArgs) internal returns (address) {
        bytes memory deploymentData = abi.encodePacked(creationCode, constructorArgs);
        address computedAddress = Create2.computeAddress(salt, keccak256(deploymentData), CREATE2_FACTORY);

        if (computedAddress.code.length == 0) {
            vm.startBroadcast();
            address deployedAddress = Create2.deploy(0, salt, deploymentData);
            vm.stopBroadcast();
            // require(deployedAddress == computedAddress, "Error: Deployed address mismatch.");
            return deployedAddress;
        }
        return computedAddress;
    }
}
