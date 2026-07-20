// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26; 

// scripts
import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { Configurations } from "@script/Configurations.s.sol"; 
import { DeployHelpers } from "../DeployHelpers.s.sol";
import { IMandateRegistry } from "@src/core/helpers/MandateRegistry.sol";

// external protocols
import { Create2 } from "@lib/openzeppelin-contracts/contracts/utils/Create2.sol"; 
import { SafeProxyFactory } from "@lib/safe-smart-account/contracts/proxies/SafeProxyFactory.sol"; 
import { Safe } from "@lib/safe-smart-account/contracts/Safe.sol"; 
import { ModuleManager } from "@lib/safe-smart-account/contracts/base/ModuleManager.sol";
import { IERC721 } from "@lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

// powers contracts
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";

// helpers 
import { ElectionRegistry } from "@src/core/helpers/ElectionRegistry.sol";
import { Governed721, IGoverned721 } from "@src/addons/helpers/Governed721.sol";

/// @title Governed721DAO Deployment Script
contract Deploy is DeployHelpers {
    Configurations helperConfig;
    IMandateRegistry registry;
    PowersTypes.MandateInitData[] constitution; 
    PowersTypes.Conditions conditions;
    Powers public powers;
    PowersTypes.Flow[] flows;
    Governed721 public governed721;
    ElectionRegistry public electionRegistry;

    uint256 constant PACKAGE_SIZE = 10; // number of mandates per packaged mandate.
    address treasury;
    uint16 mintMandateId; 
    uint16 paymentMandateId;
    uint16 transferMandateId;
    uint16 proposeSplitId;
    uint16 vetoMinterId;
    uint16 vetoOwnerId;
    uint16 vetoIntermediaryId;
    uint16 splitCheckpoint1;
    uint16 splitCheckpoint2;
    uint16 splitCheckpoint3;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] inputParams;
    string[] dynamicParams;
 
    string baseURI = "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeibcfc5dzcah2xxmvk3gjhij7t3sp5v6ppkub36jmtex2t75fcz22i/";
    // Select version mandates to be used.
    uint16 constant MAJOR = 0;
    uint16 constant MINOR = 1;
    uint16 constant PATCH = 9;

    function run() external returns (address powersAddress, address governed721Address, address electionRegistryAddress) {
        // step 0, setup. 
        helperConfig = new Configurations();
        electionRegistry = new ElectionRegistry(minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid)), minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid)));
        registry = IMandateRegistry(helperConfig.getMandateRegistry(block.chainid));

        // step 1: deploy Governed721 Powers
        vm.startBroadcast();
        powers = new Powers(
            "Governed721", // name
            string.concat(baseURI, "organisation.json"), // uri
            helperConfig.getMaxCallDataLength(block.chainid), // max call data length
            helperConfig.getMaxReturnDataLength(block.chainid), // max return data length
            helperConfig.getMaxExecutionsLength(block.chainid), // max executions length
            address(registry)
        );
        governed721 = new Governed721();
        vm.stopBroadcast();  

        uint256 constitutionLength = createConstitution();

        // step 3: run constitute.
        for (uint256 i = 0; i < constitution.length; i += PACKAGE_SIZE) {
            uint256 size = PACKAGE_SIZE;
            if (i + size > constitution.length) {
                size = constitution.length - i;
            }
            PowersTypes.MandateInitData[] memory batch = new PowersTypes.MandateInitData[](size);
            for (uint256 j = 0; j < size; j++) {
                batch[j] = constitution[i + j];
            }
            vm.startBroadcast();
            powers.constitute(batch); // set msg.sender as admin
            vm.stopBroadcast();
        }
        vm.startBroadcast(); 
        powers.closeConstitute(msg.sender, flows); // close constitute and set flows. msg.sender is admin.
        governed721.transferOwnership(address(powers));  
        vm.stopBroadcast();

        console2.log("Powers successfully constituted."); 
        console2.log("Constitution length:", constitutionLength);

        return (address(powers), address(governed721), address(electionRegistry));
    }


    //////////////////////////////////////////////////////////////////////
    //                       HELPER FUNCTIONS                           //
    //////////////////////////////////////////////////////////////////////
    function getElectionRegistry() public view returns (address) {
        return address(electionRegistry);
    }

    function createConstitution() internal returns (uint256 constitutionLength) {
        uint16 mandateCount = 0;

        //////////////////////////////////////////////////////////////////////
        //                              SETUP                               //
        //////////////////////////////////////////////////////////////////////
        calldatas = new bytes[](10);
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Admin", "");  
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", ""); 
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Artist", "");
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Owner", ""); 
        calldatas[4] = abi.encodeWithSelector(IPowers.labelRole.selector, 3, "Intermediary", ""); 
        calldatas[5] = abi.encodeWithSelector(IPowers.labelRole.selector, 4, "Voter", ""); 
        calldatas[6] = abi.encodeWithSelector(IPowers.labelRole.selector, 5, "Executive", "");
        calldatas[7] = abi.encodeWithSelector(IPowers.assignRole.selector, 5, testAccount1); 
        calldatas[8] = abi.encodeWithSelector(IPowers.setTreasury.selector, address(powers));
        calldatas[9] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1); // revoke mandate 1 after use.

        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = public.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initial Setup: Assign role labels and revokes itself after execution",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions_OnOwnPowers"),
                config: abi.encode(calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                      EXECUTIVE MANDATES                          //
        //////////////////////////////////////////////////////////////////////
        // SET SPLIT PAYMENT FLOW
        uint16[] memory mandateIds = new uint16[](7); 
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2; 
        mandateIds[2] = mandateCount + 3; 
        mandateIds[3] = mandateCount + 4;
        mandateIds[4] = mandateCount + 5;
        mandateIds[5] = mandateCount + 6;
        mandateIds[6] = mandateCount + 7;

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Set a split payment: Executives can propose a new split, minter, owner and intermediary can veto, and if no vetoes, executives can execute the new split after a time lock."
        }));

        // single executive: propose new split and vote. Input should be the new split between minter, intermediary and owner.
        inputParams = new string[](2);
        inputParams[0] = "uint8 Role"; // 1 = Artist, 2 = Intermediary. The Old Owner gets the remainder after Artist and Intermediary split, so we only need to input the splits for Artist and Intermediary.
        inputParams[1] = "uint8 Percentage";

        mandateCount++;
        conditions.allowedRole = 5; // Executive
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Propose Split Payment: Executive proposes new split. Role 1 = Artist, Role 2 = Intermediary. The old owner gets the remainder after Artist and Intermediary split.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;
        proposeSplitId = mandateCount;

        // minter, owners and intermediaries have veto (see Cultural Stewards DAO on how to do this) 
        // Minter Veto
        mandateCount++;
        conditions.allowedRole = 1; // Minter
        conditions.needFulfilled = proposeSplitId;
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.succeedAt = 51;
        conditions.quorum = 30; //
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Split (Minter): Minter can veto split change.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;
        vetoMinterId = mandateCount;

        // Owner Veto
        mandateCount++;
        conditions.allowedRole = 2; // Owner
        conditions.needFulfilled = proposeSplitId;
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.succeedAt = 51;
        conditions.quorum = 30; // 
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Split (Owner): Owner can veto split change.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;
        vetoOwnerId = mandateCount;

        // Intermediary Veto
        mandateCount++;
        conditions.allowedRole = 3; // Intermediary
        conditions.needFulfilled = proposeSplitId;
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.succeedAt = 51;
        conditions.quorum = 30; //
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Split (Intermediary): Intermediary can veto split change.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;
        vetoIntermediaryId = mandateCount;

        // executives: vote + time lock. Execute & implement new split.        
        // Checkpoint 1: Check Minter Veto
        mandateCount++;
        conditions.allowedRole = 5; // any executive can execute, but it will only execute if the minter has not vetoed.
        conditions.needFulfilled = proposeSplitId;
        conditions.needNotFulfilled = vetoMinterId;
        conditions.timelock = minutesToBlocks(10, helperConfig.getBlocksPerHour(block.chainid)); // Wait for vetos
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Split Checkpoint 1: Confirm no Minter veto.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;
        splitCheckpoint1 = mandateCount;

        // Checkpoint 2: Check Owner Veto
        mandateCount++;
        conditions.allowedRole = 5; // any executive can execute, but it will only execute if the owner has not vetoed.
        conditions.needFulfilled = splitCheckpoint1;
        conditions.needNotFulfilled = vetoOwnerId;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Split Checkpoint 2: Confirm no Owner veto.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;
        splitCheckpoint2 = mandateCount;

        // Checkpoint 3: Check Intermediary Veto & execute Split if no vetoes.
        mandateCount++;
        conditions.allowedRole = 5; // any executive can execute, but it will only execute if the intermediary has not vetoed.
        conditions.needFulfilled = splitCheckpoint2;
        conditions.needNotFulfilled = vetoIntermediaryId;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute Split Payment: Set new split payment.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(
                    address(governed721),
                    Governed721.setSplit.selector,
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;
        splitCheckpoint3 = mandateCount;
 
        // ADD / REMOVE ALLOWED TOKENS MANDATE 
        mandateIds = new uint16[](2); 
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Add/Remove Allowed Tokens: Executives can add or remove allowed tokens, with a voting period and veto power for members."
        }));

        // executives: add allowed tokens. Vote. Execute. 
        inputParams = new string[](2);
        inputParams[0] = "address Token";

        mandateCount++;
        conditions.allowedRole = 5; // Executives
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 50;
        conditions.succeedAt = 51;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Add Allowed Token: Whitelist a token.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Advanced"),
                config: abi.encode(
                    address(governed721),
                    Governed721.setWhitelist.selector,
                    abi.encode(), 
                    inputParams,
                    abi.encode(true) // true to whitelist, false to remove from whitelist
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // executives: revoke allowed tokens. Vote. Execute. Previous mandate should have executed.  
        mandateCount++;
        conditions.needFulfilled = mandateCount - 1; // Need the previous "Add Allowed Token" mandate to have executed to ensure the token is currently allowed before we can remove it.
        conditions.allowedRole = 5; // Executives
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 50;
        conditions.succeedAt = 51;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Remove Allowed Token: De-whitelist a token.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Advanced"),
                config: abi.encode(
                    address(governed721),
                    Governed721.setWhitelist.selector,
                    abi.encode(), 
                    inputParams,
                    abi.encode(false) // true to whitelist, false to remove from whitelist
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // SET BLACKLIST
        // £todo - update this flow? 
        mandateIds = new uint16[](2); 
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Set Blacklist: Executives can add or remove accounts from a blacklist, with a voting period and veto power for members."
        }));

        // executives: add addresses to blacklist. Vote. Execute.
        inputParams = new string[](1);
        inputParams[0] = "address Account";

        mandateCount++;
        conditions.allowedRole = 5; // Executives
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 50;
        conditions.succeedAt = 51;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Add account to blacklist: Blacklist an account. They will not be able to transfer or mint NFTs.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Advanced"),
                config: abi.encode(
                    address(0),
                    IPowers.blacklistAddress.selector,
                    abi.encode(), 
                    inputParams,
                    abi.encode(true) // true to whitelist 
                ),
                conditions: conditions
            })
        );
        delete conditions;

        mandateCount++;
        conditions.allowedRole = 5; // Executives
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 50;
        conditions.succeedAt = 51;
        conditions.needFulfilled = mandateCount - 1; // Need the previous "Add to Blacklist" mandate to have executed to ensure the account is currently blacklisted before we can remove it.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Remove account from blacklist: Remove an account from the blacklist. They will be able to transfer or mint NFTs again.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Advanced"),
                config: abi.encode(
                    address(0),
                    IPowers.blacklistAddress.selector,
                    abi.encode(), 
                    inputParams,
                    abi.encode(false) // true to whitelist, false to remove from whitelist
                ),
                conditions: conditions
            })
        );
        delete conditions; 
 
        //////////////////////////////////////////////////////////////////////
        //                        ELECTORAL MANDATES                        // 
        //////////////////////////////////////////////////////////////////////

        // MANAGING OWNER ROLE
        mandateIds = new uint16[](3); 
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Manage Owner Role: Assigning and revoking owner role based on ownership of the NFT. Owner can be assigned or revoked based on the ownership check, with a veto from executives for revocation."
        }));

        inputParams = new string[](1);
        inputParams[0] = "uint256 TokenId";
        // First calls the ERC721 contract to check owner of NFT. 
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = public function 
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Check ownership Token: This check is needed to assign the owner role to the NFT owner in the next mandate.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(
                    address(governed721),
                    IERC721.ownerOf.selector,
                    inputParams
                    ),
                conditions: conditions
            })
        );
        delete conditions;

        // second call uses the return value to assign the role. 
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = public function 
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Assign Owner Role: Assigns Owner role to the owner of the NFT.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_OnReturnValue"),
                config: abi.encode(
                    address(0),
                    IPowers.assignRole.selector,
                    abi.encode(2), // Owner role
                    inputParams,
                    mandateCount - 1, // the mandate from which the return data will be fetched (the ownership check mandate)
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // third call (executives) uses the same return value + previous law must be fulfilled to revoke the role. 
        mandateCount++;
        conditions.allowedRole = 5; // Executives
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.succeedAt = 51;
        conditions.quorum = 10;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke Owner Role: Revokes Owner role. In case of inactivity or lapsed ownership. Executives can revoke the owner role based on the same ownership check if needed.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_OnReturnValue"),
                config: abi.encode(
                    address(0),
                    IPowers.revokeRole.selector,
                    abi.encode(2), // Owner role
                    inputParams,
                    mandateCount - 2, // the mandate from which the return data will be fetched (the ownership check mandate)
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // MANAGING ARTIST ROLE:
        mandateIds = new uint16[](3); 
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Manage Artist Role: Assigning and revoking artist role based on having minted an NFT. Artist can be assigned or revoked based on the artist check, with a veto from executives for revocation."
        }));

        // follows the same logic as owner role assignment, but reads the artist from the governed721 contract instead of the owner. 
        inputParams = new string[](1);
        inputParams[0] = "uint256 TokenId";
        // First calls the ERC721 contract to check artist of NFT. 
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = public function 
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Check artist Token: This check is needed to assign the artist role to the NFT artist in the next mandate.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(
                    address(governed721),
                    IGoverned721.getArtist.selector,
                    inputParams
                    ),
                conditions: conditions
            })
        );
        delete conditions;

        // second call uses the return value to assign the role. 
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = public function 
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Assign Artist Role: Assigns Artist role to the artist of the NFT.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_OnReturnValue"),
                config: abi.encode(
                    address(0),
                    IPowers.assignRole.selector,
                    abi.encode(1), // Artist role
                    inputParams,
                    mandateCount - 1, // the mandate from which the return data will be fetched (the artist check mandate)
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // third call (executives) uses the same return value + previous law must be fulfilled to revoke the role. 
        mandateCount++;
        conditions.allowedRole = 5; // Executives
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.succeedAt = 51;
        conditions.quorum = 10;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke Artist Role: Revokes Artist role. In case of inactivity or lapsed ownership. Executives can revoke the artist role based on the same artist check if needed.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_OnReturnValue"),
                config: abi.encode(
                    address(0),
                    IPowers.revokeRole.selector,
                    abi.encode(1), // Artist role
                    inputParams,
                    mandateCount - 2, // the mandate from which the return data will be fetched (the artist check mandate)
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // MANAGING INTERMEDIARY ROLE:
        mandateIds = new uint16[](3); 
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Manage Intermediary Role: Assigning and revoking intermediary role based on approved address of the NFT. Intermediary can be assigned or revoked based on the approved address check, with a veto from executives for revocation."
        }));

        // Note follows the same logic as owner role assignments, but now checks if / who has been assigned as 'approved' at a token. 
        inputParams = new string[](1);
        inputParams[0] = "uint256 TokenId";
        // First calls the ERC721 contract to check approved address for NFT. 
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = public function 
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Check intermediary Token: This check is needed to assign the intermediary role to the NFT intermediary in the next mandate.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(
                    address(governed721),
                    IERC721.getApproved.selector,
                    inputParams
                    ),
                conditions: conditions
            })
        );
        delete conditions;

        // second call uses the return value to assign the role. 
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = public function 
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Assign Intermediary Role: Assigns Intermediary role to the approved address of the NFT.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_OnReturnValue"),
                config: abi.encode(
                    address(0),
                    IPowers.assignRole.selector,
                    abi.encode(3), // Intermediary role
                    inputParams,
                    mandateCount - 1, // the mandate from which the return data will be fetched (the ownership check mandate)
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // third call (executives) uses the same return value + previous law must be fulfilled to revoke the role. 
        mandateCount++;
        conditions.allowedRole = 5; // Executives
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.succeedAt = 51;
        conditions.quorum = 10;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke Intermediary Role: Revokes Intermediary role. In case of inactivity or lapsed ownership. Executives can revoke the intermediary role based on the same ownership check if needed.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_OnReturnValue"),
                config: abi.encode(
                    address(0),
                    IPowers.revokeRole.selector,
                    abi.encode(3), // Intermediary role
                    inputParams,
                    mandateCount - 2, // the mandate from which the return data will be fetched (the ownership check mandate)
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // VOTER ROLE AND EXECUTIVE ELECTIONS  
        mandateIds = new uint16[](7); 
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;
        mandateIds[3] = mandateCount + 4;
        mandateIds[4] = mandateCount + 5;
        mandateIds[5] = mandateCount + 6;
        mandateIds[6] = mandateCount + 7;

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Manage Voter Role and Executive Elections: Assigning voter role based on having a certain role (e.g. owner, minter, intermediary), with executives having the power to veto. Executives can create elections, voters can vote, and executives can tally and execute results."
        }));

        uint256[] memory voterRoleCriteria = new uint256[](3);
        voterRoleCriteria[0] = 1; // Artist role ID
        voterRoleCriteria[1] = 2; // Owner role ID
        voterRoleCriteria[2] = 3; // Intermediary role ID
        // if account has artist, owner or intermediary role, they can claim a voter role. 
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // public  
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Claim Voter Role: Artists, Owners, and Intermediarys can claim voter role.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "RoleByRoles"),
                config: abi.encode(
                    4, // Voter role ID
                    voterRoleCriteria
                    ),
                conditions: conditions
            })
        );
        delete conditions; 

        // Note standard election flow. See cultural stewards DAO for example. WHO ARE THE VOTERS AND CANDIDATES? 
        // Voters = Role 4 (Voter)
        // Candidates = Role 4? (Assume Voters can be Executives)        
        inputParams = new string[](1);
        inputParams[0] = "string Title"; 

        // Create Election
        mandateCount++;
        conditions.allowedRole = 4; // Voters
        conditions.throttleExecution = minutesToBlocks(30, helperConfig.getBlocksPerHour(block.chainid)); // Throttle to prevent multiple elections being created in a short period of time.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Create Executive Election: Voters can create election.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(
                    address(electionRegistry), // target contract (ElectionRegistry)
                    ElectionRegistry.createElection.selector,
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Open Vote
        mandateCount++;
        conditions.allowedRole = 4; // Voters
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Open Executive Vote: Open voting.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_CreateVoteMandate"),
                config: abi.encode(
                    address(electionRegistry),
                    registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Vote"),
                    1, // votes per voter
                    4 // allowed role to vote (Voter)
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Tally
        mandateCount++;
        conditions.allowedRole = 4;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Tally Executive Election: Tally votes.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Tally"),
                config: abi.encode(
                    address(electionRegistry),
                    5, // RoleId for Executives
                    5 // Max role holders
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Cleanup
        mandateCount++;
        conditions.allowedRole = 4;
        conditions.needFulfilled = mandateCount - 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Cleanup Election: Cleanup mandates.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_OnReturnValue"),
                config: abi.encode(
                    address(powers), // target contract (this DAO)
                    IPowers.revokeMandate.selector,
                    abi.encode(),
                    inputParams,
                    mandateCount - 2, // Open Vote mandate
                    abi.encode()
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Nominate
        mandateCount++;
        conditions.allowedRole = 4; // Voters
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate for Executive: Voters can nominate.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Nominate"),
                config: abi.encode(
                    address(electionRegistry),
                    true
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Revoke Nomination
        mandateCount++;
        conditions.allowedRole = 4;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke Nomination: Revoke self nomination.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Nominate"),
                config: abi.encode(
                    address(electionRegistry),
                    false
                ),
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                        ORPHAN MANDATES                           //
        //////////////////////////////////////////////////////////////////////
        // COLLECT PAYMENT 
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // Any one can call, but logic enforces caller matches role
        // conditions.needFulfilled = transferMandateId; // No longer linked to transfer mandate directly
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Collect Split Payment: Role holders can collect their split of payment.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "GovernedToken_CollectSplitPayment"),
                config: abi.encode(
                    address(governed721) // Governed721 Address
                ),
                conditions: conditions
            })
        );
        delete conditions;
        paymentMandateId = mandateCount;

        // SET URI 
        inputParams = new string[](1);
        inputParams[0] = "string newUri";

        mandateCount++;
        conditions.allowedRole = 5; // Executives
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid));
        conditions.succeedAt = 51;
        conditions.quorum = 10;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Executives can update URI: Executives can update the URI of the contract.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(0), IPowers.setUri.selector, inputParams),
                conditions: conditions
            })
        ); 
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                        REFORM MANDATES                           //
        //////////////////////////////////////////////////////////////////////
        // none. Immutable for now. 

        return constitution.length;
    }
}
