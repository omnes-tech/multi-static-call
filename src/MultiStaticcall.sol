// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

//  ██████╗ ███╗   ███╗███╗   ██╗███████╗███████╗
// ██╔═══██╗████╗ ████║████╗  ██║██╔════╝██╔════╝
// ██║   ██║██╔████╔██║██╔██╗ ██║█████╗  ███████╗
// ██║   ██║██║╚██╔╝██║██║╚██╗██║██╔══╝  ╚════██║
// ╚██████╔╝██║ ╚═╝ ██║██║ ╚████║███████╗███████║
//  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝

/// -----------------------------------------------------------------------
/// Contract
/// -----------------------------------------------------------------------

/**
 * @title Multi-static call.
 * @author Omnes Tech (Eduardo W. da Cunha - @EWCunha && Gustavo W. Deps - @G-Deps && Afonso Dalvi - @Afonsodalvi).
 * @notice Useful for sending multi view calls and consuming only one RPC call.
 */
contract MultiStaticcall {
    /// -----------------------------------------------------------------------
    /// Custom errors
    /// -----------------------------------------------------------------------

    /**
     * @dev Error for when a static call fails.
     * @param index: index of the call.
     */
    error MultiStaticcall__StaticCallFailed(uint256 index);

    /// @dev Error for when WEI is sent to this contract.
    error MultiStaticcall__SendingValueNotAllowed();

    /// -----------------------------------------------------------------------
    /// Custom types
    /// -----------------------------------------------------------------------

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
     * @dev The result of the static call.
     * @param success: whether or not the static call has been successful;
     * @param returnData: the data returned.
     */
    struct Result {
        bool success;
        bytes returnData;
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
     * @notice This fallback function redirect to Multicall3 contract.
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
        revert MultiStaticcall__SendingValueNotAllowed();
    }

    /// -----------------------------------------------------------------------
    /// External function
    /// -----------------------------------------------------------------------

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
            require(success, MultiStaticcall__StaticCallFailed(i - 1));

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
                require(
                    result.success,
                    MultiStaticcall__StaticCallFailed(i - 1)
                );
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
}
