// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// scripts
import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

// interfaces
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";

contract DeployHelpers is Script {
    address testAccount1 = vm.addr(vm.envUint("TEST_ACCOUNT_KEY_1"));
    address testAccount2 = vm.addr(vm.envUint("TEST_ACCOUNT_KEY_2"));
    address testAccount3 = vm.addr(vm.envUint("TEST_ACCOUNT_KEY_3"));

    // Struct to hold the result for each name lookup
    struct IndexResult {
        uint16 flowIndex;
        uint16 mandateIndex;
        bool found;
    }

    function daysToBlocks(uint256 quantityDays, uint256 blocksPerHour) public pure returns (uint32) {
        return uint32(quantityDays * 24 * blocksPerHour);
    }

    function hoursToBlocks(uint256 quantityHours, uint256 blocksPerHour) public pure returns (uint32) {
        return uint32(quantityHours * blocksPerHour);
    }

    function minutesToBlocks(uint256 quantityMinutes, uint256 blocksPerHour) public pure returns (uint32) {
        return uint32((quantityMinutes * blocksPerHour) / 60);
    }

    function createPlaceholderAddress(string memory name) public pure returns (address) {
        // Create a unique placeholder address based on the name
        return address(uint160(uint256(keccak256(abi.encodePacked(name)))));
    }

    function findIndices(
        string[] memory targetNames, 
        PowersTypes.MandateInitData[] memory mandateInitData, 
        PowersTypes.Flow[] memory flows
    )
        public
        pure
        returns (uint16[] memory flowIndices, uint16[] memory mandateIndices)
    {
        // Temporary arrays with maximum possible size
        uint16[] memory tempFlowIndices = new uint16[](targetNames.length);
        uint16[] memory tempMandateIndices = new uint16[](targetNames.length);
        uint16 foundCount = 0;
        
        for (uint16 n = 0; n < targetNames.length; n++) {
            bool foundMandate = false;
            uint16 mandateId;
            
            // Find the mandate by name
            for (uint16 i = 0; i < mandateInitData.length; i++) {
                if (keccak256(bytes(mandateInitData[i].nameDescription)) == keccak256(bytes(targetNames[n]))) {
                    mandateId = i;
                    foundMandate = true;
                    break;
                }
            }
            
            if (foundMandate) {
                // Find the flow containing this mandate
                bool foundInFlow = false;
                for (uint16 j = 0; j < flows.length; j++) {
                    for (uint16 k = 0; k < flows[j].mandateIds.length; k++) {
                        if (flows[j].mandateIds[k] == mandateId) {
                            tempFlowIndices[foundCount] = j;
                            tempMandateIndices[foundCount] = k;
                            foundCount++;
                            foundInFlow = true;
                            break;
                        }
                    }
                    if (foundInFlow) break;
                }
            }
        }
        
        // Create final arrays with correct size
        flowIndices = new uint16[](foundCount);
        mandateIndices = new uint16[](foundCount);
        
        for (uint16 i = 0; i < foundCount; i++) {
            flowIndices[i] = tempFlowIndices[i];
            mandateIndices[i] = tempMandateIndices[i];
        }
    }

}
