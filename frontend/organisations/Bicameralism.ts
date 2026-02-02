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
export const Bicameralism: Organization = {
  metadata: {
    id: "bicameralism",
    title: "Bicameralism",
    uri: "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreidlcgxe2mnwghrk4o5xenybljieurrxhtio6gq5fq5u6lxduyyl6e",
    banner: "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeihlduuz4ql3mcwyqifixrctuou6v45pspp5igjzmznpxwto6qdtdu",
    description: "In Bicameralism, the governance system is divided into two separate chambers or houses, each with its own distinct powers and responsibilities. In this example Delegates can initiate an action, but it can only be executed by Funders. A version of Bicameralism is implemented at the Optimism Collective.",
    disabled: false,
    onlyLocalhost: false
  },
  fields: [ ],
  dependencies:  [ ],
  exampleDeployment: {
    chainId: sepolia.id,
    address: `0xC80B17A47734EAdEd90CcF41C961e09095F7b0B6`
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
      nameDescription: "Initial Setup: Assign role labels (Delegates, Funders) and revokes itself after execution",
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
              args: [1n, "Delegates"]
            }),
            encodeFunctionData({
              abi: powersAbi,
              functionName: "labelRole",  
              args: [2n, "Funders"]
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
    //              EXECUTIVE  LAWS: BICAMERAL                      //
    //////////////////////////////////////////////////////////////////
    const executeActionConfig = encodeAbiParameters(
      parseAbiParameters('string[] inputParams'),
      [["address[] targets", "uint256[] values", "bytes[] calldatas"]]
    );

    // Veto Action
    mandateCounter++;
    mandateInitData.push({
      nameDescription: "Initiate action: Delegates can initiate an action",
      targetMandate: getInitialisedAddress("StatementOfIntent", deployedMandates),
      config: executeActionConfig,
      conditions: createConditions({
        allowedRole: 1n, // Delegates
        votingPeriod: minutesToBlocks(5, chainId),
        succeedAt: 51n,
        quorum: 33n 
      })
    }); 
    const initiateAction = BigInt(mandateCounter);

    // Execute action 
    mandateCounter++;
    mandateInitData.push({
      nameDescription: "Execute an action: Funders can execute an action.",
      targetMandate: getInitialisedAddress("OpenAction", deployedMandates),
      config: `0x`,
      conditions: createConditions({
        allowedRole: 2n, // Funders
        votingPeriod: minutesToBlocks(5, chainId),
        succeedAt: 51n,
        needFulfilled: initiateAction,
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