import { Organization, MandateInitData, isDeployableContract, isFunctionCallDependency, DeployableContract } from "./types";
import { powersAbi, safeL2Abi, safeProxyFactoryAbi } from "@/context/abi";  
import { Abi, encodeAbiParameters, encodeFunctionData, parseAbiParameters, keccak256, encodePacked, toFunctionSelector } from "viem";
import { getInitialisedAddress, daysToBlocks, ADMIN_ROLE, PUBLIC_ROLE, createConditions, createMandateInitData, minutesToBlocks } from "./helpers";
import nominees from "@/context/builds/Nominees.json";
import { getConstants } from "@/context/constants";
import { sepolia, arbitrumSepolia, optimismSepolia, mantleSepoliaTestnet, foundry } from "@wagmi/core/chains";

/**
 * Helper function to extract contract address from receipt
 */
function getContractAddressFromReceipt(receipt: any, contractName: string): `0x${string}` {
  if (!receipt || !receipt.contractAddress) {
    throw new Error(`Failed to get contract address for ${contractName} from receipt.`);
  }
  return receipt.contractAddress;
}

/**
 * Helper function to extract return value from function call receipt
 */
function getReturnValueFromReceipt(receipt: any): any {
  // This would need to be implemented based on the specific function call 
  // For now, return the receipt itself - the organization can extract what it needs
  return receipt;
}

/**
 * Bicameral Governance Organization
 *
 * Implements a simple bicameral governance structure.
 * 
 * Note that for testing purposes, daysToBlocks has been replaced with minutesToBlocks. In reality every minute is a day. 
 */
export const OptimisticExecution: Organization = {
  metadata: {
    id: "optimistic-execution",
    title: "Optimistic Execution",
    uri: "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreibzf5td4orxnfknmrz5giiifw4ltsbzciaam7izm6dok5pkm6aqqa",
    banner: "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeihd4il4irvu3kqxnlohkkzlhpywcujqmabwldi3nftqmt5xaszwxy",
    description: "In Optimistic Execution, the Powers protocol leverages optimistic mechanisms to enable faster decision-making processes by assuming proposals are valid unless challenged. This approach can improve efficiency while still allowing for dispute resolution through challenges. A similar mechanism is currently used by the Optimism Collective.",
    disabled: false,
    onlyLocalhost: true
  },
  fields: [ ],
  dependencies:  [ ],
  exampleDeployment: {
    chainId: sepolia.id,
    address: '0xf9Be974884e4d1f314C0EBE07E5b5431b9CD6650' // Placeholder
  },
  allowedChains: [
    sepolia.id, 
    optimismSepolia.id, 
  ],
  allowedChainsLocally: [
    sepolia.id,  
    optimismSepolia.id, 
    foundry.id
  ],
 
  createMandateInitData: (
    powersAddress: `0x${string}`,
    formData: Record<string, any>,
    deployedMandates: Record<string, `0x${string}`>,
    dependencyReceipts: Record<string, any>,
    chainId: number,
  ): MandateInitData[] => {
    const mandateInitData: MandateInitData[] = [];
    let mandateCounter = 0;
    // console.log("deployedMandates @ PowerLabs", deployedMandates);
    // console.log("chainId @ createMandateInitData", {formData, selection: formData["chainlinkSubscriptionId"] as bigint});
    
    //////////////////////////////////////////////////////////////////
    //                 INITIAL SETUP & ROLE LABELS                  //
    //////////////////////////////////////////////////////////////////
    mandateCounter++;
    mandateInitData.push({
      nameDescription: "Initial Setup: Assign role labels (Members, Executives) and revokes itself after execution",
      targetMandate: getInitialisedAddress("PresetSingleAction", deployedMandates),
      config: encodeAbiParameters(
        [
          { name: 'targets', type: 'address[]' },
          { name: 'values', type: 'uint256[]' },
          { name: 'calldatas', type: 'bytes[]' }
        ],
        [
          [ powersAddress, powersAddress,  powersAddress ],
          [0n, 0n, 0n],
          [
            encodeFunctionData({
              abi: powersAbi,
              functionName: "labelRole",
              args: [1n, "Members"]
            }),
            encodeFunctionData({
              abi: powersAbi,
              functionName: "labelRole",  
              args: [2n, "Executives"]
            }),
            encodeFunctionData({
              abi: powersAbi,
              functionName: "revokeMandate",
              args: [1n]
            })
          ]
        ]
      ),
      conditions: createConditions({
        allowedRole: ADMIN_ROLE
      })
    });

        
    //////////////////////////////////////////////////////////////////
    //        EXECUTIVE  LAWS: OPTIMISTIC EXECUTION                 //
    //////////////////////////////////////////////////////////////////
    const executeActionConfig = encodeAbiParameters(
      parseAbiParameters('string[] inputParams'),
      [["address[] targets", "uint256[] values", "bytes[] calldatas"]]
    );

    // Veto Action
    mandateCounter++;
    mandateInitData.push({
      nameDescription: "Veto Actions: Funders can veto actions",
      targetMandate: getInitialisedAddress("StatementOfIntent", deployedMandates),
      config: executeActionConfig,
      conditions: createConditions({
        allowedRole: 1n, // Members
        votingPeriod: minutesToBlocks(5, chainId),
        succeedAt: 66n, // note the high threshold to veto
        quorum: 66n // note the high quorum to veto
      })
    }); 
    const vetoAction = BigInt(mandateCounter);

    // Execute action 
    mandateCounter++;
    mandateInitData.push({
      nameDescription: "Execute an action: Members propose adopting new mandates",
      targetMandate: getInitialisedAddress("OpenAction", deployedMandates),
      config: `0x`,
      conditions: createConditions({
        allowedRole: 2n, // Executives
        votingPeriod: minutesToBlocks(5, chainId),
        succeedAt: 51n,
        needNotFulfilled: vetoAction,
        quorum: 33n
      })
    });
     
    //////////////////////////////////////////////////////////////////
    //                    ELECTORAL LAWS                            //
    ///////////////////////////////////////////////////////////////// 
    mandateCounter++;
    mandateInitData.push({
      nameDescription: "Admin can assign any role: For this demo, the admin can assign any role to an account.",
      targetMandate: getInitialisedAddress("BespokeActionSimple", deployedMandates),
      config: encodeAbiParameters(
      parseAbiParameters('address powers, bytes4 FunctionSelector, string[] Params'),
        [
          powersAddress,
          toFunctionSelector("assignRole(uint256,address)"),
          ["uint256 roleId","address account"]
        ]
      ),
      conditions: createConditions({
        allowedRole: ADMIN_ROLE
      })
    });
    const assignAnyRole = BigInt(mandateCounter);

    mandateCounter++;
    mandateInitData.push({
      nameDescription: "A delegate can revoke a role: For this demo, any delegate can revoke previously assigned roles.",
      targetMandate: getInitialisedAddress("BespokeActionSimple", deployedMandates),
      config: encodeAbiParameters(
      parseAbiParameters('address powers, bytes4 FunctionSelector, string[] Params'),
        [
          powersAddress,
          toFunctionSelector("revokeRole(uint256,address)"),
          ["uint256 roleId","address account"]
        ]
      ),
      conditions: createConditions({
        allowedRole: 2n,
        needFulfilled: assignAnyRole
      })
    });  

    return mandateInitData;
  }
};
