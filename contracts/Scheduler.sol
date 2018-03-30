pragma solidity ^0.4.19;

import "./CloneFactory.sol";
import "./EventEmitter.sol";
import "./IPFS.sol";
import "./ScheduledTransaction.sol";

contract Scheduler is CloneFactory {
    function () public {revert();}

    address public eventEmitter;
    address public feeRecipient;
    address public ipfs;
    address public scheduledTxCore;

    function Scheduler(
        address _eventEmitter,
        address _feeRecipient,
        address _ipfsLib,
        address _scheduledTxCore
    ) public {
        eventEmitter = _eventEmitter;
        feeRecipient = _feeRecipient;
        ipfs = _ipfsLib;
        scheduledTxCore = _scheduledTxCore;
    }

    function schedule(bytes _serializedTransaction) 
        public payable returns (address scheduledTx)
    {
        // bytes2 temporalUnit;
        // address recipient;
        uint256 value;
        uint256 callGas;
        uint256 gasPrice;
        // uint256 executionWindowStart;
        // uint256 executionWindowLength;
        uint256 bounty;
        uint256 fee;

        // uint256 callDataLen;
        // uint256 callDataLoc;
        // No requiredDeposit - Use Day Token now

        assembly {
            // temporalUnit := mload(add(_serializedTransaction, 32))
            // recipient := mload(add(_serializedTransaction, 34))
            value := mload(add(_serializedTransaction, 66))
            callGas := mload(add(_serializedTransaction, 98))
            gasPrice := mload(add(_serializedTransaction, 130))
            // executionWindowStart := mload(add(_serializedTransaction, 162))
            // executionWindowLength := mload(add(_serializedTransaction, 194))
            bounty := mload(add(_serializedTransaction, 226))
            fee := mload(add(_serializedTransaction, 258))
            // CallData = everything after this
            // first 32 bytes of array header
            // callDataLen := mload(add(_serializedTransaction, 322)) // first 32 bytes is length
            // callDataLoc := add(_serializedTransaction, 354) // the location of callData
        }

        // bytes memory callData = toBytes(callDataLoc, callDataLen);

        // EventEmitter(eventEmitter).logParameters(
        //     temporalUnit,
        //     recipient,
        //     value,
        //     callGas,
        //     gasPrice,
        //     executionWindowStart,
        //     executionWindowLength,
        //     bounty,
        //     fee,
        //     callData
        // );

        uint endowment = value + callGas * gasPrice + bounty + fee;
        require(msg.value >= endowment);

        bytes32 ipfsHash = IPFS(ipfs).generateHash(_serializedTransaction);

        scheduledTx = createTransaction();
        require(scheduledTx != 0x0);

        ScheduledTransaction(scheduledTx).init.value(msg.value)(ipfsHash, msg.sender, address(this));

        // Record on the event emitter
        EventEmitter(eventEmitter).logNewTransactionScheduled(scheduledTx, msg.sender, address(this));
    }

    function createTransaction() public returns (address) {
        return createClone(scheduledTxCore);
    }

    function toBytes(uint256 _ptr, uint256 _len) internal view returns (bytes) {
        bytes memory ret = new bytes(_len);
        uint retptr;
        assembly { retptr := add(ret, 32) }

        memcpy(retptr, _ptr, _len);
        return ret;
    }

    function memcpy(uint256 dest, uint src, uint len) private pure {
        // Copy word-length chunks while possible
        for(; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }
 
        // Copy remaining bytes
        uint mask = 256 ** (32 - len) - 1;
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }
}
