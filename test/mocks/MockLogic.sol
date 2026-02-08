// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

/// @title MockLogic - Mock logic contract for testing executeAction
contract MockLogic {
    event ActionReceived(bytes data);

    uint256 public lastValue;

    function doSomething(uint256 value) external returns (uint256) {
        lastValue = value;
        emit ActionReceived(msg.data);
        return value * 2;
    }

    function alwaysReverts() external pure {
        revert("MockLogic: intentional revert");
    }

    /// @dev Burns gas to test gas capping
    function burnGas(uint256 iterations) external pure returns (uint256 sum) {
        for (uint256 i = 0; i < iterations; i++) {
            sum += i;
        }
    }

    receive() external payable {}
}

/// @title MockLogicReentrant - Attempts reentrancy on executeAction
contract MockLogicReentrant {
    address public target;
    uint256 public tokenId;

    constructor(address _target, uint256 _tokenId) {
        target = _target;
        tokenId = _tokenId;
    }

    fallback() external payable {
        // Attempt reentrant call to executeAction
        (bool success, bytes memory data) = target.call(
            abi.encodeWithSignature(
                "executeAction(uint256,bytes)",
                tokenId,
                abi.encodeWithSignature("doSomething(uint256)", 999)
            )
        );
        // Propagate the revert so the outer call also fails
        if (!success) {
            assembly { revert(add(data, 32), mload(data)) }
        }
    }
}
