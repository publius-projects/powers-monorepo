// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { AllowanceModule } from "lib/safe-modules/modules/allowances/contracts/AllowanceModule.sol";

// @dev this script deploys Safe Allowance Module.
contract DeployAllowanceModule is Script {
    AllowanceModule allowanceModule;

    function run() external returns (address allowanceModuleAddress) {
        // Use timestamp to ensure unique salt and fresh deployment address
        bytes32 salt = keccak256(abi.encodePacked("PowersSalt", vm.unixTime()));
        
        vm.startBroadcast();
        allowanceModule = new AllowanceModule{ salt: salt }();
        vm.stopBroadcast();
        
        console.log("AllowanceModule deployed at:", address(allowanceModule));
        return address(allowanceModule);
    }
}
