// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script } from "forge-std/Script.sol";

contract Configurations is Script {
    error Configurations__UnsupportedChain();

    // @dev we only save the contract addresses of tokens, because any other params (name, symbol, etc) can and should be taken from contract itself.
    struct NetworkConfig {
        uint256 BLOCKS_PER_HOUR; // a basic way of establishing time. As long as block times are fairly stable on a chain, this will work.
        uint256 maxReturnDataLength; // for now these are all set at 10,000.
        uint256 maxCallDataLength; // for now these are all set at 10,000.
        uint256 maxExecutionsLength; // for now these are all set at 25.
        address chainlinkFunctionsRouter;
        uint64 chainlinkFunctionsSubscriptionId;
        uint32 chainlinkFunctionsGasLimit;
        bytes32 chainlinkFunctionsDonId;
        string chainlinkFunctionsEncryptedSecretsEndpoint;
        address safeCanonical;
        address safeL2Canonical;
        address safeProxyFactory;
        address safeAllowanceModule;
    }

    uint256 constant LOCAL_CHAIN_ID = 31_337;
    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11_155_111;
    uint256 constant OPT_SEPOLIA_CHAIN_ID = 11_155_420;
    uint256 constant ARB_SEPOLIA_CHAIN_ID = 421_614;
    uint256 constant BASE_SEPOLIA_CHAIN_ID = 84_532;
    uint256 constant MANTLE_SEPOLIA_CHAIN_ID = 5003;

    NetworkConfig public networkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[LOCAL_CHAIN_ID] = getOrCreateAnvilEthConfig();
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
        networkConfigs[ARB_SEPOLIA_CHAIN_ID] = getArbSepoliaConfig();
        networkConfigs[OPT_SEPOLIA_CHAIN_ID] = getOptSepoliaConfig();
        networkConfigs[BASE_SEPOLIA_CHAIN_ID] = getBaseSepoliaConfig();
        networkConfigs[MANTLE_SEPOLIA_CHAIN_ID] = getMantleSepoliaConfig();
    }

    function getConfig() public view returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public view returns (NetworkConfig memory) {
        if (networkConfigs[chainId].BLOCKS_PER_HOUR != 0) {
            return networkConfigs[chainId];
        } else {
            revert Configurations__UnsupportedChain();
        }
    }

    function getEthSepoliaConfig() public returns (NetworkConfig memory) {
        networkConfig.BLOCKS_PER_HOUR = 300; // new block every 12 seconds
        networkConfig.maxCallDataLength = 10_000;
        networkConfig.maxReturnDataLength = 10_000;
        networkConfig.maxExecutionsLength = 25;

        networkConfig.chainlinkFunctionsRouter = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
        networkConfig.chainlinkFunctionsSubscriptionId = 5819;
        networkConfig.chainlinkFunctionsGasLimit = 300_000;
        networkConfig.chainlinkFunctionsDonId = 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;
        networkConfig.chainlinkFunctionsEncryptedSecretsEndpoint = "https://01.functions-gateway.testnet.chain.link/";

        networkConfig.safeCanonical = 0x41675C099F32341bf84BFc5382aF534df5C7461a;
        networkConfig.safeL2Canonical = 0x29fcB43b46531BcA003ddC8FCB67FFE91900C762;
        networkConfig.safeProxyFactory = 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67;
        networkConfig.safeAllowanceModule = 0xCBE43419274415F51e66bd3136c4237172831b59; // self deployed allowance module on sepolia. Standard address: 0xAA46724893dedD72658219405185Fb0Fc91e091C;

        return networkConfig;
    }

    function getArbSepoliaConfig() public returns (NetworkConfig memory) {
        networkConfig.BLOCKS_PER_HOUR = 14_400; // new block every 0.25 seconds
        networkConfig.maxCallDataLength = 10_000;
        networkConfig.maxReturnDataLength = 10_000;
        networkConfig.maxExecutionsLength = 25;

        networkConfig.chainlinkFunctionsRouter = 0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C;
        networkConfig.chainlinkFunctionsSubscriptionId = 1;
        networkConfig.chainlinkFunctionsGasLimit = 300_000;
        networkConfig.chainlinkFunctionsDonId = 0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000;
        networkConfig.chainlinkFunctionsEncryptedSecretsEndpoint = "https://01.functions-gateway.testnet.chain.link/";

        networkConfig.safeCanonical = 0x41675C099F32341bf84BFc5382aF534df5C7461a;
        networkConfig.safeL2Canonical = 0x29fcB43b46531BcA003ddC8FCB67FFE91900C762;
        networkConfig.safeProxyFactory = 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67;
        networkConfig.safeAllowanceModule = 0x7320c89189364C9F0154Bfd3ddb510Fb252cB10C; // self deployed allowance module on ArbSepolia

        return networkConfig;
    }

    function getOptSepoliaConfig() public returns (NetworkConfig memory) {
        networkConfig.BLOCKS_PER_HOUR = 1800; // new block every 2 seconds
        networkConfig.maxCallDataLength = 10_000;
        networkConfig.maxReturnDataLength = 10_000;
        networkConfig.maxExecutionsLength = 25;

        networkConfig.chainlinkFunctionsRouter = 0xC17094E3A1348E5C7544D4fF8A36c28f2C6AAE28;
        networkConfig.chainlinkFunctionsSubscriptionId = 256;
        networkConfig.chainlinkFunctionsGasLimit = 300_000;
        networkConfig.chainlinkFunctionsDonId = 0x66756e2d6f7074696d69736d2d7365706f6c69612d3100000000000000000000;
        networkConfig.chainlinkFunctionsEncryptedSecretsEndpoint = "https://01.functions-gateway.testnet.chain.link/";

        networkConfig.safeCanonical = 0x41675C099F32341bf84BFc5382aF534df5C7461a;
        networkConfig.safeL2Canonical = 0x29fcB43b46531BcA003ddC8FCB67FFE91900C762;
        networkConfig.safeProxyFactory = 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67;
        networkConfig.safeAllowanceModule = 0xaff1B87A225846c50e147ceAd5baA68004ec0f7c; // self deployed allowance module on OptSepolia

        return networkConfig;
    }

    function getBaseSepoliaConfig() public returns (NetworkConfig memory) {
        networkConfig.BLOCKS_PER_HOUR = 1800; // new block every 2 seconds
        networkConfig.maxCallDataLength = 10_000;
        networkConfig.maxReturnDataLength = 10_000;
        networkConfig.maxExecutionsLength = 25;

        networkConfig.chainlinkFunctionsRouter = 0xf9B8fc078197181C841c296C876945aaa425B278;
        networkConfig.chainlinkFunctionsSubscriptionId = 1;
        networkConfig.chainlinkFunctionsGasLimit = 300_000;
        networkConfig.chainlinkFunctionsDonId = 0x66756e2d6f7074696d69736d2d7365706f6c69612d3100000000000000000000;
        networkConfig.chainlinkFunctionsEncryptedSecretsEndpoint = "https://01.functions-gateway.testnet.chain.link/";

        networkConfig.safeCanonical = 0x41675C099F32341bf84BFc5382aF534df5C7461a;
        networkConfig.safeL2Canonical = 0x29fcB43b46531BcA003ddC8FCB67FFE91900C762;
        networkConfig.safeProxyFactory = 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67;
        networkConfig.safeAllowanceModule = 0xAA46724893dedD72658219405185Fb0Fc91e091C;

        return networkConfig;
    }

    function getMantleSepoliaConfig() public returns (NetworkConfig memory) {
        networkConfig.BLOCKS_PER_HOUR = 360_000; // new block every 2 seconds
        networkConfig.maxCallDataLength = 10_000;
        networkConfig.maxReturnDataLength = 10_000;
        networkConfig.maxExecutionsLength = 25;

        networkConfig.chainlinkFunctionsRouter = 0x0000000000000000000000000000000000000000;
        networkConfig.chainlinkFunctionsSubscriptionId = 1;
        networkConfig.chainlinkFunctionsGasLimit = 300_000;
        networkConfig.chainlinkFunctionsDonId = 0x66756e2d6f7074696d69736d2d7365706f6c69612d3100000000000000000000;
        networkConfig.chainlinkFunctionsEncryptedSecretsEndpoint = "https://01.functions-gateway.testnet.chain.link/";

        networkConfig.safeCanonical = 0x0000000000000000000000000000000000000000;
        networkConfig.safeL2Canonical = 0x0000000000000000000000000000000000000000;
        networkConfig.safeProxyFactory = 0x0000000000000000000000000000000000000000;
        networkConfig.safeAllowanceModule = 0x0000000000000000000000000000000000000000;

        return networkConfig;
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        networkConfig.BLOCKS_PER_HOUR = 3600; // new block per 1 second
        networkConfig.maxCallDataLength = 10_000;
        networkConfig.maxReturnDataLength = 10_000;
        networkConfig.maxExecutionsLength = 25;

        networkConfig.chainlinkFunctionsRouter = 0x0000000000000000000000000000000000000000;
        networkConfig.chainlinkFunctionsSubscriptionId = 1;
        networkConfig.chainlinkFunctionsGasLimit = 300_000;
        networkConfig.chainlinkFunctionsDonId = 0x66756e2d6f7074696d69736d2d7365706f6c69612d3100000000000000000000;
        networkConfig.chainlinkFunctionsEncryptedSecretsEndpoint = "https://01.functions-gateway.testnet.chain.link/";

        networkConfig.safeCanonical = 0x0000000000000000000000000000000000000000;
        networkConfig.safeL2Canonical = 0x0000000000000000000000000000000000000000;
        networkConfig.safeProxyFactory = 0x0000000000000000000000000000000000000000;
        networkConfig.safeAllowanceModule = 0x0000000000000000000000000000000000000000;

        return networkConfig;
    }
}

//////////////////////////////////////////////////////////////////
//                      Acknowledgements                        //
//////////////////////////////////////////////////////////////////

/**
 * - Patrick Collins & Cyfrin: @https://updraft.cyfrin.io/courses/advanced-foundry/account-abstraction
 */
