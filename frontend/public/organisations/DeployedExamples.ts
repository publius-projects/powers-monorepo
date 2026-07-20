import { sepolia, arbitrumSepolia, optimismSepolia, foundry } from "@wagmi/core/chains";

export const DeployedExamples = [
    // {
    //     id: "governed-721",
    //     title: "Governed 721",
    //     uri: "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeibcfc5dzcah2xxmvk3gjhij7t3sp5v6ppkub36jmtex2t75fcz22i/organisation.json",
    //     banner: "/powered/landing%20page%20images/governed_721.png",
    //     description: "Governed 721 is an example of an organisation that governs specific functionality in a Protocol. In this case: setting payment split for royalties of NFT sales. It has a policy setting (the split) and enforcement (blacklisting of addresses). This type of organisation can be used to govern specific parameters or functionalities in a larger ecosystem, such as a protocol or platform.",
    //     chainId: arbitrumSepolia.id,
    //     address: '0xaa3146fBa89b6e93303c397f76B2cC36545372D0'
    // },
    {
        id: "staking-pool-governance",
        title: "Staking Pool Governance",
        uri: "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreiejezgv4itvryovwbuatrxjbsxt4p536bcp6fepdzh5z2n3aqjici",
        banner: "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeiazll4pqkkhhpzrxv7vljfkhx4ez4i5ors7u4np7l26zjxg3sxybu",
        description: "Staking Pool Governance is a demonstration organisation in which the Powers protocol owns and governs a SimpleStakingPool — an on-chain pool where users stake one token and earn another. Powers drives the pool's privileged knobs (reward rate, emergency pause, token sweep, reward funding) through mandates, distributing power across five roles with deliberate checks and balances: the Rate Committee proposes rate changes and sweeps, Stakers hold a veto and a timelock, and a Guardian and Compliance Monitor can pause staking instantly while un-pausing requires a Staker vote. An ERC-4337 paymaster sponsors gas so members can participate without holding ETH. NOTE: this is a reference/demonstration design, not a compliant production system.",
        chainId: arbitrumSepolia.id,
        address: '0x1625eB24df6571Ae13ebD9Cc3bd82b5F1E38405a'
    },
    // }, 
    {
        id: "bicameralism",
        title: "Bicameralism",
        uri: "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeiaoyanrreocw5yvgoykf2nq2rfusjbxqq5j66ba3r4dix23llyecu/bicameralism.json",
        banner: "/powered/landing%20page%20images/bimercalism.png",
        description: "In Bicameralism, the governance system is divided into two separate chambers or houses, each with its own distinct powers and responsibilities. In this example Delegates can initiate an action, but it can only be executed by Funders. A version of Bicameralism is implemented at the Optimism Collective.",
        chainId: arbitrumSepolia.id,
        address: '0x9b16B31FF15535F871d8017b1Cca682E65E49ee1'
    },
    {
        id: "optimistic-execution",
        title: "Optimistic Execution",
        uri: "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeiaoyanrreocw5yvgoykf2nq2rfusjbxqq5j66ba3r4dix23llyecu/optimisticExecution.json",
        banner: "/powered/landing%20page%20images/optimistic_execution.png",
        description: "In Optimistic Execution, the Powers protocol leverages optimistic mechanisms to enable faster decision-making processes by assuming proposals are valid unless challenged. This approach can improve efficiency while still allowing for dispute resolution through challenges. A similar mechanism is currently used by the Optimism Collective.",
        chainId: arbitrumSepolia.id,
        address: '0x455810765b497519869187eCf57424611a83709E'
    },
    {
        id: "nested-governance-parent",
        title: "Nested Governance",
        uri: "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeiaoyanrreocw5yvgoykf2nq2rfusjbxqq5j66ba3r4dix23llyecu/nestedGovernance-parent.json",
        banner: "/powered/landing%20page%20images/nested_governance.png",
        description: "Nested Governance demonstrates how the Powers protocol can be used to layer governance within each other to create complex decision-making hierarchies. This example is a single parent organisation that governs a child, but any type of complex structure can be created. The notion of sub-DAOs is similar to nested governance.",
        chainId: arbitrumSepolia.id,
        address: '0x0CE0eB29E56cead1499061991de07Cf86658740a'
    },
    {
        id: "open-elections",
        title: "Election Lists",
        uri: "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeiaoyanrreocw5yvgoykf2nq2rfusjbxqq5j66ba3r4dix23llyecu/electionListDao.json",
        banner: "/powered/landing%20page%20images/election_lists.png",
        description: "Election lists demonstrates how, using the Powers protocol, electoral lists can be used to assign roles to accounts. (These type of approaches are becoming more popular, see for instance the elections for Arbitrum's Security council, or multiple options votes). The specific logic used for an electoral list can be customised in its mandate implementation.",
        chainId: arbitrumSepolia.id,
        address: '0x5F44F12114d352eF191557Fb7a7202D96035d883'
    },
    {
        id: "token-delegates",
        title: "Token Delegates",
        uri: "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeiaoyanrreocw5yvgoykf2nq2rfusjbxqq5j66ba3r4dix23llyecu/tokenDelegates.json",
        banner: "/powered/landing%20page%20images/token_delegates.png",
        description: "One-token-one-vote is the most popular approach to DAO governance today, despite its many shortcomings. This Token Delegate example demonstrates how the Powers protocol can be used to give power to accounts along the amount of  delegated tokens they hold. There is one key difference with traditional approaches: after delegates have been selected, they all hold the same amount of power (similar to democratic elections) while in classic DAO governance inequality in votes is reflected in delegates power.",
        chainId: arbitrumSepolia.id,
        address: '0xc80A4747AA3562E23497e7E3570B10dA3A0F706D'
    }, 
    {
        id: "account-abstraction",
        title: "Account Abstraction",
        uri: "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeibcfc5dzcah2xxmvk3gjhij7t3sp5v6ppkub36jmtex2t75fcz22i/organisation.json",
        banner: "/powered/landing%20page%20images/account_abstraction.png",
        description: "Account Abstraction is an example of using ERC-4337 to sponsor gas cost for users interacting with an organisation governed by the Powers protocol. This allows users to interact with the organisation without needing to hold the native token of the chain, improving accessibility and user experience.",
        chainId: arbitrumSepolia.id,
        address: '0x2D95D1b1562a12C4220F29414837b238Dcf3430c'
    },
    {
        id: "powers101",
        title: "Powers 101",
        uri: "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeiaoyanrreocw5yvgoykf2nq2rfusjbxqq5j66ba3r4dix23llyecu/powers101.json",
        banner: "/powered/landing%20page%20images/powers_101.png",
        description: "A base example of an on-chain organisation that uses the Powers protocol to govern itself and create a simple check and balance system.",
        chainId: arbitrumSepolia.id,
        address: '0x6D5A3A936bb1e5434ad60E58E58848Bd67Afb79B'
    },
]
