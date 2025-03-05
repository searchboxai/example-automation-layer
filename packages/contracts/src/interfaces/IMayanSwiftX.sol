// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "permit2/interfaces/ISignatureTransfer.sol";
import "./IMayanSwift.sol";

interface IMayanSwiftX {
    struct TransferPayload {
        ISignatureTransfer.PermitTransferFrom permit;
        ISignatureTransfer.SignatureTransferDetails transferDetails;
        address owner;
        bytes32 witness;
        string witnessTypeString;
        bytes signature;
    }

    struct OrderPayload {
        uint256 amountIn;           
        int64 minExecutionPrice;  
        int64 maxExecutionPrice;  
        uint256 createdAt;          
        uint64 minExecutionTime;   
        uint64 maxExecutionTime;    
        bytes32 oracleFeedId;      
        address tokenIn;            
        bool isRecurring;          
        CustomOrderType customOrderType;
        IMayanSwift.OrderParams orderParams; 
    }
 

    enum CustomOrderType {
        PriceOrder,
        TimeOrder,
        RecurringOrder
    }
}