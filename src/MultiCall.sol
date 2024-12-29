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

import {Call, StaticCall, StaticCallWithFailure} from "./MultiCallCodec.sol";

/// -----------------------------------------------------------------------
/// Contract
/// -----------------------------------------------------------------------

/**
 * @title Multi call.
 * @author Omnes Tech (Eduardo W. da Cunha - @EWCunha && Gustavo W. Deps - @G-Deps && Afonso Dalvi - @Afonsodalvi).
 * @notice Useful for sending multi calls and consuming only one RPC call.
 */
contract MultiCall {
    /// -----------------------------------------------------------------------
    /// Custom errors
    /// -----------------------------------------------------------------------

    /**
     * @dev Error for when a multi call fails.
     * @param index: index of the call.
     */
    error MultiCall__CallFailed(uint256 index);

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
     * @dev Data to make the call.
     * @param target: the target address;
     * @param callData: the calldata to be sent;
     * @param value: value in WEI to be sent with the call;
     * @param requireSuccess: whether or not success is required for the call.
     */
    struct CallWithFailure {
        address target;
        bytes callData;
        uint256 value;
        bool requireSuccess;
    }

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
    /// State variables
    /// -----------------------------------------------------------------------

    address internal constant MULTICALL_ADDRESS =
        0xcA11bde05977b3631167028862bE2a173976CA11;

    /// -----------------------------------------------------------------------
    /// Fallback and receive functions
    /// -----------------------------------------------------------------------

    /**
     * @notice This fallback function points to {Multicall3} contract.
     */
    fallback() external payable {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let success := call(
                gas(),
                MULTICALL_ADDRESS,
                callvalue(),
                0,
                calldatasize(),
                0,
                0
            )
            returndatacopy(0, 0, returndatasize())
            if iszero(success) {
                revert(0, returndatasize())
            }
            return(0, returndatasize())
        }
    }

    /**
     * @notice This contract won't accept any ETH transfer.
     */
    receive() external payable {
        revert MultiCall__SendingValueNotAllowed();
    }

    /// -----------------------------------------------------------------------
    /// External functions
    /// -----------------------------------------------------------------------

    // ----- Calls -----

    /**
     * @notice Aggregates multi calls.
     * @param calls: array of calls to be executed.
     * @return returnDatas array of returned values from each call.
     */
    function aggregateCalls(
        Call[] calldata calls
    ) external payable returns (bytes[] memory returnDatas) {
        returnDatas = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; ) {
            bool success;
            (success, returnDatas[i]) = calls[i].target.call{
                value: calls[i].value
            }(calls[i].callData);

            require(success, MultiCall__CallFailed(i));

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Tries to execute multi calls. If success is require and a call fails,
     * it will revert.
     * @param calls: array of calls to be executed;
     * @param requireSuccess: whether or not success is required.
     * @return results array of {Result} struct with result of each call.
     */
    function tryAggregateCalls(
        Call[] calldata calls,
        bool requireSuccess
    ) external payable returns (Result[] memory results) {
        results = new Result[](calls.length);
        for (uint256 i = 0; i < calls.length; ) {
            (bool success, bytes memory returnData) = calls[i].target.call{
                value: calls[i].value
            }(calls[i].callData);

            if (requireSuccess) {
                require(success, MultiCall__CallFailed(i));
            }

            results[i] = Result({success: success, returnData: returnData});

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Tries to execute multi calls. If success is require for a specific call
     * it fails, it will revert.
     * @param calls: array of calls to be executed.
     * @return results array of {Result} struct with result of each call.
     */
    function tryAggregateCalls(
        CallWithFailure[] calldata calls
    ) external payable returns (Result[] memory results) {
        results = new Result[](calls.length);
        for (uint256 i = 0; i < calls.length; ) {
            (bool success, bytes memory returnData) = calls[i].target.call{
                value: calls[i].value
            }(calls[i].callData);

            if (calls[i].requireSuccess) {
                require(success, MultiCall__CallFailed(i));
            }

            results[i] = Result({success: success, returnData: returnData});

            unchecked {
                ++i;
            }
        }
    }

    // ----- Simulate calls -----

    /**
     * @notice Simulates calls. It always reverts with the simulation results.
     * @param calls: array of calls to be executed.
     */
    function simulateCalls(Call[] calldata calls) external payable {
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
    function aggregateStatic(
        StaticCall[] calldata calls
    ) external view returns (bytes[] memory returnData) {
        returnData = new bytes[](calls.length);
        StaticCall calldata call;
        for (uint256 i = calls.length; i > 0; ) {
            bool success;
            call = calls[i - 1];
            (success, returnData[i - 1]) = call.target.staticcall(
                call.callData
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
    function tryAggregateStatic(
        StaticCall[] calldata calls,
        bool requireSuccess
    ) external view returns (Result[] memory returnData) {
        returnData = new Result[](calls.length);
        StaticCall calldata call;
        for (uint256 i = calls.length; i > 0; ) {
            Result memory result = returnData[i - 1];
            call = calls[i - 1];
            (result.success, result.returnData) = call.target.staticcall(
                call.callData
            );

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
    function tryAggregateStatic(
        StaticCallWithFailure[] calldata calls
    ) external view returns (Result[] memory returnData) {
        returnData = new Result[](calls.length);
        StaticCallWithFailure calldata call;
        for (uint256 i = calls.length; i > 0; ) {
            Result memory result = returnData[i - 1];
            call = calls[i - 1];
            (result.success, result.returnData) = call.target.staticcall(
                call.callData
            );

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
    function getCodeLengths(
        address[] calldata targets
    ) external view returns (uint256[] memory lengths) {
        lengths = new uint256[](targets.length);
        for (uint256 i = targets.length; i > 0; ) {
            lengths[i - 1] = targets[i - 1].code.length;

            unchecked {
                --i;
            }
        }
    }

    /**
     * @notice Gets the balance for each given address.
     * @param targets: array of target addresses.
     * @return balances - uint256[] - array of balances for each target address.
     */
    function getBalances(
        address[] calldata targets
    ) external view returns (uint256[] memory balances) {
        balances = new uint256[](targets.length);
        for (uint256 i = targets.length; i > 0; ) {
            balances[i - 1] = targets[i - 1].balance;

            unchecked {
                --i;
            }
        }
    }
}
