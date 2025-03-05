// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "permit2/Permit2.sol";
import "./interfaces/IMayanSwift.sol";
import "./interfaces/IMayanSwiftX.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract MayanSwiftX is IMayanSwiftX {
    error WitnessMismatch();
    error OutsideExecutionWindow();
    error OutsideExecutionPrice();

    Permit2 public permit2;
    IPyth public pyth;

    address public immutable MAYAN_ORDER_CONTRACT;

    constructor (address _permit2, address _mayanOrderContract, address _pyth) {
        permit2 = Permit2(_permit2);
        MAYAN_ORDER_CONTRACT = _mayanOrderContract;
        pyth = IPyth(_pyth);
    }

    function execute(
        TransferPayload memory transferPayload,
        OrderPayload memory orderPayload,
        bytes[] memory updateData
    ) public payable {
        if (keccak256(abi.encode(orderPayload)) != transferPayload.witness) {
            revert WitnessMismatch();
        }

        bool shouldProcess;
        if (orderPayload.customOrderType == CustomOrderType.PriceOrder) {
           shouldProcess = handlePriceOrder(orderPayload, updateData);
           if (!shouldProcess) return;
        }
        
        if (orderPayload.customOrderType == CustomOrderType.TimeOrder) {
           shouldProcess = handleTimeOrder(orderPayload);
           if (!shouldProcess) return;
        }

        if (shouldProcess) {
            permit2.permitWitnessTransferFrom(
                transferPayload.permit, 
                transferPayload.transferDetails, 
                transferPayload.owner, 
                transferPayload.witness, 
                transferPayload.witnessTypeString, 
                transferPayload.signature
            );
            
            IERC20(orderPayload.tokenIn).approve(MAYAN_ORDER_CONTRACT, orderPayload.amountIn);
            
            IMayanSwift(MAYAN_ORDER_CONTRACT).createOrderWithToken(
                orderPayload.tokenIn, 
                orderPayload.amountIn, 
                orderPayload.orderParams
            );
        }
    }

    function handlePriceOrder(OrderPayload memory orderPayload, bytes[] memory updateData) public payable returns (bool shouldProcess) {
        uint fee = pyth.getUpdateFee(updateData);
        pyth.updatePriceFeeds{ value: fee }(updateData); 
        PythStructs.Price memory price = pyth.getPriceNoOlderThan(orderPayload.oracleFeedId, 60);

        if (block.timestamp < orderPayload.minExecutionTime || block.timestamp > orderPayload.maxExecutionTime) {
            revert OutsideExecutionWindow();
        }
    
        if (price.price < orderPayload.minExecutionPrice || price.price > orderPayload.maxExecutionPrice) {
            revert OutsideExecutionPrice();
        }

        return true;
    }

    function handleTimeOrder(OrderPayload memory orderPayload) public returns (bool shouldProcess) {
        if (block.timestamp < orderPayload.minExecutionTime || block.timestamp > orderPayload.maxExecutionTime) {
            revert OutsideExecutionWindow();
        }
        return true;
    }

    function handleRecurringOrder(OrderPayload memory orderPayload) {
        
    }
}