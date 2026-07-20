// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";

contract Configurations is Script {
    error Configurations__UnsupportedChain();

    uint256 constant LOCAL_CHAIN_ID = 31_337;
    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11_155_111;
    uint256 constant OPT_SEPOLIA_CHAIN_ID = 11_155_420;
    uint256 constant ARB_SEPOLIA_CHAIN_ID = 421_614;
    uint256 constant BASE_SEPOLIA_CHAIN_ID = 84_532;
    uint256 constant MANTLE_SEPOLIA_CHAIN_ID = 5003;

    function getBlocksPerHour(uint256 chainId) public pure returns (uint256) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID) return 300;
        if (chainId == ARB_SEPOLIA_CHAIN_ID) return 300; // 14_400; it works with sepolia mainnet blocknumbers..
        if (chainId == OPT_SEPOLIA_CHAIN_ID) return 1800;
        if (chainId == BASE_SEPOLIA_CHAIN_ID) return 1800;
        if (chainId == MANTLE_SEPOLIA_CHAIN_ID) return 360_000;
        if (chainId == LOCAL_CHAIN_ID) return 3600;
        revert Configurations__UnsupportedChain();
    }

    function getMaxReturnDataLength(uint256 chainId) public pure returns (uint256) {
        if (
            chainId == ETH_SEPOLIA_CHAIN_ID || chainId == ARB_SEPOLIA_CHAIN_ID || chainId == OPT_SEPOLIA_CHAIN_ID
                || chainId == BASE_SEPOLIA_CHAIN_ID || chainId == MANTLE_SEPOLIA_CHAIN_ID || chainId == LOCAL_CHAIN_ID
        ) {
            return 10_000;
        }
        revert Configurations__UnsupportedChain();
    }

    function getMaxCallDataLength(uint256 chainId) public pure returns (uint256) {
        if (
            chainId == ETH_SEPOLIA_CHAIN_ID || chainId == ARB_SEPOLIA_CHAIN_ID || chainId == OPT_SEPOLIA_CHAIN_ID
                || chainId == BASE_SEPOLIA_CHAIN_ID || chainId == MANTLE_SEPOLIA_CHAIN_ID || chainId == LOCAL_CHAIN_ID
        ) {
            return 10_000;
        }
        revert Configurations__UnsupportedChain();
    }

    function getMaxExecutionsLength(uint256 chainId) public pure returns (uint256) {
        if (
            chainId == ETH_SEPOLIA_CHAIN_ID || chainId == ARB_SEPOLIA_CHAIN_ID || chainId == OPT_SEPOLIA_CHAIN_ID
                || chainId == BASE_SEPOLIA_CHAIN_ID || chainId == MANTLE_SEPOLIA_CHAIN_ID || chainId == LOCAL_CHAIN_ID
        ) {
            return 25;
        }
        revert Configurations__UnsupportedChain();
    }

    function getChainlinkFunctionsRouter(uint256 chainId) public pure returns (address) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID) return 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
        if (chainId == ARB_SEPOLIA_CHAIN_ID) return 0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C;
        if (chainId == OPT_SEPOLIA_CHAIN_ID) return 0xC17094E3A1348E5C7544D4fF8A36c28f2C6AAE28;
        if (chainId == BASE_SEPOLIA_CHAIN_ID) return 0xf9B8fc078197181C841c296C876945aaa425B278;
        if (chainId == MANTLE_SEPOLIA_CHAIN_ID) return 0x0000000000000000000000000000000000000000;
        if (chainId == LOCAL_CHAIN_ID) return 0x0000000000000000000000000000000000000000;
        revert Configurations__UnsupportedChain();
    }

    function getChainlinkFunctionsSubscriptionId(uint256 chainId) public pure returns (uint64) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID) return 5819;
        if (chainId == ARB_SEPOLIA_CHAIN_ID) return 1;
        if (chainId == OPT_SEPOLIA_CHAIN_ID) return 256;
        if (chainId == BASE_SEPOLIA_CHAIN_ID) return 1;
        if (chainId == MANTLE_SEPOLIA_CHAIN_ID) return 1;
        if (chainId == LOCAL_CHAIN_ID) return 1;
        revert Configurations__UnsupportedChain();
    }

    function getChainlinkFunctionsGasLimit(uint256 chainId) public pure returns (uint32) {
        if (
            chainId == ETH_SEPOLIA_CHAIN_ID || chainId == ARB_SEPOLIA_CHAIN_ID || chainId == OPT_SEPOLIA_CHAIN_ID
                || chainId == BASE_SEPOLIA_CHAIN_ID || chainId == MANTLE_SEPOLIA_CHAIN_ID || chainId == LOCAL_CHAIN_ID
        ) {
            return 300_000;
        }
        revert Configurations__UnsupportedChain();
    }

    function getChainlinkFunctionsDonId(uint256 chainId) public pure returns (bytes32) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID) return 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;
        if (chainId == ARB_SEPOLIA_CHAIN_ID) return 0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000;
        if (chainId == OPT_SEPOLIA_CHAIN_ID) return 0x66756e2d6f7074696d69736d2d7365706f6c69612d3100000000000000000000;
        if (chainId == BASE_SEPOLIA_CHAIN_ID) {
            return 0x66756e2d6f7074696d69736d2d7365706f6c69612d3100000000000000000000; // Using same as Optimism as per original file
        }
        if (chainId == MANTLE_SEPOLIA_CHAIN_ID) {
            return 0x66756e2d6f7074696d69736d2d7365706f6c69612d3100000000000000000000;
        }
        if (chainId == LOCAL_CHAIN_ID) return 0x66756e2d6f7074696d69736d2d7365706f6c69612d3100000000000000000000;
        revert Configurations__UnsupportedChain();
    }

    function getChainlinkFunctionsEncryptedSecretsEndpoint(uint256 chainId) public pure returns (string memory) {
        if (
            chainId == ETH_SEPOLIA_CHAIN_ID || chainId == ARB_SEPOLIA_CHAIN_ID || chainId == OPT_SEPOLIA_CHAIN_ID
                || chainId == BASE_SEPOLIA_CHAIN_ID || chainId == MANTLE_SEPOLIA_CHAIN_ID || chainId == LOCAL_CHAIN_ID
        ) {
            return "https://01.functions-gateway.testnet.chain.link/";
        }
        revert Configurations__UnsupportedChain();
    }

    function getSafeCanonical(uint256 chainId) public pure returns (address) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID) return 0x41675C099F32341bf84BFc5382aF534df5C7461a;
        if (chainId == ARB_SEPOLIA_CHAIN_ID) return 0x41675C099F32341bf84BFc5382aF534df5C7461a;
        if (chainId == OPT_SEPOLIA_CHAIN_ID) return 0x41675C099F32341bf84BFc5382aF534df5C7461a;
        if (chainId == BASE_SEPOLIA_CHAIN_ID) return 0x41675C099F32341bf84BFc5382aF534df5C7461a;
        if (chainId == MANTLE_SEPOLIA_CHAIN_ID) return 0x0000000000000000000000000000000000000000;
        if (chainId == LOCAL_CHAIN_ID) return 0x41675C099F32341bf84BFc5382aF534df5C7461a;
        revert Configurations__UnsupportedChain();
    }

    function getSafeL2Canonical(uint256 chainId) public pure returns (address) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID) return 0x29fcB43b46531BcA003ddC8FCB67FFE91900C762;
        if (chainId == ARB_SEPOLIA_CHAIN_ID) return 0x29fcB43b46531BcA003ddC8FCB67FFE91900C762;
        if (chainId == OPT_SEPOLIA_CHAIN_ID) return 0x29fcB43b46531BcA003ddC8FCB67FFE91900C762;
        if (chainId == BASE_SEPOLIA_CHAIN_ID) return 0x29fcB43b46531BcA003ddC8FCB67FFE91900C762;
        if (chainId == MANTLE_SEPOLIA_CHAIN_ID) return 0x0000000000000000000000000000000000000000;
        if (chainId == LOCAL_CHAIN_ID) return 0x29fcB43b46531BcA003ddC8FCB67FFE91900C762;
        revert Configurations__UnsupportedChain();
    }

    function getSafeProxyFactory(uint256 chainId) public pure returns (address) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID) return 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67;
        if (chainId == ARB_SEPOLIA_CHAIN_ID) return 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67;
        if (chainId == OPT_SEPOLIA_CHAIN_ID) return 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67;
        if (chainId == BASE_SEPOLIA_CHAIN_ID) return 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67;
        if (chainId == MANTLE_SEPOLIA_CHAIN_ID) return 0x0000000000000000000000000000000000000000;
        if (chainId == LOCAL_CHAIN_ID) return 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67;
        revert Configurations__UnsupportedChain();
    }

    function getSafeAllowanceModule(uint256 chainId) public pure returns (address) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID) return 0xCBE43419274415F51e66bd3136c4237172831b59;
        if (chainId == ARB_SEPOLIA_CHAIN_ID) return 0x7320c89189364C9F0154Bfd3ddb510Fb252cB10C;
        if (chainId == OPT_SEPOLIA_CHAIN_ID) return 0xaff1B87A225846c50e147ceAd5baA68004ec0f7c;
        if (chainId == BASE_SEPOLIA_CHAIN_ID) return 0xAA46724893dedD72658219405185Fb0Fc91e091C;
        if (chainId == MANTLE_SEPOLIA_CHAIN_ID) return 0x0000000000000000000000000000000000000000;
        if (chainId == LOCAL_CHAIN_ID) return 0xaff1B87A225846c50e147ceAd5baA68004ec0f7c;
        revert Configurations__UnsupportedChain();
    }

    // £todo: deploy and update this address.
    function getGoverned721(uint256 chainId) public pure returns (address) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID || chainId == LOCAL_CHAIN_ID) {
            return 0x0000000000000000000000000000000000000123;
        }
        return 0x0000000000000000000000000000000000000123;
    }

    function getZkPassportRegistry(uint256 chainId) public pure returns (address) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID || chainId == LOCAL_CHAIN_ID) {
            return 0xc554958CE7559eCcD08AEdbB8b72B1BE54Fde9ed;
        }
        return 0x0000000000000000000000000000000000000000;
    }

    function getZkPassportVerifier(uint256 chainId) public pure returns (address) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID || chainId == LOCAL_CHAIN_ID) {
            return 0x1D000001000EFD9a6371f4d90bB8920D5431c0D8;
        }
        return 0x0000000000000000000000000000000000000123;
    }

    function getZkPassportRootRegistry(uint256 chainId) public pure returns (address) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID || chainId == LOCAL_CHAIN_ID) {
            return 0x1D0000020038d6E40E1d98e09fA1bb3A7DAA8B70;
        }
        return 0x0000000000000000000000000000000000000123;
    }

    function getZkPassportHelper(uint256 chainId) public pure returns (address) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID || chainId == LOCAL_CHAIN_ID) {
            return 0xd76aA09811dE7c7871E9BFc25eB85F4634adA5C6;
        }
        return 0x0000000000000000000000000000000000000123;
    }

    function getMandateRegistry(uint256 chainId) public pure returns (address) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID) return 0x89b77a5eD85F6D442Cf703De8A03F286266de510; //
        if (chainId == ARB_SEPOLIA_CHAIN_ID) return 0x89b77a5eD85F6D442Cf703De8A03F286266de510;
        if (chainId == OPT_SEPOLIA_CHAIN_ID) return 0x0000000000000000000000000000000000000000;
        if (chainId == BASE_SEPOLIA_CHAIN_ID) return 0x0000000000000000000000000000000000000000;
        if (chainId == MANTLE_SEPOLIA_CHAIN_ID) return 0x0000000000000000000000000000000000000000;
        if (chainId == LOCAL_CHAIN_ID) return 0x0000000000000000000000000000000000000000;
        revert Configurations__UnsupportedChain();
    }

    /// @notice Global credit -> wei exchange rate to seed the MandateRegistry with on deploy.
    /// @dev Mandates declare their price in credits; the registry multiplies by this to get the wei
    ///      cost at adoption. Tune per network so one credit maps to a sensible fiat-ish amount.
    function getWeiPerCredit(uint256 chainId) public pure returns (uint256) {
        if (
            chainId == ETH_SEPOLIA_CHAIN_ID || chainId == ARB_SEPOLIA_CHAIN_ID || chainId == OPT_SEPOLIA_CHAIN_ID
                || chainId == BASE_SEPOLIA_CHAIN_ID || chainId == MANTLE_SEPOLIA_CHAIN_ID || chainId == LOCAL_CHAIN_ID
        ) {
            return 1e14; // 0.0001 ETH per credit
        }
        revert Configurations__UnsupportedChain();
    }

    function get4337EntryPoint(uint256 chainId) public pure returns (address) {
        if (
            chainId == ETH_SEPOLIA_CHAIN_ID || chainId == ARB_SEPOLIA_CHAIN_ID || chainId == OPT_SEPOLIA_CHAIN_ID
                || chainId == BASE_SEPOLIA_CHAIN_ID || chainId == MANTLE_SEPOLIA_CHAIN_ID || chainId == LOCAL_CHAIN_ID
        ) {
            return 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
        }
        revert Configurations__UnsupportedChain();
    }

    function getSubmitMandateId(uint256 chainId) public pure returns (uint16) {
        if (
            chainId == ETH_SEPOLIA_CHAIN_ID || chainId == ARB_SEPOLIA_CHAIN_ID || chainId == OPT_SEPOLIA_CHAIN_ID
                || chainId == BASE_SEPOLIA_CHAIN_ID || chainId == MANTLE_SEPOLIA_CHAIN_ID || chainId == LOCAL_CHAIN_ID
        ) {
            return 4;
        }
        return 0;
    }
}
