// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// scripts
import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

// interfaces
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";

// mandates
import { ReformMandate_Static } from "@src/packaged-mandates/MandatePackage_Static.sol";

contract DeploySetup is Script {
    function daysToBlocks(uint256 quantityDays, uint256 blocksPerHour) public pure returns (uint32) {
        return uint32(quantityDays * 24 * blocksPerHour);
    }

    function hoursToBlocks(uint256 quantityHours, uint256 blocksPerHour) public pure returns (uint32) {
        return uint32(quantityHours * blocksPerHour);
    }

    function minutesToBlocks(uint256 quantityMinutes, uint256 blocksPerHour) public pure returns (uint32) {
        return uint32((quantityMinutes * blocksPerHour) / 60);
    }

    

    // this function takes
    // as param a long list of MandateInitData,
    // deploys the mandates in ReformMandate_Static of packageSize size using create2
    // and returns the mandateInitData for those packages.
    // the packages can then be adopted in Powers but are linked sequentially through needFulfilled conditions.
    function packageInitData(PowersTypes.MandateInitData[] memory mandateInitData, uint256 packageSize, uint16 startId)
        public
        returns (PowersTypes.MandateInitData[] memory packages)
    {
        require(packageSize > 0, "Package size must be greater than 0");

        uint256 totalMandates = mandateInitData.length;
        if (totalMandates == 0) {
            return new PowersTypes.MandateInitData[](0);
        }

        uint256 packageCount = (totalMandates + packageSize - 1) / packageSize;
        packages = new PowersTypes.MandateInitData[](packageCount);

        for (uint256 i = 0; i < packageCount; i++) {
            uint256 start = i * packageSize;
            uint256 end = start + packageSize;
            if (end > totalMandates) {
                end = totalMandates;
            }
            uint256 currentPackageSize = end - start;

            // Create sub-array for this package
            PowersTypes.MandateInitData[] memory batch = new PowersTypes.MandateInitData[](currentPackageSize);
            for (uint256 j = 0; j < currentPackageSize; j++) {
                batch[j] = mandateInitData[start + j];
            }

            // Deploy ReformMandate_Static with the batch
            bytes memory constructorArgs = abi.encode(batch);
            bytes32 salt = bytes32(abi.encodePacked(constructorArgs));
            address deployedAddress = vm.computeCreate2Address(
                salt,
                keccak256(abi.encodePacked(type(ReformMandate_Static).creationCode, constructorArgs))
            );

            if (deployedAddress.code.length == 0) {
                vm.startBroadcast();
                new ReformMandate_Static{salt: salt}(batch);
                vm.stopBroadcast();
            }

            // Create MandateInitData for the package
            // Link sequentially using needFulfilled
            PowersTypes.Conditions memory conditions;
            if (i >= 0) {
                // The previous package (i-1) will be at ID: startId + (i-1)
                // The current package (i) needs the previous one fulfilled.
                conditions.allowedRole = type(uint256).max; // public
                if (i > 0) conditions.needFulfilled = startId + uint16(i) - 1;
            }

            packages[i] = PowersTypes.MandateInitData({
                nameDescription: string(abi.encodePacked("Reform Package ", vm.toString(i + 1))),
                targetMandate: deployedAddress,
                config: "",
                conditions: conditions
            });
        }
    }

}
