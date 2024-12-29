// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

//  ██████╗ ███╗   ███╗███╗   ██╗███████╗███████╗
// ██╔═══██╗████╗ ████║████╗  ██║██╔════╝██╔════╝
// ██║   ██║██╔████╔██║██╔██╗ ██║█████╗  ███████╗
// ██║   ██║██║╚██╔╝██║██║╚██╗██║██╔══╝  ╚════██║
// ╚██████╔╝██║ ╚═╝ ██║██║ ╚████║███████╗███████║
//  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝

/// -----------------------------------------------------------------------
/// Imports
/// -----------------------------------------------------------------------

// ----- Internal imports -----

import {BytesLib} from "./BytesLib.sol";

/// -----------------------------------------------------------------------
/// Custom types
/// -----------------------------------------------------------------------

/**
 * @dev Data to make the call.
 * @param target: the target address;
 * @param callData: the calldata to be sent;
 * @param value: value in WEI to be sent with the call.
 */
struct Call {
    address target;
    bytes callData;
    uint256 value;
}

/**
 * @dev Data to make the static call.
 * @param target: the target address;
 * @param callData: the calldata to be sent.
 */
struct StaticCall {
    address target;
    bytes callData;
}

/**
 * @dev Data to make the static call.
 * @param target: the target address;
 * @param callData: the calldata to be sent.
 */
struct StaticCallWithFailure {
    address target;
    bytes callData;
    bool requireSuccess;
}

/**
 * @dev Static call types
 * @param STATIC_CALL: for `_aggregateStatic(StaticCall[])` function;
 * @param TRY_STATIC_CALL: for `_tryAggregateStatic(StaticCall[],bool)` function;
 * @param TRY_STATIC_CALL2: for `_tryAggregateStatic(StaticCallWithFailure[])` function;
 * @param CODE_LENGTH: for `_getCodeLengths(address[])` function;
 * @param SIMULATION: for `_simulateCalls(Call[])` function.
 */
enum CallType {
    STATIC_CALL,
    TRY_STATIC_CALL,
    TRY_STATIC_CALL2,
    CODE_LENGTH,
    SIMULATION
}

/// -----------------------------------------------------------------------
/// Library
/// -----------------------------------------------------------------------

/**
 * @title Multi call codec library.
 * @author Omnes Tech (Eduardo W. da Cunha - @EWCunha && Gustavo W. Deps - @G-Deps && Afonso Dalvi - @Afonsodalvi).
 */
library MultiCallCodec {
    /**
     * @dev Error for when an invalid multi call type is encountered.
     * @param type_: invalid type.
     */
    error MultiCallCodec__InvalidStaticCallType(uint8 type_);

    /**
     * @dev Decodes given value for call functions.
     * @param encoded: encoded value.
     * @return type_ multi call type;
     * @return staticCalls array of {StaticCall};
     * @return requireSuccess bool specifying if success is required;
     * @return staticCallsWithFailure array of {StaticCallWithFailure};
     * @return simulationCalls array of {Call}.
     */
    function decode(
        bytes memory encoded
    )
        internal
        pure
        returns (
            CallType type_,
            StaticCall[] memory staticCalls,
            bool requireSuccess,
            StaticCallWithFailure[] memory staticCallsWithFailure,
            Call[] memory simulationCalls,
            address[] memory addresses
        )
    {
        uint8 typeUit8 = uint8(encoded[0]);
        bytes memory encodedCall = BytesLib.slice(
            encoded,
            1,
            encoded.length - 1
        );
        if (typeUit8 == uint8(CallType.STATIC_CALL)) {
            staticCalls = abi.decode(encodedCall, (StaticCall[]));
        } else if (typeUit8 == uint8(CallType.TRY_STATIC_CALL)) {
            (staticCalls, requireSuccess) = abi.decode(
                encodedCall,
                (StaticCall[], bool)
            );
        } else if (typeUit8 == uint8(CallType.TRY_STATIC_CALL2)) {
            staticCallsWithFailure = abi.decode(
                encodedCall,
                (StaticCallWithFailure[])
            );
        } else if (typeUit8 == uint8(CallType.SIMULATION)) {
            simulationCalls = abi.decode(encodedCall, (Call[]));
        } else if (typeUit8 == uint8(CallType.CODE_LENGTH)) {
            addresses = abi.decode(encodedCall, (address[]));
        } else {
            revert MultiCallCodec__InvalidStaticCallType(typeUit8);
        }
        type_ = CallType(typeUit8);
    }
}
