// SPDX-License-Identifier: MIT

/// @notice An example implementation of a Mandate Package that adopts multiple mandates into the Powers protocol.
/// @dev It is meant to be adopted through the Mandates_Adopt mandate, and then be executed to adopt multiple mandates in a single transaction.
/// @dev The mandate self-destructs after execution.
///
/// @author 7Cedars

pragma solidity 0.8.26;

import { Mandate } from "../Mandate.sol";
import { MandateUtilities } from "../libraries/MandateUtilities.sol";
import { IPowers } from "../interfaces/IPowers.sol"; 
import { PowersTypes } from "../interfaces/PowersTypes.sol";
import { Configurations } from "../../script/Configurations.s.sol";

// For now this MandatePackage only adopts a new URI. Child organisaiton specific governance flows will be added later.

contract CulturalStewards_PaymentSequence is Mandate {
    address[] private mandateAddresses;
    Configurations.NetworkConfig private config;

    // in this case mandateAddresses should be [SafeAllowance_Transfer, statementOfIntent] -- we only need those two mandates for this package.
    constructor(address[] memory _mandateAddresses, Configurations.NetworkConfig memory _config) {
        mandateAddresses = _mandateAddresses; 
        config = _config;
        emit Mandate__Deployed(abi.encode());
    }

    function initializeMandate(
        uint16 index,
        string memory nameDescription,
        bytes memory inputParams,
        bytes memory config
    ) public override {
        inputParams = abi.encode("address treasury");
        super.initializeMandate(index, nameDescription, inputParams, config);
    }

    /// @notice Build calls to adopt the configured mandates
    /// @param mandateCalldata Unused for this mandate
    function handleRequest(
        address, /*caller*/
        address powers,
        uint16 mandateId,
        bytes memory mandateCalldata,
        uint256 nonce
    )
        public
        view
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        uint16 mandateCount = IPowers(powers).getMandateCounter();
        (address treasury) = abi.decode(mandateCalldata, (address)); // blocksPerHour, treasury
        PowersTypes.MandateInitData[] memory smandateInitData = getNewMandates(mandateAddresses, powers, mandateCount, treasury);

        

        // Create arrays for the calls to adoptMandate
        uint256 length = smandateInitData.length;
        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(length + 1);
        for (uint256 i; i < length; i++) {
            targets[i] = powers;
            calldatas[i] = abi.encodeWithSelector(IPowers.adoptMandate.selector, smandateInitData[i]);
        }
        // Final call to self-destruct the MandatePackage after adopting the mandates
        targets[length] = powers;
        calldatas[length] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateId);
        return (actionId, targets, values, calldatas);
    }

    /// @notice Generates MandateInitData for a set of new mandates to be adopted.
    /// @param mandateAddresses The addresses of the mandates to be adopted.
    // / @param powers The address of the Powers contract.
    /// @return mandateInitData An array of MandateInitData structs for the new mandates.
    /// @dev the function follows the same pattern as TestConstitutions.sol
    /// this function can be overwritten to create different mandate packages.
    function getNewMandates(
        address[] memory mandateAddresses,
        address, /* powers */
        uint16 mandateCount,  
        address treasury
    )
        public
        view
        virtual
        returns (PowersTypes.MandateInitData[] memory mandateInitData)
    {
        mandateInitData = new PowersTypes.MandateInitData[](3);
        PowersTypes.Conditions memory conditions;

        // statementOfIntent params
        string[] memory inputParams = new string[](3);
        inputParams[0] = "address Token";
        inputParams[1] = "uint256 Amount";
        inputParams[2] = "address PayableTo";

        conditions.allowedRole = type(uint256).max; // This is a public mandate. Anyone can call it.
        mandateInitData[0] = PowersTypes.MandateInitData({
            nameDescription: "Submit a Receipt: Anyone can submit a receipt for payment reimbursement.",
            targetMandate: mandateAddresses[1], // statementOfIntent
            config: abi.encode(inputParams),
            conditions: conditions
        });
        delete conditions;

        // Conveners: OK Receipt (Avoid Spam)
        conditions.allowedRole = 2; // Any convener can ok a receipt.
        conditions.needFulfilled = mandateCount - 1; // need the previous mandate to be fulfilled.
        mandateInitData[1] = PowersTypes.MandateInitData({
            nameDescription: "OK a receipt: Any convener can ok a receipt for payment reimbursement.",
            targetMandate: mandateAddresses[1], // statementOfIntent
            config: abi.encode(inputParams),
            conditions: conditions
        });
        delete conditions;

        // Conveners: Approve Payment of Receipt
        conditions.allowedRole = 2; // Conveners
        conditions.votingPeriod = uint32((5 * config.BLOCKS_PER_HOUR) / 60); // 5 minutes
        conditions.succeedAt = 67;
        conditions.quorum = 50;
        conditions.needFulfilled = mandateCount - 1; // need the previous mandate to be fulfilled.
        mandateInitData[2] = PowersTypes.MandateInitData({
            nameDescription: "Approve payment of receipt: Execute a transaction from the Safe Treasury.",
            targetMandate: mandateAddresses[0], // SafeAllowance_Transfer 
            config: abi.encode(config.safeAllowanceModule, treasury),
            conditions: conditions
        }); 
        delete conditions;

        return mandateInitData;
    }  
}
 