// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMayanSwift {
    event OrderCreated(bytes32 key);
    event OrderFulfilled(bytes32 key, uint64 sequence, uint256 netAmount);
    event OrderUnlocked(bytes32 key);
    event OrderCanceled(bytes32 key, uint64 sequence);
    event OrderRefunded(bytes32 key, uint256 netAmount);

    enum Status {
		CREATED,
		FULFILLED,
		UNLOCKED,
		CANCELED,
		REFUNDED
	}

    struct Order {
		Status status;
		uint64 amountIn;    
		uint16 destChainId;
	}

    struct OrderParams {
        bytes32 trader;
        bytes32 tokenOut;
        uint64 minAmountOut;
        uint64 gasDrop;
        uint64 cancelFee;
        uint64 refundFee;
        uint64 deadline;
        bytes32 destAddr;
        uint16 destChainId;
        bytes32 referrerAddr;
        uint8 referrerBps;
        uint8 auctionMode;
        bytes32 random;
    }

    function createOrderWithEth(OrderParams memory params) external payable returns (bytes32 orderHash);
    function createOrderWithToken(address tokenIn, uint256 amountIn, OrderParams memory params) external returns (bytes32 orderHash);
    function getOrders(bytes32[] memory orderHashes) external view returns (Order[] memory);
}