// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Mandate } from "../../Mandate.sol";
import { MandateUtilities } from "../../libraries/MandateUtilities.sol";
import { IERC20 } from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IAllowanceModule {
    function getTokens(address safeTreasury, address delegate) external view returns (address[] memory);
}

contract Safe_RecoverTokens is Mandate {
    struct Mem {
        bytes config;
        address safeTreasury;
        address allowanceModule;
        address[] allowedTokens;
        uint256 count;
        uint256 positiveBalanceCount;
        address token;
        uint256 balance;
        uint256 currentIndex;
    }

    constructor() {
        bytes memory configParams = abi.encode("address safeTreasury", "address allowanceModule");
        emit Mandate__Deployed(configParams);
    }

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
        Mem memory mem;
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        // 1. Get config
        mem.config = getConfig(powers, mandateId);
        (mem.safeTreasury, mem.allowanceModule) = abi.decode(mem.config, (address, address));

        // 2. Get allowed tokens count
        mem.allowedTokens = IAllowanceModule(mem.allowanceModule).getTokens(mem.safeTreasury, powers);
        mem.count = mem.allowedTokens.length;
        // 3. Count tokens with positive balance
        mem.positiveBalanceCount = 0;
        for (uint256 i = 0; i < mem.count; i++) {
            if (IERC20(mem.allowedTokens[i]).balanceOf(powers) > 0) {
                mem.positiveBalanceCount++;
            }
        }

        // 4. Prepare return data
        targets = new address[](mem.positiveBalanceCount);
        values = new uint256[](mem.positiveBalanceCount);
        calldatas = new bytes[](mem.positiveBalanceCount);

        mem.currentIndex = 0;
        for (uint256 i = 0; i < mem.count; i++) {
            mem.token = mem.allowedTokens[i];
            mem.balance = IERC20(mem.token).balanceOf(powers);
            if (mem.balance > 0) {
                targets[mem.currentIndex] = mem.token;
                // values[currentIndex] = 0; // default is 0
                calldatas[mem.currentIndex] =
                    abi.encodeWithSelector(IERC20.transfer.selector, mem.safeTreasury, mem.balance);
                mem.currentIndex++;
            }
        }

        return (actionId, targets, values, calldatas);
    }
}
