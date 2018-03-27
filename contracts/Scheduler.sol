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
        // address recipient;
        uint256 value;
        uint256 callGas;
        uint256 gasPrice;
        // uint256 executionWindowStart;
        // uint256 executionWindowLength;
        uint256 bounty;
        uint256 fee;
        // No requiredDeposit - Use Day Token now

        assembly {
            // recipient := mload(add(_serializedTransaction, 32))
            value := mload(add(_serializedTransaction, 64))
            callGas := mload(add(_serializedTransaction, 96))
            gasPrice := mload(add(_serializedTransaction, 128))
            // executionWindowStart := mload(add(_serializedTransaction, 160))
            // executionWindowLength := mload(add(_serializedTransaction, 192))
            bounty := mload(add(_serializedTransaction, 224))
            fee := mload(add(_serializedTransaction, 256))
            // CallData = everything after this
        }

        // EventEmitter(eventEmitter).logParameters(
        //     recipient,
        //     value,
        //     callGas,
        //     gasPrice,
        //     executionWindowStart,
        //     executionWindowLength,
        //     bounty,
        //     fee
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
}
