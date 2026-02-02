// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// import { Mandate } from "../../Mandate.sol";
// import { IPowers } from "../../interfaces/IPowers.sol";
// import { PowersTypes } from "../../interfaces/PowersTypes.sol";
// import { Powers } from "../../Powers.sol";
// import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
// import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// /**
//  * @title TreasuryPoolGovernance
//  * @notice Mandate B: Adopts the standard 3 governance mandates (Propose, Veto, Execute Transfer) for a Treasury Pool
//  * after it was created by a Mandate A action (e.g., via a mandate that calls TreasuryPools.createPool).
//  * @dev Reads the poolId from the stored return data of the pool creation action (Mandate A).
//  * @dev Reads the managerRoleId from the original input calldata of the pool creation action (Mandate A).
//  * @dev Condition `needFulfilled` must point to the specific Mandate A instance.
//  */
// contract TreasuryPoolGovernance is Mandate {
//     /// @dev Configurations for this mandate adoption mandate. Includes addresses of base mandates to adopt.
//     struct ConfigData {
//         address selectedPoolTransfer; // The SelectedPoolTransfer mandate
//         address treasuryPools; // The TreasuryPools contract
//         uint16 proposeMandateId; // Mandate ID for the Proposal mandate
//         uint16 vetoMandateId; // Mandate ID for the Veto mandate
//         uint32 votingPeriod;
//         uint8 succeedAt;
//         uint8 quorum;
//     }

//     /// @dev Mapping mandate hash => configuration.
//     mapping(bytes32 mandateHash => ConfigData data) public mandateConfig;

//     // State memory accumulator to avoid stack too deep errors
//     struct Mem {
//         uint256 createPoolActionId;
//         uint16 sourceActionMandateId;
//         uint48 sourceActionFulfilledAt;
//         bytes createPoolActionReturnData;
//         uint256 poolId;
//         bytes createPoolActionCalldata;
//         uint256 managerRoleId;

//         string[] transferInputParams;

//         // mem mandate
//         uint16 counter;
//         string mandateName;
//         bytes encodedParams;
//         bytes mandateConfig;
//         PowersTypes.MandateInitData mandateInitData;
//         PowersTypes.Conditions mandateCondition;
//     }

//     /// @notice Error if the referenced action ID is invalid or not fulfilled.
//     error InvalidSourceAction();
//     /// @notice Error decoding pool ID from source action return data.
//     error CannotDecodePoolId();
//     /// @notice Error decoding original inputs (managerRoleId) from source action calldata.
//     error CannotDecodeSourceInputs();
//     /// @notice Error if the mandate instance is not configured.
//     error MandateNotConfigured();

//     constructor() {
//         bytes memory configParams = abi.encode(
//             "address selectedPoolTransfer",
//             "address TreasuryPools",
//             "uint16 proposalMandateId",
//             "uint16 vetoMandateId",
//             "uint32 votingPeriod",
//             "uint8 succeedAt",
//             "uint8 quorum"
//         );
//         emit Mandate__Deployed(configParams);
//     }

//     /// @notice Standard initializer for Powers mandates.
//     /// @param index The unique index assigned by Powers.sol.
//     /// @param nameDescription A human-readable description.
//     /// @param inputParams ABI encoded string[] describing required inputs for execute.
//     /// @param config Abi.encode(address treasuryPools, address soi, address bespoke, uint16 createPoolMandateId).
//     function initializeMandate(
//         uint16 index,
//         string memory nameDescription,
//         bytes memory inputParams, // Expected: abi.encode(string[]("uint256 createPoolActionId"))
//         bytes memory config
//     ) public override {
//         (
//             address selectedPoolTransferAddress_,
//             address treasuryPoolsAddress_,
//             uint16 proposeMandateId_,
//             uint16 vetoMandateId_,
//             uint32 votingPeriod_,
//             uint8 succeedAt_,
//             uint8 quorum_
//         ) = abi.decode(config, (address, address, uint16, uint16, uint32, uint8, uint8));
//         bytes32 mandateHash_ = MandateUtilities.hashMandate(msg.sender, index);

//         inputParams = abi.encode("address TokenAddress", "uint256 Budget", "uint256 ManagerRoleId");

//         mandateConfig[mandateHash_] = ConfigData({
//             selectedPoolTransfer: selectedPoolTransferAddress_,
//             treasuryPools: treasuryPoolsAddress_,
//             proposeMandateId: proposeMandateId_,
//             vetoMandateId: vetoMandateId_,
//             votingPeriod: votingPeriod_,
//             succeedAt: succeedAt_,
//             quorum: quorum_
//         });

