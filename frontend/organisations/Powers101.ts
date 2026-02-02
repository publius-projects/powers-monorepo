import { Organization } from "./types";
import { powersAbi } from "@/context/abi";
import { Abi, encodeAbiParameters, encodeFunctionData } from "viem";
import { minutesToBlocks, ADMIN_ROLE, PUBLIC_ROLE, createConditions, getInitialisedAddress } from "./helpers";
import { MandateInitData } from "./types";
import { sepolia, arbitrumSepolia, optimismSepolia, mantleSepoliaTestnet, foundry } from "@wagmi/core/chains";
 

/**
 * Powers 101 Organization
 * 
 * A simple DAO with basic governance based on separation of powers between 
 * delegates, members, and an admin. Perfect for learning the Powers protocol.
 * 
 * Key Features:
 * - Statement of Intent system for proposals
 * - Delegate execution with voting requirements
 * - Veto power for admin
 * - Self-nomination and election system
 * - Community membership via self-selection
 */
export const Powers101: Organization = {
  metadata: {
    id: "powers-101",
    title: "Powers 101",
    uri: "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreicbh6txnypkoy6ivngl3l2k6m646hruupqspyo7naf2jpiumn2jqe",
    banner: "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeickdiqcdmjjwx6ah6ckuveufjw6n2g6qdvatuhxcsbmkub3pvshnm",
    description: "A simple DAO with basic governance based on a separation of powers between delegates, an executive council and an admin. It is a good starting point for understanding the Powers protocol.",
    disabled: false,
    onlyLocalhost: false
  },
  fields: [],
  dependencies: [ ],
  allowedChains: [
    sepolia.id, 
    optimismSepolia.id
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

    // console.log("deployedMandates @Powers101", deployedMandates);
    // console.log("deployedDependencies @Powers101", deployedMandates);

    //////////////////////////////////////////////////////////////////
    //                 LAW 1: INITIAL SETUP                         //
    //////////////////////////////////////////////////////////////////

    mandateInitData.push({
      nameDescription: "Initial Setup: Assign role labels (Members, Delegates) and revoke itself after execution",
      targetMandate: getInitialisedAddress("PresetSingleAction", deployedMandates),
      config: encodeAbiParameters(
        [
          { name: 'targets', type: 'address[]' },
          { name: 'values', type: 'uint256[]' },
          { name: 'calldatas', type: 'bytes[]' }
        ],
        [
          [
            powersAddress, 
            powersAddress,  
            powersAddress
          ],
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
              args: [2n, "Delegates"]
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
    //                    EXECUTIVE LAWS                            //
    //////////////////////////////////////////////////////////////////

    const statementOfIntentConfig = encodeAbiParameters(
      [{ name: 'inputParams', type: 'string[]' }],
      [["address[] Targets", "uint256[] Values", "bytes[] Calldatas"]]
    );

    // Mandate 2: Statement of Intent
    mandateInitData.push({
      nameDescription: "Statement Of Intent: Members can initiate an action through a Statement of Intent that Delegates can later execute",
      targetMandate: getInitialisedAddress("StatementOfIntent", deployedMandates),
      config: statementOfIntentConfig,
      conditions: createConditions({
        allowedRole: 1n,
        votingPeriod: minutesToBlocks(5, Number(deployedMandates.chainId)),
        succeedAt: 51n,
        quorum: 20n
      })
    });

    // Mandate 3: Veto an action
    mandateInitData.push({
      nameDescription: "Veto Action: Admin can veto actions proposed by the community",
      targetMandate: getInitialisedAddress("StatementOfIntent", deployedMandates),
      config: statementOfIntentConfig,
      conditions: createConditions({
        allowedRole: ADMIN_ROLE,
        needFulfilled: 2n
      })
    });

    // Mandate 4: Execute an action
    mandateInitData.push({
      nameDescription: "Execute Action: Delegates approve and execute actions proposed by the community",
      targetMandate: getInitialisedAddress("OpenAction", deployedMandates),
      config: "0x",
      conditions: createConditions({
        allowedRole: 2n,
        quorum: 50n,
        succeedAt: 77n,
        votingPeriod: minutesToBlocks(5, Number(deployedMandates.chainId)),
        needFulfilled: 2n,
        needNotFulfilled: 3n,
        timelock: minutesToBlocks(3, Number(deployedMandates.chainId))
      })
    });

    //////////////////////////////////////////////////////////////////
    //                    ELECTORAL LAWS                            //
    //////////////////////////////////////////////////////////////////

    // Mandate 5: Self select as community member
    mandateInitData.push({
      nameDescription: "Join as Member: Anyone can self-select to become a community member",
      targetMandate: getInitialisedAddress("SelfSelect", deployedMandates),
      config: encodeAbiParameters(
        [{ name: 'roleId', type: 'uint256' }],
        [1n]
      ),
      conditions: createConditions({
        throttleExecution: 25n,
        allowedRole: PUBLIC_ROLE
      })
    });

    // Mandate 6: Self select as delegate
    mandateInitData.push({
      nameDescription: "Become Delegate: Community members can self-select to become a Delegate",
      targetMandate: getInitialisedAddress("SelfSelect", deployedMandates),
      config: encodeAbiParameters(
        [{ name: 'roleId', type: 'uint256' }],
        [2n]
      ),
      conditions: createConditions({
        throttleExecution: 25n,
        allowedRole: 1n
      })
    });

    return mandateInitData;
  }
};
