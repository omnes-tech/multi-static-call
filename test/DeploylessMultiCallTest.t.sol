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

//  ==========  External imports    ==========

import {Test, console} from "forge-std/Test.sol";

//  ==========  Internal imports    ==========

import {DeploylessMultiCall} from "../src/DeploylessMultiCall.sol";
import {CallType, StaticCall} from "../src/MultiCallCodec.sol";

/// -----------------------------------------------------------------------
/// Test
/// -----------------------------------------------------------------------

/**
 * @title Test file.
 * @author Omnes Tech (Eduardo W. da Cunha - @EWCunha && Gustavo W. Deps - @G-Deps && Afonso Dalvi - @Afonsodalvi).
 */
contract DeploylessMultiCallTest is Test {
    DeploylessMultiCall public multiCall;

    function test_Simulation() public {}

    function test_StaticCall() public {
        address target = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
        bytes memory callData = abi.encodeWithSignature(
            "balanceOf(address)",
            address(0)
        );

        StaticCall[] memory calls = new StaticCall[](1);
        calls[0] = StaticCall({target: target, callData: callData});
        // calls[1] = StaticCall({target: target, callData: callData});

        bytes memory constructorArg = abi.encodePacked(
            CallType.STATIC_CALL,
            abi.encode(calls)
        );

        bytes memory creationCode = abi.encodePacked(
            type(DeploylessMultiCall).creationCode,
            abi.encode(constructorArg)
        );

        // multiCall = new DeploylessMultiCall(constructorArg);

        bytes memory returnData;
        assembly {
            let contractAddress := create(
                0,
                add(creationCode, 0x20),
                mload(creationCode)
            )

            returndatacopy(add(returnData, 0x20), 0x00, returndatasize())
        }

        console.logBytes(returnData);
    }

    function test_ChainData() public {
        bytes memory constructorArg = abi.encodePacked(CallType.CHAIN_DATA);

        bytes memory creationCode = abi.encodePacked(
            type(DeploylessMultiCall).creationCode,
            abi.encode(constructorArg)
        );

        bytes memory returnData;
        assembly {
            let contractAddress := create(
                0,
                add(creationCode, 0x20),
                mload(creationCode)
            )
            returndatacopy(add(returnData, 0x20), 0x00, returndatasize())
        }

        console.logBytes(returnData);
    }
}
