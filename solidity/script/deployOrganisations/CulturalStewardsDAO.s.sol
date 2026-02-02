// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// scripts
import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { Configurations } from "@script/Configurations.s.sol";
import { InitialisePowers } from "@script/InitialisePowers.s.sol";
import { DeploySetup } from "./DeploySetup.s.sol";

// external protocols
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { SafeProxyFactory } from "lib/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import { Safe } from "lib/safe-smart-account/contracts/Safe.sol";
import { ModuleManager } from "lib/safe-smart-account/contracts/base/ModuleManager.sol";

// powers contracts
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";

// helpers
import { SimpleErc20Votes } from "@mocks/SimpleErc20Votes.sol";
import { Soulbound1155 } from "@src/helpers/Soulbound1155.sol";
import { PowersFactory } from "@src/helpers/PowersFactory.sol";
import { ElectionList } from "@src/helpers/ElectionList.sol";
import { RwaMock, ComplianceRegistryMock } from "@mocks/RwaMock.sol";

/// @title Cultural Stewards DAO - Deployment Script
/// Note: all days are turned into minutes for testing purposes. These should be changed before production deployment: ctrl-f minutesToBlocks -> daysToBlocks.
contract CulturalStewardsDAO is DeploySetup {
    InitialisePowers initialisePowers;
    Configurations helperConfig;
    Configurations.NetworkConfig public config;
    PowersTypes.Conditions conditions;

    PowersTypes.MandateInitData[] primaryConstitution;
    PowersTypes.MandateInitData[] digitalConstitution;
    PowersTypes.MandateInitData[] ideasConstitution;
    PowersTypes.MandateInitData[] packedIdeasConstitution;
    PowersTypes.MandateInitData[] physicalConstitution;
    PowersTypes.MandateInitData[] packedPhysicalConstitution;

    Powers primaryDAO;
    Powers digitalSubDAO;
    Powers ideasSubDAO;
    Powers physicalSubDAO;

    PowersFactory ideasDaoFactory;
    PowersFactory physicalDaoFactory;
    Soulbound1155 soulbound1155;
    ElectionList electionList;

    // NB: FOR TESTING PURPOSES ONLY: REMOVE BEFORE ACTUAL DEPLOYMENT!
    address cedars = 0x328735d26e5Ada93610F0006c32abE2278c46211;
    address testAccount1 = 0xEA223f81D7E74321370a77f1e44067bE8738B627;
    address testAccount2 = 0x1bFdB91B283d7Ec24012d7ff5A5B29005140D09a;
    address testAccount3 = 0x49fCf1DD685F6b5F88d9b0a972Dbf80Ee8846234;
    // NB: FOR TESTING PURPOSES ONLY: REMOVE BEFORE ACTUAL DEPLOYMENT!

    uint256 constitutionLength;
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] inputParams;
    string[] dynamicParams;
    uint16 mandateCount;
    address treasury;
    uint256 constant PACKAGE_SIZE = 10;
    uint16 requestAllowanceDigitalDAOId; // mandate id for request allowance on digital subDAO.
    uint16 requestAllowancePhysicalDAOId; // mandate id for request allowance on ideas subDAO.
    uint16 mintPoapTokenId; // mandate id for minting POAP tokens on soulbound1155.
    uint16 mintActivityTokenId; 
    uint16 requestNewPhysicalDaoId; 

    // DEPLOY SEQUENCE FOR L2s FOR CULTURAL STEWARDS DAO
    function run() external { 
        // step 0, setup.
        initialisePowers = new InitialisePowers();
        initialisePowers.run();
        helperConfig = new Configurations();
        config = helperConfig.getConfig();

        // Deploy vanilla DAOs (parent and digital) and DAO factories (for ideas and physical).
        vm.startBroadcast();
        console2.log("Deploying Vanilla Powers contracts...");
        primaryDAO = new Powers(
            "Primary DAO", // name
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreihtpfkpjxianudgvf7pdq7toccccrztvckqpkc3vfnai4x7l3zmme", // uri
            config.maxCallDataLength, // max call data length
            config.maxReturnDataLength, // max return data length
            config.maxExecutionsLength // max executions length
        );

        digitalSubDAO = new Powers(
            "Digital sub-DAO", // name
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreiemrhwiqju7msjxbszlrk73cn5omctzf2xf2jxaenyw7is2r4takm", // uri
            config.maxCallDataLength, // max call data length
            config.maxReturnDataLength, // max return data length
            config.maxExecutionsLength // max executions length
        );

        console2.log("Deploying Organisation's Helper contracts...");
        soulbound1155 = new Soulbound1155(
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreighx6axdemwbjara3xhhfn5yaiktidgljykzx3vsrqtymicxxtgvi"
        );
        vm.stopBroadcast();
        console2.log("Primary DAO deployed at:", address(primaryDAO));
        console2.log("Digital sub-DAO deployed at:", address(digitalSubDAO));
        console2.log("Soulbound1155 deployed at:", address(soulbound1155));

        // setup Safe treasury.
        address[] memory owners = new address[](1);
        owners[0] = address(primaryDAO);

        vm.startBroadcast();
        console2.log("Setting up Safe treasury for Primary DAO...");
        treasury = address(
            SafeProxyFactory(config.safeProxyFactory)
                .createProxyWithNonce(
                    config.safeL2Canonical,
                    abi.encodeWithSelector(
                        Safe.setup.selector,
                        owners,
                        1, // threshold
                        address(0), // to
                        "", // data
                        address(0), // fallbackHandler
                        address(0), // paymentToken
                        0, // payment
                        address(0) // paymentReceiver
                    ),
                    1 // = nonce
                )
        );
        vm.stopBroadcast();
        console2.log("Safe treasury deployed at:", treasury);

        console2.log("Creating Physical constitution...");
        createPhysicalConstitution();
        console2.log("Physical Constitution, length:", physicalConstitution.length); 

        console2.log("Deploying Physical sub-DAO factory...");
        vm.startBroadcast();
        physicalDaoFactory = new PowersFactory(
            config.maxCallDataLength, // max call data length
            config.maxReturnDataLength, // max return data length
            config.maxExecutionsLength // max executions length
        );
        physicalDaoFactory.addMandates(packedPhysicalConstitution); // Note: if needed we can also loop through mandates one-by-one. 
        vm.stopBroadcast();

        // Create primary constitution first to set mandate IDs
        console2.log("Creating Primary constitution...");
        createPrimaryConstitution();
        console2.log("Primary Constitution, length:", primaryConstitution.length);

        console2.log("Creating Digital constitution...");
        createDigitalConstitution();
        console2.log("Digital Constitution, length:", digitalConstitution.length);

        // Deploying Ideas and Physical sub-DAO factories (after primary constitution to reference mandate IDs)
        console2.log("Creating Ideas constitution...");
        createIdeasConstitution();
        console2.log("Ideas Constitution, length:", ideasConstitution.length);

        // Deploying subDAO factories.
        console2.log("Deploying Ideas Sub-DAO factory...");
        vm.startBroadcast();
        ideasDaoFactory = new PowersFactory(
            config.maxCallDataLength, // max call data length
            config.maxReturnDataLength, // max return data length
            config.maxExecutionsLength // max executions length
        );
        ideasDaoFactory.addMandates(packedIdeasConstitution); // Note: if needed we can also loop through mandates one-by-one. 
        vm.stopBroadcast();
        
        console2.log("Ideas sub-DAO factory deployed at:", address(ideasDaoFactory));
        console2.log("Physical sub-DAO factory deployed at:", address(physicalDaoFactory));

        // Step 4: run constitute on vanilla DAOs. Send 10 mandates each time to avoid gas limits overruns.
        
        console2.log("Constituting Primary DAO...");
        // due to the size of these DAOs, we add them one by one in a loop.
        PowersTypes.MandateInitData[] memory batch = new PowersTypes.MandateInitData[](1); 
        for (uint256 i = 0; i < primaryConstitution.length; i++) {
            batch[0] = primaryConstitution[i];
            vm.startBroadcast();
            primaryDAO.constitute(batch); // set msg.sender as admin
            vm.stopBroadcast();
        } 
        vm.startBroadcast();
        primaryDAO.closeConstitute();
        vm.stopBroadcast();

        console2.log("Constituting Digital sub-DAO...");
        for (uint256 i = 0; i < digitalConstitution.length; i++) {
            batch[0] = digitalConstitution[i];
            vm.startBroadcast();
            digitalSubDAO.constitute(batch); // set msg.sender as admin
            vm.stopBroadcast();
        } 
        vm.startBroadcast();
        digitalSubDAO.closeConstitute();
        vm.stopBroadcast();

        // step 5: transfer ownership of factories to primary DAO.
        vm.startBroadcast();
        console2.log("Transferring ownership of DAO factories to Primary DAO...");
        soulbound1155.transferOwnership(address(primaryDAO));
        ideasDaoFactory.transferOwnership(address(primaryDAO));
        physicalDaoFactory.transferOwnership(address(primaryDAO));
        vm.stopBroadcast();

        console2.log("Success! All contracts successfully deployed, unpacked and configured.");
    }

    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    //                         PRIME DAO CONSTITUTION                         //
    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////

    function createPrimaryConstitution() internal {
        mandateCount = 0; // resetting mandate count at 4, because there will be 4 packagedMandate Laws.
        //////////////////////////////////////////////////////////////////////
        //                              SETUP                               //
        //////////////////////////////////////////////////////////////////////
        // setup calls //
        // signature for Safe module enabling call
        bytes memory signature = abi.encodePacked(
            uint256(uint160(address(primaryDAO))), // r = address of the signer (powers contract)
            uint256(0), // s = 0
            uint8(1) // v = 1 This is a type 1 call. See Safe.sol for details.
        );

        targets = new address[](16);
        values = new uint256[](16);
        calldatas = new bytes[](16);

        for (uint256 i = 0; i < targets.length; i++) {
            targets[i] = address(primaryDAO);
        }
        targets[13] = treasury; // the Safe treasury address.
        targets[14] = treasury; // the Safe treasury address.

        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Members");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Executives");
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 3, "Physical sub-DAOs");
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 4, "Ideas sub-DAOs");
        calldatas[4] = abi.encodeWithSelector(IPowers.labelRole.selector, 5, "Digital sub-DAOs");
        calldatas[5] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, cedars);
        calldatas[6] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, testAccount1);
        calldatas[7] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, testAccount2);
        calldatas[8] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, testAccount3);
        calldatas[9] = abi.encodeWithSelector(IPowers.assignRole.selector, 2, cedars);
        calldatas[10] = abi.encodeWithSelector(IPowers.assignRole.selector, 3, cedars);
        calldatas[11] = abi.encodeWithSelector(IPowers.assignRole.selector, 5, address(digitalSubDAO));
        calldatas[12] = abi.encodeWithSelector(IPowers.setTreasury.selector, treasury);
        calldatas[13] = abi.encodeWithSelector( // cal to set allowance module to the Safe treasury.
            Safe.execTransaction.selector,
            treasury, // The internal transaction's destination
            0, // The internal transaction's value in this mandate is always 0. To transfer Eth use a different mandate.
            abi.encodeWithSelector( // the call to be executed by the Safe: enabling the module.
                ModuleManager.enableModule.selector,
                config.safeAllowanceModule
            ),
            0, // operation = Call
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            address(0), // refundReceiver
            signature // the signature constructed above
        );
        calldatas[14] = abi.encodeWithSelector( // call to set Digital sub-DAO as delegate to the Safe treasury.
            Safe.execTransaction.selector,
            config.safeAllowanceModule, // The internal transaction's destination: the Allowance Module.
            0, // The internal transaction's value in this mandate is always 0. To transfer Eth use a different mandate.
            abi.encodeWithSignature(
                "addDelegate(address)", // == AllowanceModule.addDelegate.selector,  (because the contracts are compiled with different solidity versions we cannot reference the contract directly here)
                address(digitalSubDAO)
            ),
            0, // operation = Call
            0, // safeTxGas
            0, // baseGas
            0, // gasPrice
            address(0), // gasToken
            address(0), // refundReceiver
            signature // the signature constructed above
        );
        calldatas[15] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1); // revoke mandate after use.

        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = public.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initial Setup: Assigns role labels, sets up the allowance module, the treasury and revokes itself after execution",
                targetMandate: initialisePowers.getInitialisedAddress("PresetActions_Single"),
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                      EXECUTIVE MANDATES                          //
        //////////////////////////////////////////////////////////////////////
        // CREATE IDEAS DAO //
        inputParams = new string[](2);
        inputParams[0] = "string Name";
        inputParams[1] = "string Uri"; 
        // note: no allowance assigned. Ideas sub-DAO do not control assets.

        // Members: Initiate Ideas sub-DAO creation
        mandateCount++;
        conditions.allowedRole = 1; // = Members
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = 5 minutes / days
        conditions.succeedAt = 51; // = 51% majority
        conditions.quorum = 5; // = 5% quorum. Note: very low quorum to encourage experimentation.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initiate Ideas sub-DAO: Initiate creation of Ideas sub-DAO",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Executives: Execute Ideas sub-DAO creation
        mandateCount++;
        conditions.allowedRole = 2; // = Executives
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = 5 minutes / days
        conditions.succeedAt = 66; // = 2/3 majority
        conditions.quorum = 66; // = 66% quorum
        conditions.needFulfilled = mandateCount - 1; // need the previous mandate to be fulfilled.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Create Ideas sub-DAO: Execute Ideas sub-DAO creation",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(
                    address(ideasDaoFactory), // calling the ideas factory
                    PowersFactory.createPowers.selector, // function selector to call
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Executives: Assign role Id to Ideas sub-DAO //
        mandateCount++;
        conditions.allowedRole = 2; // = Any executive
        conditions.needFulfilled = mandateCount - 1; // need the previous mandate to be fulfilled.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Assign role Id to DAO: Assign role id 4 (Ideas sub-DAO) to the new DAO",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_OnReturnValue"),
                config: abi.encode(
                    address(primaryDAO), // target contract
                    IPowers.assignRole.selector, // function selector to call
                    abi.encode(4), // params before (role id 4 = Ideas sub-DAOs)
                    inputParams, // dynamic params (the address of the created Ideas sub-DAO)
                    mandateCount - 1, // parent mandate id (the create Ideas sub-DAO mandate)
                    abi.encode() // no params after
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // REVOKE IDEAS DAO //
        inputParams = new string[](1);
        inputParams[0] = "address IdeasSubDAO";

        // Members: Veto Revoke Ideas sub-DAO creation mandate //
        mandateCount++;
        conditions.allowedRole = 1; // = Members
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = 5 minutes / days
        conditions.succeedAt = 51; // = 51% majority
        conditions.quorum = 77; // = Note: high threshold.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto revoke Ideas sub-DAO: Veto the revoking of an Ideas sub-DAO from Cultural Stewards",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Executives: Revoke Ideas sub-DAO (revoke role Id) //
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.quorum = 66;
        conditions.succeedAt = 51;
        conditions.timelock = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.needNotFulfilled = mandateCount - 1; // need the veto to have NOT been fulfilled.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke role Id: Revoke role id 4 (Ideas sub-DAO) from the DAO",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Advanced"),
                config: abi.encode(
                    address(primaryDAO), // target contract
                    IPowers.revokeRole.selector, // function selector to call
                    abi.encode(4), // params before (role id 4 = Ideas sub-DAOs) // the static params
                    inputParams, // the dynamic params (the address of the created Ideas sub-DAO)
                    abi.encode() // no args after
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // CREATE PHYSICAL DAO //
        inputParams = new string[](2);
        inputParams[0] = "string Name";
        inputParams[1] = "string Uri"; 
        // note: an allowance is set when DAO is created.

        // Ideas sub-DAOs: Initiate Physical sub-DAO creation. Any Ideas sub-DAO can propose creating a Physical sub-DAO.
        mandateCount++;
        conditions.allowedRole = 4; // = Ideas sub-DAO
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initiate Physical sub-DAO: Initiate creation of Physical sub-DAO",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;
        requestNewPhysicalDaoId = mandateCount; 

        // Executives: Execute Physical sub-DAO creation
        mandateCount++;
        conditions.allowedRole = 2; // = Executives
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = 5 minutes / days
        conditions.succeedAt = 66; // = 2/3 majority
        conditions.quorum = 66; // = 66% quorum
        conditions.needFulfilled = mandateCount - 1; // need the previous mandate to be fulfilled.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Create Physical sub-DAO: Execute Physical sub-DAO creation",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(
                    physicalDaoFactory, // calling the Physical factory
                    PowersFactory.createPowers.selector, // function selector to call
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Executives: Assign role Id to Physical sub-DAO //
        mandateCount++;
        conditions.allowedRole = 2; // = Any executive
        conditions.needFulfilled = mandateCount - 1; // need the previous mandate to be fulfilled.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Assign role Id: Assign role Id 3 to Physical sub-DAO",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_OnReturnValue"),
                config: abi.encode(
                    address(primaryDAO), // target contract
                    IPowers.assignRole.selector, // function selector to call
                    abi.encode(uint16(3)), // params before (role id 4 = Ideas sub-DAOs)
                    inputParams, // dynamic params (the address of the created Ideas sub-DAO)
                    mandateCount - 1, // parent mandate id (the create Ideas sub-DAO mandate)
                    abi.encode() // no params after
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Executives: Assign Delegate status to Physical sub-DAO //
        mandateCount++;
        conditions.allowedRole = 2; // = Any executive
        conditions.needFulfilled = mandateCount - 2; // need the Physical sub-DAO to have been created.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Assign Delegate status: Assign delegate status at Safe treasury to the Physical sub-DAO",
                targetMandate: initialisePowers.getInitialisedAddress("Safe_ExecTransaction_OnReturnValue"),
                config: abi.encode(
                    config.safeAllowanceModule, // target contract
                    bytes4(0xe71bdf41), // == AllowanceModule.addDelegate.selector (because the contracts are compiled with different solidity versions we cannot reference the contract directly here)
                    abi.encode(), // params before (role id 4 = Ideas sub-DAOs)
                    inputParams, // dynamic params (the address of the created Ideas sub-DAO)
                    mandateCount - 2, // parent mandate id (the create Physical sub-DAO mandate)
                    abi.encode() // no params after
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // REVOKE PHYSICAL DAO //
        inputParams = new string[](2);
        inputParams[0] = "address IdeasSubDAO";
        inputParams[1] = "bool removeAllowance";

        // members veto revoking physical DAO
        mandateCount++;
        conditions.allowedRole = 1; // = Members
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = 5 minutes / days
        conditions.succeedAt = 51; // = 51% majority
        conditions.quorum = 77; // = Note: high threshold.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto revoke Physical sub-DAO: Veto the revoking of an Physical sub-DAO from Cultural Stewards",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Executives: Revoke Physical sub-DAO (Revoke Role ID) //
        mandateCount++;
        conditions.allowedRole = 2; // = Executives
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = 5 minutes / days
        conditions.succeedAt = 51; // = 51% majority
        conditions.quorum = 77; // = Note: high threshold.
        conditions.timelock = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = 10 minutes timelock before execution.
        conditions.needNotFulfilled = mandateCount - 1; // need the veto to have NOT been fulfilled.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke Role Id: Revoke role Id 3 from Physical sub-DAO",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Advanced"),
                config: abi.encode(
                    address(primaryDAO), // target contract
                    IPowers.revokeRole.selector, // function selector to call
                    abi.encode(3), // params before (role id 3 = Physical sub-DAOs) // the static params
                    inputParams, // the dynamic params (the address of the created Ideas sub-DAO)
                    abi.encode() // no args after
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Executives: Revoke Physical sub-DAO (Revoke Delegate status DAO) //
        mandateCount++;
        conditions.allowedRole = 2; // = Executives
        conditions.needFulfilled = mandateCount - 1; // need the assign role to have been fulfilled.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke Delegate status: Revoke delegate status Physical sub-DAO at the Safe treasury",
                targetMandate: initialisePowers.getInitialisedAddress("Safe_ExecTransaction"),
                config: abi.encode(
                    inputParams,
                    bytes4(0xdd43a79f), // == AllowanceModule.removeDelegate.selector (because the contracts are compiled with different solidity versions we cannot reference the contract directly
                    config.safeAllowanceModule // target contract
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // ASSIGN ADDITIONAL ALLOWANCE TO PHYSICAL DAO OR DIGITAL DAO //
        inputParams = new string[](5);
        inputParams[0] = "address Sub-DAO";
        inputParams[1] = "address Token";
        inputParams[2] = "uint96 allowanceAmount";
        inputParams[3] = "uint16 resetTimeMin";
        inputParams[4] = "uint32 resetBaseMin";

        // Physical sub-DAO: Veto additional allowance
        mandateCount++;
        conditions.allowedRole = 3; // = Physical sub-DAOs
        conditions.quorum = 66; // = 66% quorum needed
        conditions.succeedAt = 66; // = 66% majority needed for veto.
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = number of blocks
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto allowance: Veto setting an allowance to either Digital sub-DAO or a Physical sub-DAO.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Physical sub-DAO: Request additional allowance
        mandateCount++;
        conditions.allowedRole = 3; // = Physical sub-DAOs.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Request additional allowance: Any Physical sub-DAO can request an allowance from the Safe Treasury.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;
        requestAllowancePhysicalDAOId = mandateCount; // store the mandate id for Digital sub-DAO allowance veto.

        // Executives: Grant Allowance to Physical sub-DAO
        mandateCount++;
        conditions.allowedRole = 2; // = Executives.
        conditions.quorum = 30; // = 30% quorum needed
        conditions.succeedAt = 51; // = 51% simple majority needed for assigning and revoking members.
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = number of blocks
        conditions.needFulfilled = mandateCount - 1; // = the proposal mandate.
        conditions.needNotFulfilled = mandateCount - 2; // = the veto mandate.
        conditions.timelock = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = 10 minutes timelock before execution.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Set Allowance: Execute and set allowance for a Physical sub-DAO.",
                targetMandate: initialisePowers.getInitialisedAddress("SafeAllowance_Action"),
                config: abi.encode(
                    inputParams,
                    bytes4(0xbeaeb388), // == AllowanceModule.setAllowance.selector (because the contracts are compiled with different solidity versions we cannot reference the contract directly here)
                    config.safeAllowanceModule
                ),
                conditions: conditions // everythign zero == Only admin can call directly
            })
        );
        delete conditions;

        // Digital sub-DAO: Request additional allowance
        mandateCount++;
        conditions.allowedRole = 5; // = Digital sub-DAO.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Request additional allowance: The Digital sub-DAO can request an allowance from the Safe Treasury.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;
        requestAllowanceDigitalDAOId = mandateCount; // store the mandate id for Physical sub-DAO allowance veto.

        // Executives: Grant Allowance to Digital sub-DAO
        mandateCount++;
        conditions.allowedRole = 2; // = Executives.
        conditions.quorum = 30; // = 30% quorum needed
        conditions.succeedAt = 51; // = 51% simple majority needed for assigning and revoking members.
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = number of blocks
        conditions.needFulfilled = mandateCount - 1; // = the proposal mandate.
        conditions.needNotFulfilled = mandateCount - 4; // = the veto mandate.
        conditions.timelock = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = 10 minutes timelock before execution.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Set Allowance: Execute and set allowance for the Digital sub-DAO.",
                targetMandate: initialisePowers.getInitialisedAddress("SafeAllowance_Action"),
                config: abi.encode(
                    inputParams,
                    bytes4(0xbeaeb388), // == AllowanceModule.setAllowance.selector (because the contracts are compiled with different solidity versions we cannot reference the contract directly here)
                    config.safeAllowanceModule
                ),
                conditions: conditions // everythign zero == Only admin can call directly
            })
        );
        delete conditions;

        // EXECUTE VETO ON MANDATE ADOPTION AT OTHER SUB-DAOs //
        inputParams = new string[](2);
        inputParams[0] = "uint16[] MandateId";
        inputParams[1] = "uint256[] roleIds";

        // Executioners: Veto call to Powers instance and mandateIds in other sub-DAOs
        mandateCount++;
        conditions.allowedRole = 2; // = executioners
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = 5 minutes / days
        conditions.succeedAt = 51; // = 51% majority
        conditions.quorum = 77; // = Note: high threshold.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Call to sub-Dao: Executioners can veto updating the Primary DAO URI",
                targetMandate: initialisePowers.getInitialisedAddress("PowersAction_Flexible"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // UPDATE URI //
        inputParams = new string[](1);
        inputParams[0] = "string newUri";

        // Members: Veto update URI
        mandateCount++;
        conditions.allowedRole = 1; // = Members
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = 5 minutes / days
        conditions.succeedAt = 51; // = 51% majority
        conditions.quorum = 77; // = Note: high threshold.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto update URI: Members can veto updating the Primary DAO URI",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Executives: Update URI
        mandateCount++;
        conditions.allowedRole = 2; // = Executives
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = 5 minutes / days
        conditions.succeedAt = 66; // = 2/3 majority
        conditions.quorum = 66; // = 66% quorum
        conditions.needNotFulfilled = mandateCount - 1; // the previous VETO mandate should not have been fulfilled.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Update URI: Set allowed token for Cultural Stewards DAOs",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(
                    address(primaryDAO), // calling the allowed tokens contract
                    IPowers.setUri.selector, // function selector to call
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Ideas sub-DAO: Mint Tokens Ideas sub-DAO - ERC 1155 //
        inputParams = new string[](1);
        inputParams[0] = "address To";

        mandateCount++;
        conditions.allowedRole = 4; // = Ideas sub-DAOs
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Mint token Ideas sub-DAO: Any Ideas sub-DAO can mint new NFTs",
                targetMandate: initialisePowers.getInitialisedAddress("Soulbound1155_MintEncodedToken"),
                config: abi.encode(address(soulbound1155)),
                conditions: conditions
            })
        );
        delete conditions;
        mintActivityTokenId = mandateCount; // store the mandate id for minting activity tokens.

        // Physical sub-DAOs: Mint NFTs Physical sub-DAO - ERC 1155 //
        mandateCount++;
        conditions.allowedRole = 3; // = Physical sub-DAOs
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Mint token Physical sub-DAO: Any Physical sub-DAO can mint new NFTs",
                targetMandate: initialisePowers.getInitialisedAddress("Soulbound1155_MintEncodedToken"),
                config: abi.encode(address(soulbound1155)),
                conditions: conditions
            })
        );
        delete conditions;
        mintPoapTokenId = mandateCount; // store the mandate id for minting POAP tokens.

        // TRANSFER TOKENS INTO TREASURY //
        mandateCount++;
        conditions.allowedRole = 2; // = Executives. Any executive can call this mandate.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Transfer tokens to treasury: Any tokens accidently sent to the Primary DAO can be recovered by sending them to the treasury",
                targetMandate: initialisePowers.getInitialisedAddress("Safe_RecoverTokens"),
                config: abi.encode(
                    treasury, // this should be the safe treasury!
                    config.safeAllowanceModule // allowance module address
                ),
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                      ELECTORAL MANDATES                          //
        //////////////////////////////////////////////////////////////////////

        // CLAIM MEMBERSHIP PARENT DAO // -- on the basis of activity token and POAP ownership.
        // Public: Check ownership POAPS.
        // insert: all tokens owned.
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = public
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Request Membership Step 1: 2 POAPS from physical DAO and 20 activity tokens from ideas DAOs needed that are not older than 6 months.",
                targetMandate: initialisePowers.getInitialisedAddress("Soulbound1155_GatedAccess"),
                config: abi.encode(
                    address(soulbound1155), // soulbound token contract
                    type(uint256).max - 1, // assigns a nonsense role Id. This mandate is just to check ownership of tokens.
                    3, // checks if token is from address that is a Physical sub-DAO
                    daysToBlocks(180, config.BLOCKS_PER_HOUR), // look back period in blocks = 30 days.
                    2 // number of tokens required
                ),
                conditions: conditions
            })
        );
        delete conditions;

        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = public
        conditions.needFulfilled = mandateCount - 1; // need the previous mandate to be fulfilled.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Request Membership Step 2: 2 POAPS from physical DAO and 20 activity tokens from ideas DAOs needed that are not older than 6 months.",
                targetMandate: initialisePowers.getInitialisedAddress("Soulbound1155_GatedAccess"),
                config: abi.encode(
                    address(soulbound1155), // soulbound token contract
                    1, // member role Id
                    4, // checks if token is from address that is an Ideas sub-DAO
                    daysToBlocks(180, config.BLOCKS_PER_HOUR), // look back period in blocks = 30 days.
                    20 // number of tokens required
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // ELECT EXECUTIVES //
        inputParams = new string[](3);
        inputParams[0] = "string Title";
        inputParams[1] = "uint48 StartBlock";
        inputParams[2] = "uint48 EndBlock";

        // Members: create election
        mandateCount++;
        conditions.allowedRole = 1; // = Members (should be Executives according to MD, but code says Members)
        conditions.throttleExecution = minutesToBlocks(120, config.BLOCKS_PER_HOUR); // = once every 2 hours
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Create an election: an election can be initiated be any member.",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    ElectionList.createElection.selector, // selector
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Nominate for Executive election
        mandateCount++;
        conditions.allowedRole = 1; // = Members (should be Executives according to MD, but code says Members)
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate for election: any member can nominate for an election.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Nominate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    true // nominate as candidate
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members revoke nomination for Executive election.
        mandateCount++;
        conditions.allowedRole = 1; // = Members (should be Executives according to MD, but code says Members)
        conditions.needFulfilled = mandateCount - 1; // = Nominate for election
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke nomination for election: any member can revoke their nomination for an election.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Nominate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    false // revoke nomination
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Open Vote for election
        mandateCount++;
        conditions.allowedRole = 1; // = Members
        conditions.needFulfilled = mandateCount - 3; // = Create election
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Open voting for election: Members can open the vote for an election. This will create a dedicated vote mandate.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_CreateVoteMandate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    initialisePowers.getInitialisedAddress("ElectionList_Vote"), // the vote mandate address
                    1, // the max number of votes a voter can cast
                    1 // the role Id allowed to vote (Members)
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Tally election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1; // = Open Vote election
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Tally elections: After an election has finished, assign the Executive role to the winners.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Tally"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"),
                    2, // RoleId for Executives
                    5 // Max role holders
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: clean up election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1; // = Tally election
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Clean up election: After an election has finished, clean up related mandates.",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_OnReturnValue"),
                config: abi.encode(
                    address(primaryDAO), // target contract
                    IPowers.revokeMandate.selector, // function selector to call
                    abi.encode(), // params before
                    new string[](0), // dynamic params: none (return value is used directly)
                    mandateCount - 2, // parent mandate id (the open vote  mandate)
                    abi.encode() // no params after
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // VOTE OF NO CONFIDENCE // 
        // very similar to elect executives, but no throttle, higher threshold and ALL executives get role revoked the moment the first mandate passes.
        inputParams = new string[](3);
        inputParams[0] = "string Title";
        inputParams[1] = "uint48 StartBlock";
        inputParams[2] = "uint48 EndBlock";

        // Members: Vote of No Confidence 
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = 5 minutes / days
        conditions.succeedAt = 77; // high majority
        conditions.quorum = 60; // = high quorum 
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Vote of No Confidence: Revoke Executive statuses.",
                targetMandate: initialisePowers.getInitialisedAddress("RevokeAccountsRoleId"),
                config: abi.encode(
                    2, // roleId
                    inputParams // the input params to fill out.
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: create election
        mandateCount++;
        conditions.allowedRole = 1; // = Members (should be Executives according to MD, but code says Members)
        conditions.needFulfilled = mandateCount - 1; // = previous Vote of No Confidence mandate. Note: NO throttle on this one.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Create an election: an election can be initiated be any member.",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    ElectionList.createElection.selector, // selector
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Nominate for Executive election
        mandateCount++;
        conditions.allowedRole = 1; // = Members (should be Executives according to MD, but code says Members)
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate for election: any member can nominate for an election.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Nominate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    true // nominate as candidate
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members revoke nomination for Executive election.
        mandateCount++;
        conditions.allowedRole = 1; // = Members (should be Executives according to MD, but code says Members)
        conditions.needFulfilled = mandateCount - 1; // = Nominate for election
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke nomination for election: any member can revoke their nomination for an election.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Nominate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    false // revoke nomination
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Open Vote for election
        mandateCount++;
        conditions.allowedRole = 1; // = Members
        conditions.needFulfilled = mandateCount - 3; // = Create election
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Open voting for election: Members can open the vote for an election. This will create a dedicated vote mandate.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_CreateVoteMandate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    initialisePowers.getInitialisedAddress("ElectionList_Vote"), // the vote mandate address
                    1, // the max number of votes a voter can cast
                    1 // the role Id allowed to vote (Members)
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Tally election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1; // = Open Vote election
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Tally elections: After an election has finished, assign the Executive role to the winners.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Tally"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"),
                    2, // RoleId for Executives
                    5 // Max role holders
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: clean up election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1; // = Tally election
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Clean up election: After an election has finished, clean up related mandates.",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_OnReturnValue"),
                config: abi.encode(
                    address(primaryDAO), // target contract
                    IPowers.revokeMandate.selector, // function selector to call
                    abi.encode(), // params before
                    new string[](0), // dynamic params: none (return value is used directly)
                    mandateCount - 2, // parent mandate id (the open vote  mandate)
                    abi.encode() // no params after
                ),
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                        REFORM MANDATES                           //
        //////////////////////////////////////////////////////////////////////

        // ADOPT MANDATE //
        string[] memory adoptMandatesParams = new string[](2);
        adoptMandatesParams[0] = "address[] mandates";
        adoptMandatesParams[1] = "uint256[] roleIds";

        // Any executive: Propose Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 2; // Executives
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initiate mandate adoption: Any executive can propose adopting new mandates into the organization.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Veto Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 1; // Members
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 66;
        conditions.quorum = 77;
        conditions.needFulfilled = mandateCount - 1;
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Adopting Mandates: Members can veto proposals to adopt new mandates",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Physical sub-DAOs: Ok Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 3; // Physical sub-DAO
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 51;
        conditions.quorum = 20;
        conditions.needFulfilled = mandateCount - 2;
        conditions.needNotFulfilled = mandateCount - 1;
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Ok adopting Mandates: Ok to adopt new mandates into the organization",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Ideas sub-DAOs: Ok Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 4; // Ideas sub-DAO
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 51;
        conditions.quorum = 20;
        conditions.needFulfilled = mandateCount - 1;
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Ok adopting Mandates: Ok to adopt new mandates into the organization",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Digital sub-DAO: Ok Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 5; // Digital sub-DAO
        conditions.needFulfilled = mandateCount - 1;
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Ok adopting Mandates: Ok to adopt new mandates into the organization",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Executives: Adopt Mandates
        mandateCount++;
        conditions.allowedRole = 2; // Executives
        conditions.needFulfilled = mandateCount - 1;
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 66;
        conditions.quorum = 80;
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Adopt new Mandates: Executives can adopt new mandates into the organization",
                targetMandate: initialisePowers.getInitialisedAddress("Mandates_Adopt"),
                config: abi.encode(),
                conditions: conditions
            })
        );
        delete conditions;
    }

    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    //                       DIGITAL DAO CONSTITUTION                         //
    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////

    function createDigitalConstitution() internal {
        mandateCount = 0; // resetting mandate count. // there are 2 initial mandates already in the digital DAO.
        //////////////////////////////////////////////////////////////////////
        //                              SETUP                               //
        //////////////////////////////////////////////////////////////////////
        // setup role labels //
        targets = new address[](6);
        values = new uint256[](6);
        calldatas = new bytes[](6);
        for (uint256 i = 0; i < targets.length; i++) {
            targets[i] = address(digitalSubDAO);
        }
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Members");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Conveners"); 
        calldatas[2] = abi.encodeWithSelector(IPowers.assignRole.selector, 1, cedars);
        calldatas[3] = abi.encodeWithSelector(IPowers.assignRole.selector, 2, cedars);
        calldatas[4] = abi.encodeWithSelector(IPowers.assignRole.selector, 3, cedars);
        calldatas[5] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1); // revoke mandate 1 after use.

        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = public.
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initial Setup: Assign role labels and revokes itself after execution",
                targetMandate: initialisePowers.getInitialisedAddress("PresetActions_Single"),
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                      EXECUTIVE MANDATES                          //
        //////////////////////////////////////////////////////////////////////

        // REQUEST ALLOWANCES FROM PRIME DAO //
        string[] memory inputParams = new string[](5);
        inputParams[0] = "address Sub-DAO";
        inputParams[1] = "address Token";
        inputParams[2] = "uint96 allowanceAmount";
        inputParams[3] = "uint16 resetTimeMin";
        inputParams[4] = "uint32 resetBaseMin";
 
        // Members: Veto request allowance from Primary DAO
        mandateCount++;
        conditions.allowedRole = 1; // Members 
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto request allowance: Members can veto a request for additional allowance", //
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Conveners: Request allowance from Primary DAO
        mandateCount++;
        conditions.allowedRole = 2; // Conveners 
        conditions.needNotFulfilled = mandateCount - 1;
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 66;
        conditions.quorum = 80;
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Request allowance: Conveners can request an allowance from the Primary DAO Safe Treasury.",
                targetMandate: initialisePowers.getInitialisedAddress("PowersAction_Simple"),
                config: abi.encode(
                    address(primaryDAO), // target contract
                    requestAllowanceDigitalDAOId, // parent mandate id (the request allowance at primary DAO mandate)
                    inputParams // dynamic params (the address of the created Ideas sub-DAO)
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // PAYMENT OF RECEIPTS //
        inputParams = new string[](3);
        inputParams[0] = "address Token";
        inputParams[1] = "uint256 Amount";
        inputParams[2] = "address PayableTo";

        // Public: Submit a receipt (Payment Reimbursement - After Action)
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // This is a public mandate. Anyone can call it.
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Submit a Receipt: Anyone can submit a receipt for payment reimbursement.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Conveners: OK Receipt (Avoid Spam)
        mandateCount++;
        conditions.allowedRole = 2; // Any convener can ok a receipt.
        conditions.needFulfilled = mandateCount - 1; // need the previous mandate to be fulfilled.
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "OK a receipt: Any convener can ok a receipt for payment reimbursement.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Conveners: Approve Payment of Receipt
        mandateCount++;
        conditions.allowedRole = 2; // Conveners
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 67;
        conditions.quorum = 50;
        conditions.needFulfilled = mandateCount - 1; // need the previous mandate to be fulfilled.
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Approve payment of receipt: Execute a transaction from the Safe Treasury.",
                targetMandate: initialisePowers.getInitialisedAddress("SafeAllowance_Transfer"),
                config: abi.encode(config.safeAllowanceModule, address(treasury)),
                conditions: conditions
            })
        );
        delete conditions;

        // PAYMENT OF PROJECTS //
        inputParams = new string[](3);
        inputParams[0] = "address Token";
        inputParams[1] = "uint256 Amount";
        inputParams[2] = "address PayableTo";

        // Members: Submit a project (Payment Before Action)
        mandateCount++;
        conditions.allowedRole = 1; // Members can propose a project.
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 51;
        conditions.quorum = 5; // note the low quorum to encourage proposals.
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Submit a project for Funding: Any member can submit a project for funding.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Conveners: Approve Funding of Project
        mandateCount++;
        conditions.allowedRole = 2; // Conveners
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 67;
        conditions.quorum = 50;
        conditions.needFulfilled = mandateCount - 1; // need the previous mandate to be fulfilled.
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Approve funding of project: Execute a transaction from the Safe Treasury.",
                targetMandate: initialisePowers.getInitialisedAddress("SafeAllowance_Transfer"),
                config: abi.encode(config.safeAllowanceModule, address(treasury)),
                conditions: conditions
            })
        );
        delete conditions;

        // UPDATE URI //
        inputParams = new string[](1);
        inputParams[0] = "string newUri";

        // Conveners: Update URI
        mandateCount++;
        conditions.allowedRole = 2; // = Conveners
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = 5 minutes / days
        conditions.succeedAt = 66; // = 2/3 majority
        conditions.quorum = 66; // = 66% quorum
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Update URI: Set allowed token for Physical sub-DAO",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_OnOwnPowers"),
                config: abi.encode(
                    Powers.setUri.selector, // function selector to call
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // TRANSFER TOKENS INTO TREASURY //
        mandateCount++;
        conditions.allowedRole = 2; // = Conveners. Any convener can call this mandate.
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Transfer tokens to treasury: Any tokens accidently sent to the DAO can be recovered by sending them to the treasury",
                targetMandate: initialisePowers.getInitialisedAddress("Safe_RecoverTokens"),
                config: abi.encode(
                    treasury, // this should be the safe treasury!
                    config.safeAllowanceModule // allowance module address
                ),
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                      ELECTORAL MANDATES                          //
        //////////////////////////////////////////////////////////////////////

        // ASSIGN MEMBERSHIP // -- on the basis of contributions to website
        // TODO: needs to be configured with github repo details etc.
        string[] memory paths = new string[](3);
        paths[0] = "documentation"; // can be anything
        paths[1] = "frontend";
        paths[2] = "solidity";
        uint256[] memory roleIds = new uint256[](3);
        roleIds[0] = 2;
        roleIds[1] = 3;
        roleIds[2] = 4;

        // Public: Apply for member role
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // Public
        conditions.throttleExecution = minutesToBlocks(3, config.BLOCKS_PER_HOUR); // to avoid spamming, the law is throttled.
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Apply for Member Role: Anyone can claim member roles based on their GitHub contributions to the DAO's repository", // crrently the path is set at cedars/powers
                targetMandate: initialisePowers.getInitialisedAddress("Github_ClaimRoleWithSig"), // TODO: needs to be more configurable
                config: abi.encode(
                    "develop", // branch
                    paths,
                    roleIds,
                    "signed", // signatureString
                    config.chainlinkFunctionsSubscriptionId,
                    config.chainlinkFunctionsGasLimit,
                    config.chainlinkFunctionsDonId
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Public: Claim Member Role
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // Public
        conditions.needFulfilled = mandateCount - 1; // must have applied for member role.
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Claim Member Role: Following a successful initial claim, members can get member role assigned to their account.",
                targetMandate: initialisePowers.getInitialisedAddress("Github_AssignRoleWithSig"),
                config: abi.encode(), // empty config
                conditions: conditions
            })
        );
        delete conditions;

        // ELECT CONVENERS //
        inputParams = new string[](3);
        inputParams[0] = "string Title";
        inputParams[1] = "uint48 StartBlock";
        inputParams[2] = "uint48 EndBlock";

        // Members: create election
        mandateCount++;
        conditions.allowedRole = 1; // = Members
        conditions.throttleExecution = minutesToBlocks(120, config.BLOCKS_PER_HOUR); // = once every 2 hours
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Create an election: an election can be initiated be any member.",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    ElectionList.createElection.selector, // selector
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Nominate for Convener election
        mandateCount++;
        conditions.allowedRole = 1; // = Members
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate for election: any member can nominate for an election.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Nominate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    true // nominate as candidate
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members revoke nomination for Convener election.
        mandateCount++;
        conditions.allowedRole = 1; // = Members
        conditions.needFulfilled = mandateCount - 1; // = Nominate for election
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke nomination for election: any member can revoke their nomination for an election.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Nominate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    false // revoke nomination
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Open Vote for election
        mandateCount++;
        conditions.allowedRole = 1; // = Members
        conditions.needFulfilled = mandateCount - 3; // = Create election
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Open voting for election: Members can open the vote for an election. This will create a dedicated vote mandate.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_CreateVoteMandate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    initialisePowers.getInitialisedAddress("ElectionList_Vote"), // the vote mandate address
                    1, // the max number of votes a voter can cast
                    1 // the role Id allowed to vote (Members)
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Tally election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1; // = Open Vote election
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Tally elections: After an election has finished, assign the Convener role to the winners.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Tally"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"),
                    2, // RoleId for Conveners
                    3 // Max role holders
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: clean up election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1; // = Tally election
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Clean up election: After an election has finished, clean up related mandates.",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_OnReturnValue"),
                config: abi.encode(
                    address(digitalSubDAO), // target contract
                    IPowers.revokeMandate.selector, // function selector to call
                    abi.encode(), // params before
                    new string[](0), // dynamic params: none
                    mandateCount - 2, // parent mandate id (the open vote mandate)
                    abi.encode() // no params after
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // VOTE OF NO CONFIDENCE // 
        // very similar to elect conveners, but no throttle, higher threshold and ALL executives get role revoked the moment the first mandate passes.
        inputParams = new string[](3);
        inputParams[0] = "string Title";
        inputParams[1] = "uint48 StartBlock";
        inputParams[2] = "uint48 EndBlock";

        // Members: Vote of No Confidence 
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = 5 minutes / days
        conditions.succeedAt = 77; // high majority
        conditions.quorum = 60; // = high quorum 
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Vote of No Confidence: Revoke Convener statuses.",
                targetMandate: initialisePowers.getInitialisedAddress("RevokeAccountsRoleId"),
                config: abi.encode(
                    2, // roleId
                    inputParams // the input params to fill out.
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: create election
        mandateCount++;
        conditions.allowedRole = 1; // = Members (should be Convener according to MD, but code says Members)
        conditions.needFulfilled = mandateCount - 1; // = previous Vote of No Confidence mandate. Note: NO throttle on this one.
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Create an election: an election can be initiated be any member.",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    ElectionList.createElection.selector, // selector
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Nominate for Executive election
        mandateCount++;
        conditions.allowedRole = 1; // = Members (should be Conveners according to MD, but code says Members)
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate for election: any member can nominate for an election.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Nominate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    true // nominate as candidate
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members revoke nomination for Executive election.
        mandateCount++;
        conditions.allowedRole = 1; // = Members (should be Conveners according to MD, but code says Members)
        conditions.needFulfilled = mandateCount - 1; // = Nominate for election
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke nomination for election: any member can revoke their nomination for an election.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Nominate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    false // revoke nomination
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Open Vote for election
        mandateCount++;
        conditions.allowedRole = 1; // = Members
        conditions.needFulfilled = mandateCount - 3; // = Create election
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Open voting for election: Members can open the vote for an election. This will create a dedicated vote mandate.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_CreateVoteMandate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    initialisePowers.getInitialisedAddress("ElectionList_Vote"), // the vote mandate address
                    1, // the max number of votes a voter can cast
                    1 // the role Id allowed to vote (Members)
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Tally election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1; // = Open Vote election
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Tally elections: After an election has finished, assign the Convener role to the winners.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Tally"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"),
                    2, // RoleId for Conveners
                    5 // Max role holders
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: clean up election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1; // = Tally election
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Clean up election: After an election has finished, clean up related mandates.",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_OnReturnValue"),
                config: abi.encode(
                    address(primaryDAO), // target contract
                    IPowers.revokeMandate.selector, // function selector to call
                    abi.encode(), // params before
                    new string[](0), // dynamic params: none (return value is used directly)
                    mandateCount - 2, // parent mandate id (the open vote  mandate)
                    abi.encode() // no params after
                ),
                conditions: conditions
            })
        );
        delete conditions;


        //////////////////////////////////////////////////////////////////////
        //                        REFORM MANDATES                           //
        //////////////////////////////////////////////////////////////////////

        // ADOPT MANDATES //
        string[] memory adoptMandatesParams = new string[](2);
        adoptMandatesParams[0] = "address[] mandates";
        adoptMandatesParams[1] = "uint256[] roleIds";

        // Members: initiate Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 1; // Members
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 66;
        conditions.quorum = 77;
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initiate Adopting Mandates: Members can initiate adopting new mandates",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        // PrimaryDAO: Veto Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 0; // PrimaryDAO = Admin. 
        conditions.needFulfilled = mandateCount - 1;
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Adopting Mandates: PrimaryDAO can veto proposals to adopt new mandates", // TODO: PrimaryDAO actually does not have a law yet to cast a veto..
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        // // Conveners: Adopt Mandates
        mandateCount++;
        conditions.allowedRole = 2; // Conveners
        conditions.needFulfilled = mandateCount - 2;
        conditions.needNotFulfilled = mandateCount - 1;
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 66;
        conditions.quorum = 80;
        digitalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Adopt new Mandates: Conveners can adopt new mandates into the organization",
                targetMandate: initialisePowers.getInitialisedAddress("Mandates_Adopt"),
                config: abi.encode(),
                conditions: conditions
            })
        );
        delete conditions;
    }

    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    //                        IDEAS DAO CONSTITUTION                          //
    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////

    function createIdeasConstitution() internal {
        mandateCount = 0; // resetting mandate count.
        //////////////////////////////////////////////////////////////////////
        //                      EXECUTIVE MANDATES                          //
        //////////////////////////////////////////////////////////////////////
        // SET ROLE LABELS //
        inputParams = new string[](2);
        inputParams[0] = "uint256 RoleId";
        inputParams[1] = "string Label";

        // Role 1: Veto setting role labels
        mandateCount++;
        conditions.allowedRole = 1; // = Members.
        conditions.quorum = 30; //  
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minutes to vote
        conditions.succeedAt = 67; // two thirds majority
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto setting role labels: Role 1 can veto setting role labels",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Role 2: Set role labels
        mandateCount++;
        conditions.allowedRole = 2; // = Conveners.
        conditions.quorum = 51; // simple majority
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minutes to vote
        conditions.succeedAt = 51; // simple majority
        conditions.timelock = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minute timelock after passing
        conditions.needNotFulfilled = mandateCount - 1; // need role 1 not to have vetoed.
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Setting role label: Role 2 (coveners) can set role labels",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_OnOwnPowers"),
                config: abi.encode(
                    IPowers.labelRole.selector, // this should be the safe treasury!
                    inputParams // allowance module address
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // MINT ACTIVITY TOKENS //
        inputParams = new string[](1);
        inputParams[0] = "address To";

        // Public: Mint an active ideas token
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = Public
        conditions.throttleExecution = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // note: the more people try to gain access, the harder it will be to get as supply is fixed.
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Mint activity token: Anyone can mint an Active Ideas token. One token is available per 5 minutes.",
                targetMandate: initialisePowers.getInitialisedAddress("PowersAction_Simple"),
                config: abi.encode(
                    address(primaryDAO), 
                    mintActivityTokenId, // parent mandate id (the mint activity token at primary DAO mandate)
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // REQUEST CREATION NEW PHYSICAL DAO
        inputParams = new string[](2);
        inputParams[0] = "string name";
        inputParams[1] = "string uri";

        // Conveners: request at Primary DAO the creation of a new physical DAO.
        // Note: this is a statement of intent. Physical DAOs are requested using a working group, after initated here by conveners.
        mandateCount++;
        conditions.allowedRole = 2; // = Conveners
        conditions.quorum = 51; // simple majority
        conditions.votingPeriod = minutesToBlocks(10, config.BLOCKS_PER_HOUR); // 10 minutes to vote
        conditions.succeedAt = 51; // simple majority
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initiate request new Physical sub-DAO: Conveners can request creation new Physical sub-DAO.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode( 
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;
        uint16 requestNewPhysicalDaoWorkingGroupMandateId = mandateCount;

        // CREATE NEW IDEAS WORKING GROUP FLOW //  
        // NB
        // conveners: create governance flow for creating new working groups within the idea DAO.
        PowersTypes.MandateInitData[] memory workingGroupFlow = new PowersTypes.MandateInitData[](7);
            // Step 1: call to Primary DAO to create new Physical sub-DAO. - needfulfilled requestNewPhysicalDaoWorkingGroupMandateId.
            conditions.needFulfilled = requestNewPhysicalDaoWorkingGroupMandateId;
            conditions.allowedRole = 0; // = NB! this is the INDEX of the roleIds supplied when calling this function! 
            conditions.quorum = 51; // simple majority
            conditions.votingPeriod = minutesToBlocks(10, config.BLOCKS_PER_HOUR); // 10 minutes to vote
            conditions.succeedAt = 51; // simple majority
            workingGroupFlow[0] = PowersTypes.MandateInitData({
                nameDescription: "Request new Physical sub-DAO: Working group members can request creation new Physical sub-DAO.",
                targetMandate: initialisePowers.getInitialisedAddress("PowersAction_Simple"),
                config: abi.encode( 
                    address(primaryDAO),
                    requestNewPhysicalDaoId, // parent mandate id (the create new physical sub-DAO at primary DAO mandate)
                    inputParams
                ),
                conditions: conditions
            }); 
            delete conditions;

            // Step 2-6: election for working group members. 
            // ELECT WORKING GROUP MEMBERS //
            inputParams = new string[](3);
            inputParams[0] = "string Title";
            inputParams[1] = "uint48 StartBlock";
            inputParams[2] = "uint48 EndBlock";

            // Members: create election
            conditions.allowedRole = 1; // = Members
            conditions.throttleExecution = minutesToBlocks(120, config.BLOCKS_PER_HOUR); // = once every 2 hours
            workingGroupFlow[1] = PowersTypes.MandateInitData({
                nameDescription: "Create an WG election: an election can be initiated be any member.",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    ElectionList.createElection.selector, // selector
                    inputParams
                ),
                conditions: conditions
            });
            delete conditions;

            // Members: Nominate for Convener election
            conditions.allowedRole = 1; // = Members
            workingGroupFlow[2] = PowersTypes.MandateInitData({
                nameDescription: "Nominate for WG election: any member can nominate for an election.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Nominate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    true // nominate as candidate
                ),
                conditions: conditions
            });
            delete conditions;

            // Members revoke nomination for Convener election.
            conditions.allowedRole = 1; // = Members
            conditions.needFulfilled = 2; // number will be automatically adjusted = nominate for election
            workingGroupFlow[3] = PowersTypes.MandateInitData({
                nameDescription: "Revoke nomination for WG election: any member can revoke their nomination for an election.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Nominate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    false // revoke nomination
                ),
                conditions: conditions
            }); 
            delete conditions;

            // Members: Open Vote for election
            conditions.allowedRole = 1; // = Members
            conditions.needFulfilled = 1; // = Create election 
            workingGroupFlow[4] = PowersTypes.MandateInitData({
                nameDescription: "Open voting for WG election: Members can open the vote for an election. This will create a dedicated vote mandate.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_CreateVoteMandate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    initialisePowers.getInitialisedAddress("ElectionList_Vote"), // the vote mandate address
                    1, // the max number of votes a voter can cast
                    1 // the role Id allowed to vote (Members)
                ),
                conditions: conditions
            });
            delete conditions;

            // Members: Tally election
            conditions.allowedRole = 1;
            conditions.needFulfilled = 4; // = Open Vote election
            workingGroupFlow[5] = PowersTypes.MandateInitData({
                nameDescription: "Tally elections: After an election has finished, assign the Convener role to the winners.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Tally"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"),
                    2, // RoleId for Conveners
                    3 // Max role holders
                ),
                conditions: conditions
            });
            delete conditions;

            // Members: clean up election
            conditions.allowedRole = 1;
            conditions.needFulfilled = 5; // = Tally election
            workingGroupFlow[6] = PowersTypes.MandateInitData({
                nameDescription: "Clean up election: After an election has finished, clean up related mandates.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_CleanUpVoteMandate"),
                config: abi.encode(mandateCount - 2), // The create vote mandate)
                conditions: conditions
            });
            delete conditions;

        mandateCount++;
        conditions.allowedRole = 2; // = Conveners
        conditions.quorum = 51; // simple majority
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minutes to vote
        conditions.succeedAt = 51; // simple majority
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Create new Working group: Conveners can create new Working group.",
                targetMandate: initialisePowers.getInitialisedAddress("Mandates_Prepackaged"),
                config: abi.encode(workingGroupFlow),
                conditions: conditions
            })
        );
        delete conditions; 


        // UPDATE URI //
        inputParams = new string[](1);
        inputParams[0] = "string newUri";

        // Conveners: Update URI
        mandateCount++;
        conditions.allowedRole = 2; // = Conveners
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = 5 minutes / days
        conditions.succeedAt = 66; // = 2/3 majority
        conditions.quorum = 66; // = 66% quorum
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Update URI: Set allowed token for Physical sub-DAO",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_OnOwnPowers"),
                config: abi.encode(
                    Powers.setUri.selector, // function selector to call
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // TRANSFER TOKENS INTO TREASURY //
        mandateCount++;
        conditions.allowedRole = 2; // = Conveners. Any convener can call this mandate.
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Transfer tokens to treasury: Any tokens accidently sent to the DAO can be recovered by sending them to the treasury",
                targetMandate: initialisePowers.getInitialisedAddress("Safe_RecoverTokens"),
                config: abi.encode(
                    treasury, // this should be the safe treasury!
                    config.safeAllowanceModule // allowance module address
                ),
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                      ELECTORAL MANDATES                          //
        //////////////////////////////////////////////////////////////////////
        // ASSIGN MEMBERSHIP // -- on the basis of collected tokens from the org.
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = public
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Request Membership: Anyone can become a member if they have sufficient activity token from the DAO: 5 tokens during the last 30 days.",
                targetMandate: initialisePowers.getInitialisedAddress("Soulbound1155_GatedAccess"),
                config: abi.encode(
                    address(soulbound1155), // soulbound token contract
                    1, // member role Id
                    0, // checks if token is from address that holds role Id 0 (meaning the admin, which is the DAO itself).
                    5, // number of tokens required
                    daysToBlocks(30, config.BLOCKS_PER_HOUR) // look back period in blocks = 30 days.
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // ELECT CONVENERS //
        inputParams = new string[](3);
        inputParams[0] = "string Title";
        inputParams[1] = "uint48 StartBlock";
        inputParams[2] = "uint48 EndBlock";

        // Members: create election
        mandateCount++;
        conditions.allowedRole = 1; // = Members
        conditions.throttleExecution = minutesToBlocks(120, config.BLOCKS_PER_HOUR); // = once every 2 hours
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Create an election: an election can be initiated be any member.",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    ElectionList.createElection.selector, // selector
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Nominate for Convener election
        mandateCount++;
        conditions.allowedRole = 1; // = Members
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate for election: any member can nominate for an election.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Nominate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    true // nominate as candidate
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members revoke nomination for Convener election.
        mandateCount++;
        conditions.allowedRole = 1; // = Members
        conditions.needFulfilled = mandateCount - 1; // = Nominate for election
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke nomination for election: any member can revoke their nomination for an election.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Nominate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    false // revoke nomination
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Open Vote for election
        mandateCount++;
        conditions.allowedRole = 1; // = Members
        conditions.needFulfilled = mandateCount - 3; // = Create election
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Open voting for election: Members can open the vote for an election. This will create a dedicated vote mandate.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_CreateVoteMandate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    initialisePowers.getInitialisedAddress("ElectionList_Vote"), // the vote mandate address
                    1, // the max number of votes a voter can cast
                    1 // the role Id allowed to vote (Members)
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Tally election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1; // = Open Vote election
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Tally elections: After an election has finished, assign the Convener role to the winners.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Tally"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"),
                    2, // RoleId for Conveners
                    3 // Max role holders
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: clean up election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1; // = Tally election
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Clean up election: After an election has finished, clean up related mandates.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_CleanUpVoteMandate"),
                config: abi.encode(mandateCount - 2), // The create vote mandate)
                conditions: conditions
            })
        );
        delete conditions;

        // VOTE OF NO CONFIDENCE // 
        // very similar to elect conveners, but no throttle, higher threshold and ALL executives get role revoked the moment the first mandate passes.
        inputParams = new string[](3);
        inputParams[0] = "string Title";
        inputParams[1] = "uint48 StartBlock";
        inputParams[2] = "uint48 EndBlock";

        // Members: Vote of No Confidence 
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = 5 minutes / days
        conditions.succeedAt = 77; // high majority
        conditions.quorum = 60; // = high quorum 
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Vote of No Confidence: Revoke Convener statuses.",
                targetMandate: initialisePowers.getInitialisedAddress("RevokeAccountsRoleId"),
                config: abi.encode(
                    2, // roleId
                    inputParams // the input params to fill out.
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: create election
        mandateCount++;
        conditions.allowedRole = 1; // = Members (should be Convener according to MD, but code says Members)
        conditions.needFulfilled = mandateCount - 1; // = previous Vote of No Confidence mandate. Note: NO throttle on this one.
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Create an election: an election can be initiated be any member.",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    ElectionList.createElection.selector, // selector
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Nominate for Executive election
        mandateCount++;
        conditions.allowedRole = 1; // = Members (should be Conveners according to MD, but code says Members)
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate for election: any member can nominate for an election.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Nominate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    true // nominate as candidate
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members revoke nomination for Executive election.
        mandateCount++;
        conditions.allowedRole = 1; // = Members (should be Conveners according to MD, but code says Members)
        conditions.needFulfilled = mandateCount - 1; // = Nominate for election
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke nomination for election: any member can revoke their nomination for an election.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Nominate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    false // revoke nomination
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Open Vote for election
        mandateCount++;
        conditions.allowedRole = 1; // = Members
        conditions.needFulfilled = mandateCount - 3; // = Create election
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Open voting for election: Members can open the vote for an election. This will create a dedicated vote mandate.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_CreateVoteMandate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    initialisePowers.getInitialisedAddress("ElectionList_Vote"), // the vote mandate address
                    1, // the max number of votes a voter can cast
                    1 // the role Id allowed to vote (Members)
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Tally election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1; // = Open Vote election
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Tally elections: After an election has finished, assign the Convener role to the winners.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Tally"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"),
                    2, // RoleId for Conveners
                    5 // Max role holders
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: clean up election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1; // = Tally election
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Clean up election: After an election has finished, clean up related mandates.",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_OnReturnValue"),
                config: abi.encode(
                    address(primaryDAO), // target contract
                    IPowers.revokeMandate.selector, // function selector to call
                    abi.encode(), // params before
                    new string[](0), // dynamic params: none (return value is used directly)
                    mandateCount - 2, // parent mandate id (the open vote  mandate)
                    abi.encode() // no params after
                ),
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                        REFORM MANDATES                           //
        //////////////////////////////////////////////////////////////////////

        // Adopt mandate //
        inputParams = new string[](2);
        inputParams[0] = "address[] mandates";
        inputParams[1] = "uint256[] roleIds";

        // Members: Veto Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 1; // Members
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 66;
        conditions.quorum = 77;
        conditions.needFulfilled = mandateCount - 1;
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Adopting Mandates: Members can veto proposals to adopt new mandates",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Conveners: Adopt Mandates
        mandateCount++;
        conditions.allowedRole = 2; // Conveners
        conditions.needFulfilled = mandateCount - 1;
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 66;
        conditions.quorum = 80;
        ideasConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Adopt new Mandates: Conveners can adopt new mandates into the organization",
                targetMandate: initialisePowers.getInitialisedAddress("Mandates_Adopt"),
                config: abi.encode(),
                conditions: conditions
            })
        );
        delete conditions;
    }

    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    //                       PHYSICAL DAO CONSTITUTION                        //
    //////////////////////////////////////////////////////////////////////////// 
    ////////////////////////////////////////////////////////////////////////////

    function createPhysicalConstitution() internal {
        mandateCount = 0; // resetting mandate count.
        //////////////////////////////////////////////////////////////////////
        //                              SETUP                               //
        //////////////////////////////////////////////////////////////////////
        // SETUP PAYMENT FLOW //
        // Role 1: Veto setting role labels
        mandateCount++;
        conditions.allowedRole = 2; // = Any convener.
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Setup Payment Flow: Any convener can setup the payment flow for the physical DAO.",
                targetMandate: initialisePowers.getInitialisedPackageAddress("CulturalStewards_PaymentSequence"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                      EXECUTIVE MANDATES                          //
        //////////////////////////////////////////////////////////////////////
        // SET ROLE LABELS //
        inputParams = new string[](2);
        inputParams[0] = "uint256 RoleId";
        inputParams[1] = "string Label";

        // Role 1: Veto setting role labels
        mandateCount++;
        conditions.allowedRole = 1; // = Members.
        conditions.quorum = 30; //  
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minutes to vote
        conditions.succeedAt = 67; // two thirds majority
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto setting role labels: Role 1 can veto setting role labels",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Role 2: Set role labels
        mandateCount++;
        conditions.allowedRole = 2; // = Conveners.
        conditions.quorum = 20; //
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minutes to vote
        conditions.succeedAt = 51; // simple majority
        conditions.timelock = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minute timelock after passing
        conditions.needNotFulfilled = mandateCount - 1; // need role 1 not to have vetoed.
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Setting role label: Role 2 (coveners) can set role labels",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_OnOwnPowers"),
                config: abi.encode(
                    IPowers.labelRole.selector, // this should be the safe treasury!
                    inputParams // allowance module address
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // CREATE NEW RWA TOKEN //
        inputParams = new string[](1); 
        inputParams[0] = "string Name";

        // role 1: veto creating RWA token
        mandateCount++;
        conditions.allowedRole = 1; // = Members.
        conditions.quorum = 40; //  
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minutes to vote
        conditions.succeedAt = 67; // two thirds majority
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto creating new RWA item: Role 1 can veto creating new RWA item",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // role 2: create RWA token
        mandateCount++;
        conditions.allowedRole = 2; // = Conveners.
        conditions.quorum = 20; //
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minutes to vote
        conditions.succeedAt = 51; // simple majority
        conditions.timelock = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minute timelock after passing
        conditions.needNotFulfilled = mandateCount - 1; // need role 1 not to have vetoed.
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Creating RWA token: Role 2 (conveners) can create RWA token",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("RwaMock"), // RWA token contract
                    RwaMock.createToken.selector, // 
                    inputParams // 
                ),
                conditions: conditions
            })
        );
        delete conditions;

    
        // SET COMPLIANCE TOKEN //
        inputParams = new string[](6); 
        inputParams[0] = "uint256 tokenId";
        inputParams[1] = "address from"; 
        inputParams[2] = "address to";
        inputParams[3] = "uint256 amount";
        inputParams[4] = "uint256 currentToBalance";
        inputParams[5] = "uint256 currentTotalSupply";

        // role 1: veto setting compliance token
        mandateCount++;
        conditions.allowedRole = 1; // = Members.
        conditions.quorum = 40; //  
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minutes to vote
        conditions.succeedAt = 67; // two thirds majority
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto setting compliance token: Role 1 can veto setting compliance token",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

         // role 2: set compliance token
        mandateCount++;
        conditions.allowedRole = 2; // = Conveners.
        conditions.quorum = 20; //
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minutes to vote
        conditions.succeedAt = 51; // simple majority
        conditions.timelock = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minute timelock after passing
        conditions.needNotFulfilled = mandateCount - 1; // need role 1 not to have vetoed.
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Setting compliance token: Role 2 (conveners) can set compliance token",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ComplianceRegistryMock"), // compliance registry contract
                    ComplianceRegistryMock.setComplianceChecks.selector, //  
                    inputParams // 
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // MINT AND TRANSFER RWA TOKEN TO TREASURY // 
        inputParams = new string[](3); 
        inputParams[0] = "address To";
        inputParams[1] = "uint256 TokenId";
        inputParams[2] = "uint256 Amount";

        // role 1: veto minting RWA token to treasury
        mandateCount++;
        conditions.allowedRole = 1; // = Members.
        conditions.quorum = 40;  
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minutes to vote
        conditions.succeedAt = 67; // two thirds majority
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto minting RWA token to treasury: Role 1 can veto minting RWA token to treasury",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // role 2: mint RWA token to treasury
        mandateCount++;
        conditions.allowedRole = 2; // = Conveners.
        conditions.quorum = 20; //
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minutes to vote
        conditions.succeedAt = 51; // simple majority
        conditions.timelock = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minute timelock after passing
        conditions.needNotFulfilled = mandateCount - 1; // need role 1 not to have vetoed.
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Minting RWA token to treasury: Role 2 (conveners) can mint RWA token to treasury",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("RwaMock"), // RWA token contract
                    RwaMock.mint.selector, // 
                    inputParams // 
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // TRANSFER RWA TOKEN TO THIRD PARTY //
        inputParams = new string[](5); 
        inputParams[0] = "address From";
        inputParams[1] = "address To";
        inputParams[2] = "uint256 TokenId";
        inputParams[3] = "uint256 Amount";
        inputParams[4] = "bytes Data";

        // role 1: veto transfer RWA token to third party
        mandateCount++;
        conditions.allowedRole = 1; // = Members.
        conditions.quorum = 40;  
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minutes to vote
        conditions.succeedAt = 67; // two thirds majority
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto transfer RWA token to third party: Role 1 can veto transfer RWA token to third party",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // role 2: transfer RWA token to third party
        mandateCount++;
        conditions.allowedRole = 2; // = Conveners.
        conditions.quorum = 20; //
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minutes to vote
        conditions.succeedAt = 51; // simple majority
        conditions.timelock = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minute timelock after passing
        conditions.needNotFulfilled = mandateCount - 1; // need role 1 not to have vetoed.
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Transfer RWA token to third party: Role 2 (conveners) can transfer RWA token to third party",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("RwaMock"), // RWA token contract
                    RwaMock.safeTransferFrom.selector, // 
                    inputParams // 
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // // FORCED TRANSFER RWA TO TREASURY //
        // // Note the higher thresholds for passing this governance flow. 
        // inputParams = new string[](4); 
        // inputParams[0] = "address From";
        // inputParams[1] = "address To";
        // inputParams[2] = "uint256 TokenId";
        // inputParams[3] = "uint256 Amount"; 

        // // role 1: veto forced transfer RWA token to treasury
        // // Lower threshold here: = easier to veto. 
        // mandateCount++;
        // conditions.allowedRole = 1; // = Members.
        // conditions.quorum = 20;  
        // conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minutes to vote
        // conditions.succeedAt = 51; // More than two thirds majority
        // physicalConstitution.push(
        //     PowersTypes.MandateInitData({
        //         nameDescription: "Veto forced transfer RWA token to treasury: Role 1 can veto forced transfer RWA token to treasury",
        //         targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
        //         config: abi.encode(inputParams),
        //         conditions: conditions
        //     })
        // );
        // delete conditions;

        // // role 2: forced transfer RWA token to treasury
        // // higher threshold here: = harder to pass.
        // mandateCount++;
        // conditions.allowedRole = 2; // = Conveners.
        // conditions.quorum = 40; //
        // conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minutes to vote
        // conditions.succeedAt = 67; // simple majority
        // conditions.timelock = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // 10 minute timelock after passing
        // conditions.needNotFulfilled = mandateCount - 1; // need role 1 not to have vetoed.
        // physicalConstitution.push(
        //     PowersTypes.MandateInitData({
        //         nameDescription: "Forced transfer RWA token to treasury: Role 2 (conveners) can transfer RWA token to treasury",
        //         targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
        //         config: abi.encode(
        //             initialisePowers.getInitialisedAddress("RwaMock"), // RWA token contract    
        //             RwaMock.safeTransferFrom.selector, // 
        //             inputParams // 
        //         ),
        //         conditions: conditions
        //     })
        // );
        // delete conditions;

        // MINT POAPS // 
        inputParams = new string[](1);
        inputParams[0] = "address To";

        // Convener: Mint POAP
        mandateCount++;
        conditions.allowedRole = 2; // = Conveners
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Mint POAP: Any Convener can mint a POAP.",
                targetMandate: initialisePowers.getInitialisedAddress("PowersAction_Simple"),
                config: abi.encode(
                    address(primaryDAO),
                    mintPoapTokenId, // parent mandate id (the mint POAP token at primary DAO mandate)
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // UPDATE URI //
        inputParams = new string[](1);
        inputParams[0] = "string newUri";

        // Conveners: Update URI
        mandateCount++;
        conditions.allowedRole = 2; // = Conveners
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = 5 minutes / days
        conditions.succeedAt = 66; // = 2/3 majority
        conditions.quorum = 66; // = 66% quorum
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Update URI: Set allowed token for Physical sub-DAO",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_OnOwnPowers"),
                config: abi.encode(
                    Powers.setUri.selector, // function selector to call
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // TRANSFER TOKENS INTO TREASURY //
        mandateCount++;
        conditions.allowedRole = 2; // = Conveners. Any convener can call this mandate.
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Transfer tokens to treasury: Any tokens accidently sent to the DAO can be recovered by sending them to the treasury",
                targetMandate: initialisePowers.getInitialisedAddress("Safe_RecoverTokens"),
                config: abi.encode(
                    treasury, // this should be the safe treasury!
                    config.safeAllowanceModule // allowance module address
                ),
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                      ELECTORAL MANDATES                          //
        //////////////////////////////////////////////////////////////////////
        // ASSIGN MEMBERSHIP // -- on the basis of POAPS.
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = public
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Request Membership: Anyone can become a member if they have sufficient activity token from the DAO: 1 tokens during the last 15 days.",
                targetMandate: initialisePowers.getInitialisedAddress("Soulbound1155_GatedAccess"),
                config: abi.encode(
                    address(soulbound1155), // soulbound token contract
                    1, // member role Id
                    0, // checks if token is from address that holds role Id 0 (meaning the admin, which is the DAO itself).
                    1, // number of tokens required. Only one POAP needed for membership.
                    daysToBlocks(15, config.BLOCKS_PER_HOUR) // look back period in blocks = 15 days.
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // ELECT CONVENERS //
        inputParams = new string[](3);
        inputParams[0] = "string Title";
        inputParams[1] = "uint48 StartBlock";
        inputParams[2] = "uint48 EndBlock";

        // Members: create election
        mandateCount++;
        conditions.allowedRole = 1; // = Members
        conditions.throttleExecution = minutesToBlocks(120, config.BLOCKS_PER_HOUR); // = once every 2 hours
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Create an election: an election can be initiated be any member.",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    ElectionList.createElection.selector, // selector
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Nominate for Convener election
        mandateCount++;
        conditions.allowedRole = 1; // = Members
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate for election: any member can nominate for an election.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Nominate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    true // nominate as candidate
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members revoke nomination for Convener election.
        mandateCount++;
        conditions.allowedRole = 1; // = Members
        conditions.needFulfilled = mandateCount - 1; // = Nominate for election
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke nomination for election: any member can revoke their nomination for an election.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Nominate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    false // revoke nomination
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Open Vote for election
        mandateCount++;
        conditions.allowedRole = 1; // = Members
        conditions.needFulfilled = mandateCount - 3; // = Create election
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Open voting for election: Members can open the vote for an election. This will create a dedicated vote mandate.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_CreateVoteMandate"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
                    initialisePowers.getInitialisedAddress("ElectionList_Vote"), // the vote mandate address
                    1, // the max number of votes a voter can cast
                    1 // the role Id allowed to vote (Members)
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Tally election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1; // = Open Vote election
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Tally elections: After an election has finished, assign the Convener role to the winners.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Tally"),
                config: abi.encode(
                    initialisePowers.getInitialisedAddress("ElectionList"),
                    2, // RoleId for Conveners
                    3 // Max role holders
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: clean up election
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = mandateCount - 1; // = Tally election
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Clean up election: After an election has finished, clean up related mandates.",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_CleanUpVoteMandate"),
                config: abi.encode(mandateCount - 2), // The create vote mandate)
                conditions: conditions
            })
        );
        delete conditions;

        // // VOTE OF NO CONFIDENCE // 
        // // very similar to elect conveners, but no throttle, higher threshold and ALL executives get role revoked the moment the first mandate passes.
        // inputParams = new string[](3);
        // inputParams[0] = "string Title";
        // inputParams[1] = "uint48 StartBlock";
        // inputParams[2] = "uint48 EndBlock";

        // // Members: Vote of No Confidence 
        // mandateCount++;
        // conditions.allowedRole = 1;
        // conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = 5 minutes / days
        // conditions.succeedAt = 77; // high majority
        // conditions.quorum = 60; // = high quorum 
        // physicalConstitution.push(
        //     PowersTypes.MandateInitData({
        //         nameDescription: "Vote of No Confidence: Revoke Convener statuses.",
        //         targetMandate: initialisePowers.getInitialisedAddress("RevokeAccountsRoleId"),
        //         config: abi.encode(
        //             2, // roleId
        //             inputParams // the input params to fill out.
        //         ),
        //         conditions: conditions
        //     })
        // );
        // delete conditions;

        // // Members: create election
        // mandateCount++;
        // conditions.allowedRole = 1; // = Members (should be Convener according to MD, but code says Members)
        // conditions.needFulfilled = mandateCount - 1; // = previous Vote of No Confidence mandate. Note: NO throttle on this one.
        // physicalConstitution.push(
        //     PowersTypes.MandateInitData({
        //         nameDescription: "Create an election: an election can be initiated be any member.",
        //         targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
        //         config: abi.encode(
        //             initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
        //             ElectionList.createElection.selector, // selector
        //             inputParams
        //         ),
        //         conditions: conditions
        //     })
        // );
        // delete conditions;

        // // Members: Nominate for Executive election
        // mandateCount++;
        // conditions.allowedRole = 1; // = Members (should be Conveners according to MD, but code says Members)
        // physicalConstitution.push(
        //     PowersTypes.MandateInitData({
        //         nameDescription: "Nominate for election: any member can nominate for an election.",
        //         targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Nominate"),
        //         config: abi.encode(
        //             initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
        //             true // nominate as candidate
        //         ),
        //         conditions: conditions
        //     })
        // );
        // delete conditions;

        // // Members revoke nomination for Executive election.
        // mandateCount++;
        // conditions.allowedRole = 1; // = Members (should be Conveners according to MD, but code says Members)
        // conditions.needFulfilled = mandateCount - 1; // = Nominate for election
        // physicalConstitution.push(
        //     PowersTypes.MandateInitData({
        //         nameDescription: "Revoke nomination for election: any member can revoke their nomination for an election.",
        //         targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Nominate"),
        //         config: abi.encode(
        //             initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
        //             false // revoke nomination
        //         ),
        //         conditions: conditions
        //     })
        // );
        // delete conditions;

        // // Members: Open Vote for election
        // mandateCount++;
        // conditions.allowedRole = 1; // = Members
        // conditions.needFulfilled = mandateCount - 3; // = Create election
        // physicalConstitution.push(
        //     PowersTypes.MandateInitData({
        //         nameDescription: "Open voting for election: Members can open the vote for an election. This will create a dedicated vote mandate.",
        //         targetMandate: initialisePowers.getInitialisedAddress("ElectionList_CreateVoteMandate"),
        //         config: abi.encode(
        //             initialisePowers.getInitialisedAddress("ElectionList"), // election list contract
        //             initialisePowers.getInitialisedAddress("ElectionList_Vote"), // the vote mandate address
        //             1, // the max number of votes a voter can cast
        //             1 // the role Id allowed to vote (Members)
        //         ),
        //         conditions: conditions
        //     })
        // );
        // delete conditions;

        // // Members: Tally election
        // mandateCount++;
        // conditions.allowedRole = 1;
        // conditions.needFulfilled = mandateCount - 1; // = Open Vote election
        // physicalConstitution.push(
        //     PowersTypes.MandateInitData({
        //         nameDescription: "Tally elections: After an election has finished, assign the Convener role to the winners.",
        //         targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Tally"),
        //         config: abi.encode(
        //             initialisePowers.getInitialisedAddress("ElectionList"),
        //             2, // RoleId for Conveners
        //             5 // Max role holders
        //         ),
        //         conditions: conditions
        //     })
        // );
        // delete conditions;

        // // Members: clean up election
        // mandateCount++;
        // conditions.allowedRole = 1;
        // conditions.needFulfilled = mandateCount - 1; // = Tally election
        // physicalConstitution.push(
        //     PowersTypes.MandateInitData({
        //         nameDescription: "Clean up election: After an election has finished, clean up related mandates.",
        //         targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_OnReturnValue"),
        //         config: abi.encode(
        //             address(primaryDAO), // target contract
        //             IPowers.revokeMandate.selector, // function selector to call
        //             abi.encode(), // params before
        //             new string[](0), // dynamic params: none (return value is used directly)
        //             mandateCount - 2, // parent mandate id (the open vote  mandate)
        //             abi.encode() // no params after
        //         ),
        //         conditions: conditions
        //     })
        // );
        // delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                        REFORM MANDATES                           //
        //////////////////////////////////////////////////////////////////////

        // ADOPT MANDATES //
        string[] memory adoptMandatesParams = new string[](2);
        adoptMandatesParams[0] = "address[] mandates";
        adoptMandatesParams[1] = "uint256[] roleIds";

        // Members: initiate Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 1; // Members
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 66;
        conditions.quorum = 77;
        conditions.needFulfilled = mandateCount - 1;
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initiate Adopting Mandates: Members can initiate adopting new mandates",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        // PrimaryDAO: Veto Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 0; // PrimaryDAO = Admin. 
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Adopting Mandates: PrimaryDAO can veto proposals to adopt new mandates", // TODO: PrimaryDAO actually does not have a law yet to cast a veto..
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Conveners: Adopt Mandates
        mandateCount++;
        conditions.allowedRole = 2; // Conveners
        conditions.needFulfilled = mandateCount - 2;
        conditions.needNotFulfilled = mandateCount - 1;
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 66;
        conditions.quorum = 80;
        physicalConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Adopt new Mandates: Conveners can adopt new mandates into the organization",
                targetMandate: initialisePowers.getInitialisedAddress("Mandates_Adopt"),
                config: abi.encode(),
                conditions: conditions
            })
        );
        delete conditions;
    }

    //////////////////////////////////////////////////////////////
    //                      HELPER FUNCTIONS                    //
    //////////////////////////////////////////////////////////////
    function getPrimaryDAO() public view returns (Powers) {
        return primaryDAO;   
    }

    function getDigitalSubDAO() public view returns (Powers) {
        return digitalSubDAO;   
    }

    function getTreasury() public view returns (address treasuryAddress) {
        return primaryDAO.getTreasury();   
    }

    function getConfig() public view returns (Configurations.NetworkConfig memory) {
        return config;   
    }
}



