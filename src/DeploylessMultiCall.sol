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

import {MultiCallCodec, Call, StaticCall, StaticCallWithFailure, CallType} from "./MultiCallCodec.sol";

/// -----------------------------------------------------------------------
/// Contract
/// -----------------------------------------------------------------------

/**
 * @title Deployless multi call.
 * @author Omnes Tech (Eduardo W. da Cunha - @EWCunha && Gustavo W. Deps - @G-Deps && Afonso Dalvi - @Afonsodalvi).
 * @notice Useful for sending multi calls and consuming only one RPC call.
 */
contract DeploylessMultiCall {
    /// -----------------------------------------------------------------------
    /// Custom errors
    /// -----------------------------------------------------------------------

    /**
     * @dev Error for the multi call simulation.
     * @param results: array of {SimulatedResult} with the result of each call simulation.
     */
    error MultiCall__Simulation(SimulatedResult[] results);

    /**
     * @dev Error for when a static call fails.
     * @param index: index of the call.
     */
    error MultiCall__StaticCallFailed(uint256 index);

    /// @dev Error for when WEI is sent to this contract.
    error MultiCall__SendingValueNotAllowed();

    /// -----------------------------------------------------------------------
    /// Custom types
    /// -----------------------------------------------------------------------

    /**
     * @dev The result of the static call.
     * @param success: whether or not the static call has been successful;
     * @param returnData: the data returned.
     */
    struct Result {
        bool success;
        bytes returnData;
    }

    /**
     * @dev The result of the static call.
     * @param success: whether or not the static call has been successful;
     * @param returnData: the data returned;
     * @param gasUsed: amount of gas used by the call.
     */
    struct SimulatedResult {
        bool success;
        bytes returnData;
        uint256 gasUsed;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    /**
     * @notice Used for deployless simulation or static call.
     * Returns either simulation or static call results.
     */
    constructor(bytes memory callData) payable {
        (
            CallType type_,
            StaticCall[] memory staticCalls,
            bool requireSuccess,
            StaticCallWithFailure[] memory staticCallsWithFailure,
            Call[] memory simulationCalls,
            address[] memory addresses
        ) = MultiCallCodec.decode(callData);
        if (type_ == CallType.STATIC_CALL) {
            bytes[] memory results = _aggregateStatic(staticCalls);
            assembly {
                return(results, returndatasize())
            }
        } else if (type_ == CallType.TRY_STATIC_CALL) {
            Result[] memory results = _tryAggregateStatic(
                staticCalls,
                requireSuccess
            );
            assembly {
                return(results, returndatasize())
            }
        } else if (type_ == CallType.TRY_STATIC_CALL2) {
            Result[] memory results = _tryAggregateStatic(
                staticCallsWithFailure
            );
            assembly {
                return(results, returndatasize())
            }
        } else if (type_ == CallType.CODE_LENGTH) {
            uint256[] memory lengths = _getCodeLengths(addresses);
            assembly {
                return(lengths, returndatasize())
            }
        } else {
            _simulateCalls(simulationCalls);
        }
    }

    /// -----------------------------------------------------------------------
    /// Internal functions (for deployless calls)
    /// -----------------------------------------------------------------------

    // ----- Simulate calls -----

    /**
     * @notice Simulates calls. It always reverts with the simulation results.
     * @param calls: array of calls to be executed.
     */
    function _simulateCalls(Call[] memory calls) internal {
        SimulatedResult[] memory results = new SimulatedResult[](calls.length);
        for (uint256 i = 0; i < calls.length; ) {
            uint256 gasBefore = gasleft();
            (bool success, bytes memory returnData) = calls[i].target.call{
                value: calls[i].value
            }(calls[i].callData);

            results[i] = SimulatedResult({
                success: success,
                returnData: returnData,
                gasUsed: gasBefore - gasleft()
            });

            unchecked {
                ++i;
            }
        }

        revert MultiCall__Simulation(results);
    }

    // ----- Static calls -----

    /**
     * @notice Executes several static calls.
     * @dev Reverts if any call fails.
     * @param calls: array of calls to be executed.
     * @return returnData - bytes[] - array of returned data.
     */
    function _aggregateStatic(
        StaticCall[] memory calls
    ) internal view returns (bytes[] memory returnData) {
        returnData = new bytes[](calls.length);
        for (uint256 i = calls.length; i > 0; ) {
            bool success;
            (success, returnData[i - 1]) = calls[i - 1].target.staticcall(
                calls[i - 1].callData
            );

            require(success, MultiCall__StaticCallFailed(i - 1));

            unchecked {
                --i;
            }
        }
    }

    /**
     * @notice Executes several static calls.
     * @dev Reverts if any call fails AND if `requireSuccess` is set to true.
     * @param calls: array of calls to be executed;
     * @param requireSuccess: whether or not to revert if any call fails.
     * @return returnData - Result[] - array of returned data encoded in {Result} struct.
     */
    function _tryAggregateStatic(
        StaticCall[] memory calls,
        bool requireSuccess
    ) internal view returns (Result[] memory returnData) {
        returnData = new Result[](calls.length);
        for (uint256 i = calls.length; i > 0; ) {
            Result memory result = returnData[i - 1];
            (result.success, result.returnData) = calls[i - 1]
                .target
                .staticcall(calls[i - 1].callData);

            if (requireSuccess) {
                require(result.success, MultiCall__StaticCallFailed(i - 1));
            }

            unchecked {
                --i;
            }
        }
    }

    /**
     * @notice Executes several static calls.
     * @dev Reverts if any call fails AND if `requireSuccess` is set to true.
     * @param calls: array of calls to be executed;
     * @return returnData - Result[] - array of returned data encoded in {Result} struct.
     */
    function _tryAggregateStatic(
        StaticCallWithFailure[] memory calls
    ) internal view returns (Result[] memory returnData) {
        returnData = new Result[](calls.length);
        for (uint256 i = calls.length; i > 0; ) {
            Result memory result = returnData[i - 1];
            (result.success, result.returnData) = calls[i - 1]
                .target
                .staticcall(calls[i - 1].callData);

            if (calls[i - 1].requireSuccess) {
                require(result.success, MultiCall__StaticCallFailed(i - 1));
            }

            unchecked {
                --i;
            }
        }
    }

    /**
     * @notice Gets the code length for each given address. Useful for checking if an
     * address is a contract.
     * @param targets: array of target addresses.
     * @return lengths - uint256[] - array of length of codes for each target address.
     */
    function _getCodeLengths(
        address[] memory targets
    ) internal view returns (uint256[] memory lengths) {
        lengths = new uint256[](targets.length);
        for (uint256 i = targets.length; i > 0; ) {
            lengths[i - 1] = targets[i - 1].code.length;

            unchecked {
                --i;
            }
        }
    }
}