//         super.initializeMandate(index, nameDescription, inputParams, config);
//     }

//     /// @notice Prepares the calls to adopt the three governance mandates.
//     /// @param /* caller */ The original caller (not used).
//     /// @param powers The address of the Powers contract instance.
//     /// @param mandateId The ID of this specific mandate instance.
//     /// @param mandateCalldata ABI encoded input data: abi.encode(uint256 createPoolActionId).
//     /// @param nonce A unique nonce for replay protection.
//     /// @return actionId Unique ID for this action proposal.
//     /// @return targets Array containing the Powers address three times.
//     /// @return values Array containing 0 three times.
//     /// @return calldatas Array containing the three encoded calls to Powers.adoptMandate.
//     function handleRequest(
//         address,
//         /* caller */
//         address powers,
//         uint16 mandateId,
//         bytes memory mandateCalldata, // Contains createPoolActionId
//         uint256 nonce
//     )
//         public
//         view
//         override
//         returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
//     {
//         bytes32 mandateHash_ = MandateUtilities.hashMandate(powers, mandateId);
//         ConfigData memory config_ = mandateConfig[mandateHash_];
//         if (config_.treasuryPools == address(0)) revert("Mandate Not Configured");
//         Mem memory m;

//         // First get the mandate Id of the mandate that created the pool
//         IPowers.Conditions memory conditions = IPowers(powers).getConditions(mandateId);
//         if (conditions.needFulfilled == 0) revert("Fulfilled not set");

//         // Then retrieve the source action data
//         m.createPoolActionId = MandateUtilities.computeActionId(conditions.needFulfilled, mandateCalldata, nonce);
//         (m.sourceActionMandateId,,, m.sourceActionFulfilledAt,,,) = IPowers(powers).getActionData(m.createPoolActionId);

//         // Check if action exists, is fulfilled, and came from the correct mandate type
//         if (m.sourceActionFulfilledAt == 0) revert InvalidSourceAction();

//         // --- Decode necessary data, get the poolId ---
//         m.createPoolActionReturnData = IPowers(powers).getActionReturnData(m.createPoolActionId, 0);
//         (m.poolId) = abi.decode(m.createPoolActionReturnData, (uint256));
//         if (m.poolId == 0) revert("Cannot decode poolId"); // NB! PoolId 0 is invalid

//         // m.createPoolActionCalldata = IPowers(powers).getActionCalldata(m.createPoolActionId);
//         (,, m.managerRoleId) = abi.decode(mandateCalldata, (address, uint256, uint256));

//         // --- Predict the upcoming Mandate IDs ---
//         m.counter = Powers(payable(powers)).mandateCounter();

//         //////////////////////////////////////////////////////////////
//         //             BUILDING SELECTED POOL TRANSFER LAW          //
//         //////////////////////////////////////////////////////////////

//         // 3. Execute Transfer Mandate (SelectedPoolTransfer)
//         m.mandateName = string.concat("Pool ", Strings.toString(m.poolId), " Execute Transfer");

//         m.mandateConfig = abi.encode(config_.treasuryPools, m.poolId);

//         m.mandateCondition.allowedRole = m.managerRoleId; // Use roleId from Mandate A's input
//         m.mandateCondition.votingPeriod = config_.votingPeriod; // No voting period for Execute Transfer
//         m.mandateCondition.succeedAt = config_.succeedAt;
//         m.mandateCondition.quorum = config_.quorum;
//         m.mandateCondition.needFulfilled = config_.proposeMandateId; // Propose must pass
//         m.mandateCondition.needNotFulfilled = config_.vetoMandateId; // Veto must NOT pass

//         m.mandateInitData = PowersTypes.MandateInitData({
//             targetMandate: config_.selectedPoolTransfer,
//             nameDescription: m.mandateName,
//             config: m.mandateConfig,
//             conditions: m.mandateCondition
//         });

//         // --- Prepare the calls to Powers.adoptMandate ---
//         (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
//         targets[0] = powers;
//         calldatas[0] = abi.encodeWithSelector(IPowers.adoptMandate.selector, m.mandateInitData);

//         actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
//         // Powers.fulfill will execute these calls
//         return (actionId, targets, values, calldatas);
//     }

//     /// @notice Retrieves the config data for a given factory mandate instance.
//     function getConfigData(address powers, uint16 mandateId) external view returns (ConfigData memory) {
//         bytes32 mandateHash_ = MandateUtilities.hashMandate(powers, mandateId);
//         if (mandateConfig[mandateHash_].treasuryPools == address(0)) revert MandateNotConfigured();
//         return mandateConfig[mandateHash_];
//     }
// }
