// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Mandate } from "@src/Mandate.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";
import { ZKPassport_PowersRegistry } from "@src/addons/helpers/ZKPassport_PowersRegistry.sol";
import { DisclosedData } from "@lib/zkpassport-packages/packages/registry-contracts/src/lib/Types.sol";

/// @title ZKPassport Check Mandate
/// @notice Checks if a caller has a valid ZKPassport proof registered with specific data.
/// @author 7Cedars

/// NB: a list of available checks and their functionSelectors is appended below.
/// NB 2: You can only run one check at a time on the registry. If you want to run multiple checks, you need to create multiple mandates with different configs in a single chain.
contract ZKPassport_Check is Mandate {
    //////////////////////////////////////////////////////////////
    //                       STRUCTS                            //
    //////////////////////////////////////////////////////////////
    struct Mem {
        bool verified;
        string[] inputParams;
        address registry;
        uint256 staleAfterSeconds;
        bool facematchRequired;
        bytes4 functionSelector;
        bytes input;
        address accountToCheck;
        uint256 proofTimestamp;
        bool success;
        DisclosedData disclosedData;
    }

    //////////////////////////////////////////////////////////////
    //                   MANDATE EXECUTION                      //
    //////////////////////////////////////////////////////////////
    constructor(address registry_) Mandate(registry_) {
        bytes memory configParams = abi.encode(
            "string[] inputParams", // NB: these input params are not used in the actual contract. By changing the inputParams, the mandate can be places in a broader governance flow. See StatementOfIntent.sol for a similar approach.
            "address registry",
            "uint256 staleAfterSeconds",
            "bool facematchRequired",
            "bytes4 functionSelector",
            "bytes input"
        );
        emit Mandate__Deployed(configParams);
    }

    function initializeMandate(uint16 index, string memory nameDescription, bytes memory, bytes memory config)
        public
        override
    {
        (string[] memory params_,,,,,) = abi.decode(config, (string[], address, uint256, bool, bytes4, bytes));

        string[] memory newParams_ = new string[](params_.length + 1);
        for (uint256 i; i < params_.length; i++) {
            newParams_[i] = params_[i];
        }
        newParams_[params_.length] = "address AccountToCheck";
        super.initializeMandate(index, nameDescription, abi.encode(newParams_), config);
    }

    /// @inheritdoc Mandate
    function handleRequest(
        address caller,
        address powers,
        uint16 mandateId,
        bytes calldata mandateCalldata,
        uint256 nonce
    )
        public
        view
        override
        returns (uint256 actionId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        // Decode config
        Mem memory mem;
        (mem.inputParams, mem.registry, mem.staleAfterSeconds, mem.facematchRequired, mem.functionSelector, mem.input) =
            abi.decode(getConfig(powers, mandateId), (string[], address, uint256, bool, bytes4, bytes));
        // "address AccountToCheck" is appended last in initializeMandate, so read from position mem.inputParams.length.
        mem.accountToCheck = abi.decode(mandateCalldata[mem.inputParams.length * 32:], (address));

        // 1. validate inputs
        if (mem.registry == address(0)) revert("ZKPassport: Invalid registry address");
        if (mem.accountToCheck == address(0)) revert("ZKPassport: Invalid zero address for account to check");
        if (mem.accountToCheck != caller) revert("ZKPassport: Caller is not the account to check");

        ZKPassport_PowersRegistry registry = ZKPassport_PowersRegistry(mem.registry);
        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);

        // 2. check that the proof is not stale
        mem.proofTimestamp = registry.getProofTimestamp(mem.accountToCheck);
        require(block.timestamp - mem.proofTimestamp < mem.staleAfterSeconds, "Proof is stale");

        // 3. check that the FaceMatch requirement is met (if required)
        if (mem.facematchRequired) {
            require(registry.getIsFacematched(mem.accountToCheck), "FaceMatch requirement not met");
        }

        // 4. retrieve disclosed data
        mem.disclosedData = registry.getDisclosed(mem.accountToCheck);

        // 5. call internal function to check against disclosed data
        if (mem.functionSelector == bytes4(keccak256("isAgeAbove(uint8)"))) {
            mem.success = _verifyAgeAbove(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isAgeAboveOrEqual(uint8)"))) {
            mem.success = _verifyAgeAboveOrEqual(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isAgeBelow(uint8)"))) {
            mem.success = _verifyAgeBelow(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isAgeBelowOrEqual(uint8)"))) {
            mem.success = _verifyAgeBelowOrEqual(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isAgeBetween(uint8,uint8)"))) {
            mem.success = _verifyAgeBetween(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isAgeEqual(uint8)"))) {
            mem.success = _verifyAgeEqual(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isBirthdateAfter(uint256)"))) {
            mem.success = _verifyBirthdateAfter(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isBirthdateAfterOrEqual(uint256)"))) {
            mem.success = _verifyBirthdateAfterOrEqual(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isBirthdateBefore(uint256)"))) {
            mem.success = _verifyBirthdateBefore(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isBirthdateBeforeOrEqual(uint256)"))) {
            mem.success = _verifyBirthdateBeforeOrEqual(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isBirthdateBetween(uint256,uint256)"))) {
            mem.success = _verifyBirthdateBetween(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isBirthdateEqual(uint256)"))) {
            mem.success = _verifyBirthdateEqual(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isExpiryDateAfter(uint256)"))) {
            mem.success = _verifyExpiryDateAfter(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isExpiryDateAfterOrEqual(uint256)"))) {
            mem.success = _verifyExpiryDateAfterOrEqual(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isExpiryDateBefore(uint256)"))) {
            mem.success = _verifyExpiryDateBefore(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isExpiryDateBeforeOrEqual(uint256)"))) {
            mem.success = _verifyExpiryDateBeforeOrEqual(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isExpiryDateBetween(uint256,uint256)"))) {
            mem.success = _verifyExpiryDateBetween(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isExpiryDateEqual(uint256)"))) {
            mem.success = _verifyExpiryDateEqual(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isIssuingCountryIn(string[])"))) {
            mem.success = _verifyIssuingCountryIn(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isIssuingCountryOut(string[])"))) {
            mem.success = _verifyIssuingCountryOut(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isNationalityIn(string[])"))) {
            mem.success = _verifyNationalityIn(mem.input, mem.disclosedData);
        } else if (mem.functionSelector == bytes4(keccak256("isNationalityOut(string[])"))) {
            mem.success = _verifyNationalityOut(mem.input, mem.disclosedData);
        } else {
            revert("Unsupported function selector");
        }

        if (!mem.success) {
            revert("ZKPassport: Proof verification failed");
        }

        (targets, values, calldatas) = MandateUtilities.createEmptyArrays(1);
        calldatas[0] = abi.encode(caller);
        return (actionId, targets, values, calldatas);
    }

    //////////////////////////////////////////////////////////////
    //                       CHECKS                             //
    //////////////////////////////////////////////////////////////
    function _verifyAgeAbove(bytes memory input, DisclosedData memory data) internal view returns (bool) {
        uint8 threshold = abi.decode(input, (uint8));
        return _calculateAge(data.birthDate) > threshold;
    }

    function _verifyAgeAboveOrEqual(bytes memory input, DisclosedData memory data) internal view returns (bool) {
        uint8 threshold = abi.decode(input, (uint8));
        return _calculateAge(data.birthDate) >= threshold;
    }

    function _verifyAgeBelow(bytes memory input, DisclosedData memory data) internal view returns (bool) {
        uint8 threshold = abi.decode(input, (uint8));
        return _calculateAge(data.birthDate) < threshold;
    }

    function _verifyAgeBelowOrEqual(bytes memory input, DisclosedData memory data) internal view returns (bool) {
        uint8 threshold = abi.decode(input, (uint8));
        return _calculateAge(data.birthDate) <= threshold;
    }

    function _verifyAgeBetween(bytes memory input, DisclosedData memory data) internal view returns (bool) {
        (uint8 lower, uint8 upper) = abi.decode(input, (uint8, uint8));
        uint256 age = _calculateAge(data.birthDate);
        return age >= lower && age <= upper;
    }

    function _verifyAgeEqual(bytes memory input, DisclosedData memory data) internal view returns (bool) {
        uint8 threshold = abi.decode(input, (uint8));
        return _calculateAge(data.birthDate) == threshold;
    }

    function _verifyBirthdateAfter(bytes memory input, DisclosedData memory data) internal view returns (bool) {
        uint256 timestamp = abi.decode(input, (uint256));
        return _mrzToYYYYMMDD(data.birthDate, false) > _timestampToYYYYMMDD(timestamp);
    }

    function _verifyBirthdateAfterOrEqual(bytes memory input, DisclosedData memory data) internal view returns (bool) {
        uint256 timestamp = abi.decode(input, (uint256));
        return _mrzToYYYYMMDD(data.birthDate, false) >= _timestampToYYYYMMDD(timestamp);
    }

    function _verifyBirthdateBefore(bytes memory input, DisclosedData memory data) internal view returns (bool) {
        uint256 timestamp = abi.decode(input, (uint256));
        return _mrzToYYYYMMDD(data.birthDate, false) < _timestampToYYYYMMDD(timestamp);
    }

    function _verifyBirthdateBeforeOrEqual(bytes memory input, DisclosedData memory data) internal view returns (bool) {
        uint256 timestamp = abi.decode(input, (uint256));
        return _mrzToYYYYMMDD(data.birthDate, false) <= _timestampToYYYYMMDD(timestamp);
    }

    function _verifyBirthdateBetween(bytes memory input, DisclosedData memory data) internal view returns (bool) {
        (uint256 tLower, uint256 tUpper) = abi.decode(input, (uint256, uint256));
        uint256 bYYYYMMDD = _mrzToYYYYMMDD(data.birthDate, false);
        return bYYYYMMDD >= _timestampToYYYYMMDD(tLower) && bYYYYMMDD <= _timestampToYYYYMMDD(tUpper);
    }

    function _verifyBirthdateEqual(bytes memory input, DisclosedData memory data) internal view returns (bool) {
        uint256 timestamp = abi.decode(input, (uint256));
        return _mrzToYYYYMMDD(data.birthDate, false) == _timestampToYYYYMMDD(timestamp);
    }

    function _verifyExpiryDateAfter(bytes memory input, DisclosedData memory data) internal view returns (bool) {
        uint256 timestamp = abi.decode(input, (uint256));
        return _mrzToYYYYMMDD(data.expiryDate, true) > _timestampToYYYYMMDD(timestamp);
    }

    function _verifyExpiryDateAfterOrEqual(bytes memory input, DisclosedData memory data) internal view returns (bool) {
        uint256 timestamp = abi.decode(input, (uint256));
        return _mrzToYYYYMMDD(data.expiryDate, true) >= _timestampToYYYYMMDD(timestamp);
    }

    function _verifyExpiryDateBefore(bytes memory input, DisclosedData memory data) internal view returns (bool) {
        uint256 timestamp = abi.decode(input, (uint256));
        return _mrzToYYYYMMDD(data.expiryDate, true) < _timestampToYYYYMMDD(timestamp);
    }

    function _verifyExpiryDateBeforeOrEqual(bytes memory input, DisclosedData memory data)
        internal
        view
        returns (bool)
    {
        uint256 timestamp = abi.decode(input, (uint256));
        return _mrzToYYYYMMDD(data.expiryDate, true) <= _timestampToYYYYMMDD(timestamp);
    }

    function _verifyExpiryDateBetween(bytes memory input, DisclosedData memory data) internal view returns (bool) {
        (uint256 tLower, uint256 tUpper) = abi.decode(input, (uint256, uint256));
        uint256 eYYYYMMDD = _mrzToYYYYMMDD(data.expiryDate, true);
        return eYYYYMMDD >= _timestampToYYYYMMDD(tLower) && eYYYYMMDD <= _timestampToYYYYMMDD(tUpper);
    }

    function _verifyExpiryDateEqual(bytes memory input, DisclosedData memory data) internal view returns (bool) {
        uint256 timestamp = abi.decode(input, (uint256));
        return _mrzToYYYYMMDD(data.expiryDate, true) == _timestampToYYYYMMDD(timestamp);
    }

    function _verifyIssuingCountryIn(bytes memory input, DisclosedData memory data) internal pure returns (bool) {
        string[] memory countries = abi.decode(input, (string[]));
        for (uint256 i = 0; i < countries.length; i++) {
            if (keccak256(bytes(countries[i])) == keccak256(bytes(data.issuingCountry))) {
                return true;
            }
        }
        return false;
    }

    function _verifyIssuingCountryOut(bytes memory input, DisclosedData memory data) internal pure returns (bool) {
        string[] memory countries = abi.decode(input, (string[]));
        for (uint256 i = 0; i < countries.length; i++) {
            if (keccak256(bytes(countries[i])) == keccak256(bytes(data.issuingCountry))) {
                return false;
            }
        }
        return true;
    }

    function _verifyNationalityIn(bytes memory input, DisclosedData memory data) internal pure returns (bool) {
        string[] memory nationalities = abi.decode(input, (string[]));
        for (uint256 i = 0; i < nationalities.length; i++) {
            if (keccak256(bytes(nationalities[i])) == keccak256(bytes(data.nationality))) {
                return true;
            }
        }
        return false;
    }

    function _verifyNationalityOut(bytes memory input, DisclosedData memory data) internal pure returns (bool) {
        string[] memory nationalities = abi.decode(input, (string[]));
        for (uint256 i = 0; i < nationalities.length; i++) {
            if (keccak256(bytes(nationalities[i])) == keccak256(bytes(data.nationality))) {
                return false;
            }
        }
        return true;
    }

    //////////////////////////////////////////////////////////////
    //                   HELPER FUNCTIONS                       //
    //////////////////////////////////////////////////////////////

    function _calculateAge(string memory birthDate) internal view returns (uint256) {
        uint256 bYYYYMMDD = _mrzToYYYYMMDD(birthDate, false);
        uint256 cYYYYMMDD = _timestampToYYYYMMDD(block.timestamp);

        if (cYYYYMMDD < bYYYYMMDD) return 0; // Should not happen
        return (cYYYYMMDD - bYYYYMMDD) / 10_000;
    }

    function _mrzToYYYYMMDD(string memory mrz, bool isExpiry) internal view returns (uint256) {
        bytes memory d = bytes(mrz);
        require(d.length == 6, "Invalid MRZ date length");
        uint256 yy = _stringToUint(string(abi.encodePacked(d[0], d[1])));
        uint256 mm = _stringToUint(string(abi.encodePacked(d[2], d[3])));
        uint256 dd = _stringToUint(string(abi.encodePacked(d[4], d[5])));

        uint256 currentYYYYMMDD = _timestampToYYYYMMDD(block.timestamp);
        uint256 currentYY = (currentYYYYMMDD / 10_000) % 100;

        uint256 year;
        if (isExpiry) {
            // Expiry: assume 2000+ if yy is within reasonable future/past window relative to currentYY
            // If yy < currentYY + 50, assume 2000+yy. Else 1900+yy.
            if (yy < currentYY + 50) {
                year = 2000 + yy;
            } else {
                year = 1900 + yy;
            }
        } else {
            // Birthdate: assume 1900+ if yy > currentYY, else 2000+
            if (yy > currentYY) {
                year = 1900 + yy;
            } else {
                year = 2000 + yy;
            }
        }

        return year * 10_000 + mm * 100 + dd;
    }

    function _timestampToYYYYMMDD(uint256 timestamp) internal pure returns (uint256) {
        (uint256 y, uint256 m, uint256 d) = _timestampToDate(timestamp);
        return y * 10_000 + m * 100 + d;
    }

    function _timestampToDate(uint256 timestamp) internal pure returns (uint256 year, uint256 month, uint256 day) {
        uint256 z = timestamp / 86_400 + 719_468;
        uint256 era = (z >= 0 ? z : z - 146_096) / 146_097;
        uint256 doe = z - era * 146_097;
        uint256 ydoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
        uint256 y = ydoe + era * 400;
        uint256 doy = doe - (365 * ydoe + ydoe / 4 - ydoe / 100);
        uint256 mp = (5 * doy + 2) / 153;
        day = doy - (153 * mp + 2) / 5 + 1;
        month = mp < 10 ? mp + 3 : mp - 9;
        year = y + (month <= 2 ? 1 : 0);
    }

    function _stringToUint(string memory s) internal pure returns (uint256 result) {
        bytes memory b = bytes(s);
        uint256 i;
        result = 0;
        for (i = 0; i < b.length; i++) {
            uint8 c = uint8(b[i]);
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
    }
}