/////////////////////////////////////////////
// OLD DEPLOY SEQUENCE FOR SEPOLIA MAINNET // 
/////////////////////////////////////////////



    // // DEPLOY SEQUENCE FOR SEPOLIA MAINNET FOR CULTURAL STEWARDS DAO
    // function run() external { // DEPLOY SEQUENCE FOR SEPOLIA MAINNET FOR CULTURAL STEWARDS DAO
    //     // step 0, setup.
    //     initialisePowers = new InitialisePowers();
    //     initialisePowers.run();
    //     helperConfig = new Configurations();
    //     config = helperConfig.getConfig();

    //     // Deploy vanilla DAOs (parent and digital) and DAO factories (for ideas and physical).
    //     vm.startBroadcast();
    //     console2.log("Deploying Vanilla Powers contracts...");
    //     primaryDAO = new Powers(
    //         "Primary DAO", // name
    //         "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreihtpfkpjxianudgvf7pdq7toccccrztvckqpkc3vfnai4x7l3zmme", // uri
    //         config.maxCallDataLength, // max call data length
    //         config.maxReturnDataLength, // max return data length
    //         config.maxExecutionsLength // max executions length
    //     );

    //     digitalSubDAO = new Powers(
    //         "Digital sub-DAO", // name
    //         "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreiemrhwiqju7msjxbszlrk73cn5omctzf2xf2jxaenyw7is2r4takm", // uri
    //         config.maxCallDataLength, // max call data length
    //         config.maxReturnDataLength, // max return data length
    //         config.maxExecutionsLength // max executions length
    //     );

    //     console2.log("Deploying Organisation's Helper contracts...");
    //     soulbound1155 = new Soulbound1155(
    //         "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreighx6axdemwbjara3xhhfn5yaiktidgljykzx3vsrqtymicxxtgvi"
    //     );
    //     vm.stopBroadcast();
    //     console2.log("Primary DAO deployed at:", address(primaryDAO));
    //     console2.log("Digital sub-DAO deployed at:", address(digitalSubDAO));
    //     console2.log("Soulbound1155 deployed at:", address(soulbound1155));

    //     // setup Safe treasury.
    //     address[] memory owners = new address[](1);
    //     owners[0] = address(primaryDAO);

    //     vm.startBroadcast();
    //     console2.log("Setting up Safe treasury for Primary DAO...");
    //     treasury = address(
    //         SafeProxyFactory(config.safeProxyFactory)
    //             .createProxyWithNonce(
    //                 config.safeL2Canonical,
    //                 abi.encodeWithSelector(
    //                     Safe.setup.selector,
    //                     owners,
    //                     1, // threshold
    //                     address(0), // to
    //                     "", // data
    //                     address(0), // fallbackHandler
    //                     address(0), // paymentToken
    //                     0, // payment
    //                     address(0) // paymentReceiver
    //                 ),
    //                 1 // = nonce
    //             )
    //     );
    //     vm.stopBroadcast();
    //     console2.log("Safe treasury deployed at:", treasury);

    //     // Deploing Ideas and Physical sub-DAO factories.
    //     createIdeasConstitution();
    //     console2.log("Ideas Constitution, length:", ideasConstitution.length);
    //     PowersTypes.MandateInitData[] memory packedIdeasConstitution =
    //         packageInitData(ideasConstitution, PACKAGE_SIZE, 1);
    //     console2.log("Ideas Constitution Packed, length:", packedIdeasConstitution.length);

    //     createPhysicalConstitution();
    //     console2.log("Physical Constitution, length:", physicalConstitution.length);
    //     PowersTypes.MandateInitData[] memory packedPhysicalConstitution =
    //         packageInitData(physicalConstitution, PACKAGE_SIZE, 1);
    //     console2.log("Physical Constitution Packed, length:", packedPhysicalConstitution.length);

    //     // dpeloying subDAO factories.
    //     console2.log("Deploying DAO factories...");
    //     vm.startBroadcast();
    //     ideasDaoFactory = new PowersFactory(
    //         packedIdeasConstitution, // mandate init data
    //         config.maxCallDataLength, // max call data length
    //         config.maxReturnDataLength, // max return data length
    //         config.maxExecutionsLength // max executions length
    //     );

    //     physicalDaoFactory = new PowersFactory(
    //         packedPhysicalConstitution, // mandate init data
    //         config.maxCallDataLength, // max call data length
    //         config.maxReturnDataLength, // max return data length
    //         config.maxExecutionsLength // max executions length
    //     );
    //     vm.stopBroadcast();
    //     console2.log("Ideas sub-DAO factory deployed at:", address(ideasDaoFactory));
    //     console2.log("Physical sub-DAO factory deployed at:", address(physicalDaoFactory));

    //     console2.log("Creating constitutions...");
    //     createPrimaryConstitution();
    //     console2.log("Parent Constitution, length:", primaryConstitution.length);
    //     PowersTypes.MandateInitData[] memory packedPrimaryConstitution =
    //         packageInitData(primaryConstitution, PACKAGE_SIZE, 1); // package size 10 mandates. startId = 1.
    //     console2.log("Parent Packed Constitution, length:", packedPrimaryConstitution.length);

    //     createDigitalConstitution();
    //     console2.log("Digital Constitution, length:", digitalConstitution.length);
    //     PowersTypes.MandateInitData[] memory packedDigitalConstitution =
    //         packageInitData(digitalConstitution, PACKAGE_SIZE, 1); // package size 10 mandates. startId = 1.
    //     console2.log("Parent Packed Constitution, length:", packedDigitalConstitution.length);

    //     // step 4: run constitute on vanilla DAOs.
    //     vm.startBroadcast();
    //     console2.log("Constituting Primary DAO and Digital sub-DAO...");
    //     primaryDAO.constitute(packedPrimaryConstitution, msg.sender); // set msg.sender as admin
    //     vm.stopBroadcast();

    //     vm.startBroadcast();
    //     digitalSubDAO.constitute(packedDigitalConstitution, msg.sender); // set msg.sender as admin
    //     vm.stopBroadcast();

    //     // step 5: transfer ownership of factories to primary DAO.
    //     vm.startBroadcast();
    //     console2.log("Transferring ownership of DAO factories to Primary DAO...");
    //     soulbound1155.transferOwnership(address(primaryDAO));
    //     ideasDaoFactory.transferOwnership(address(primaryDAO));
    //     physicalDaoFactory.transferOwnership(address(primaryDAO));
    //     vm.stopBroadcast();

    //     // step 6: Unpack mandates
    //     uint256 numPackages = (primaryConstitution.length + PACKAGE_SIZE - 1) / PACKAGE_SIZE;
    //     uint256 numPackagesDig = (digitalConstitution.length + PACKAGE_SIZE - 1) / PACKAGE_SIZE;

    //     console2.log("Unpacking %s packages...", numPackages);
    //     // Execute package mandates (sequentially)
    //     vm.startBroadcast();
    //     for (uint256 i = 1; i <= numPackages; i++) {
    //         primaryDAO.request(uint16(i), "", 0, "");
    //     }

    //     for (uint256 j = 1; j <= numPackagesDig; j++) {
    //         digitalSubDAO.request(uint16(j), "", 0, "");
    //     }
    //     vm.stopBroadcast();

    //     console2.log("Success! All contracts successfully deployed, unpacked and configured.");
    // }
