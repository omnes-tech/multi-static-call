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
        bytes memory resultsB;
        if (type_ == CallType.SIMULATION) {
            _simulateCalls(simulationCalls);
        } else if (type_ == CallType.STATIC_CALL) {
            bytes[] memory results = _aggregateStatic(staticCalls);
            resultsB = abi.encode(results);
        } else if (type_ == CallType.TRY_STATIC_CALL) {
            Result[] memory results = _tryAggregateStatic(
                staticCalls,
                requireSuccess
            );
            resultsB = abi.encode(results);
        } else if (type_ == CallType.TRY_STATIC_CALL2) {
            Result[] memory results = _tryAggregateStatic(
                staticCallsWithFailure
            );
            resultsB = abi.encode(results);
        } else if (type_ == CallType.CODE_LENGTH) {
            uint256[] memory lengths = _getCodeLengths(addresses);
            resultsB = abi.encode(lengths);
        } else if (type_ == CallType.BALANCES) {
            uint256[] memory lengths = _getBalances(addresses);
            resultsB = abi.encode(lengths);
        } else if (type_ == CallType.ADDRESSES_DATA) {
            (
                uint256[] memory balances,
                uint256[] memory codeLengths
            ) = _getAddressesData(addresses);
            resultsB = abi.encode(balances, codeLengths);
        } else if (type_ == CallType.CHAIN_DATA) {
            (
                uint256 chainId,
                uint256 blockNumber,
                bytes32 blockHash,
                uint256 basefee,
                address coinbase,
                uint256 timestamp,
                uint256 prevrandao,
                uint256 gaslimit,
                uint256 gasprice
            ) = _getChainData();
            bytes memory part1 = abi.encode(
                chainId,
                blockNumber,
                blockHash,
                basefee,
                coinbase
            );
            bytes memory part2 = abi.encode(
                timestamp,
                prevrandao,
                gaslimit,
                gasprice
            );
            resultsB = abi.encodePacked(part1, part2);
        }

        assembly {
            return(add(resultsB, 0x20), mload(resultsB))
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

    /**
     * @notice Gets the balance for each given address.
     * @param targets: array of target addresses.
     * @return balances - uint256[] - array of balances for each target address.
     */
    function _getBalances(
        address[] memory targets
    ) internal view returns (uint256[] memory balances) {
        balances = new uint256[](targets.length);
        for (uint256 i = targets.length; i > 0; ) {
            balances[i - 1] = targets[i - 1].balance;

            unchecked {
                --i;
            }
        }
    }

    /**
     * @notice Gets data from given addresses.
     * @param targets: array of target addresses.
     * @return balances - uint256[] - array of balances for each target address.
     * @return codeLengths - uint256[] - array of length of codes for each target address.
     */
    function _getAddressesData(
        address[] memory targets
    )
        internal
        view
        returns (uint256[] memory balances, uint256[] memory codeLengths)
    {
        balances = new uint256[](targets.length);
        codeLengths = new uint256[](targets.length);
        for (uint256 i = targets.length; i > 0; ) {
            balances[i - 1] = targets[i - 1].balance;
            codeLengths[i - 1] = targets[i - 1].code.length;

            unchecked {
                --i;
            }
        }
    }

    /**
     * @notice Gets chain data.
     * @return chainId - uint256 - chain id.
     * @return blockNumber - uint256 - block number.
     * @return blockHash - bytes32 - block hash.
     * @return basefee - uint256 - base fee.
     * @return coinbase - address - coinbase.
     * @return timestamp - uint256 - timestamp.
     * @return prevrandao - uint256 - prevrandao.
     * @return gaslimit - uint256 - gas limit.
     * @return gasprice - uint256 - gas price.
     */
    function _getChainData()
        internal
        view
        returns (
            uint256 chainId,
            uint256 blockNumber,
            bytes32 blockHash,
            uint256 basefee,
            address coinbase,
            uint256 timestamp,
            uint256 prevrandao,
            uint256 gaslimit,
            uint256 gasprice
        )
    {
        return (
            block.chainid,
            block.number,
            blockhash(block.number),
            block.basefee,
            block.coinbase,
            block.timestamp,
            block.prevrandao,
            block.gaslimit,
            tx.gasprice
        );
    }
}
