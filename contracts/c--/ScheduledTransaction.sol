pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./ParseLib.sol";

contract ScheduledTransaction {
    using ParseLib for *;
    
    bytes32 public dataHash;

    enum State {
        Null,
        Initialized,
        Success,
        Failed,
        Cancelled
    }

    State public state = State.Null;

    /**
     * MODIFIER
     */

    modifier requireCorrectData(bytes _serializedTransaction) {
        bytes32 _hash = keccak256(_serializedTransaction);
        require(dataHash == _hash);
        _;
    }

    modifier requireInState(State _state) {
        require(state == _state);
        _;
    }

    /**
     * FUNCTION
     */

    function initialize(bytes32 _dataHash)
        requireInState(State.Null)
        public payable
    {
        dataHash = _dataHash;

        state = State.Initialized;
    }

    function execute(bytes _serializedTransaction)
        requireCorrectData(_serializedTransaction)
        requireInState(State.Initialized)
        public returns (bool)
    {
        ParseLib.Transaction memory tx_ = ParseLib.fromData(_serializedTransaction);

        require(gasleft() >= tx_.gas + 180000 - 25000);

        // require(tx_.inExecutionWindow());
        // require(tx_.gasPrice == tx.gasprice);

        bool success = tx_.execute();
        
        if (success) {
            state = State.Success;
        } else { state = State.Failed; }

        tx_.payBounty();

        // Transfer the rest to the owner
        getOwner(_serializedTransaction).transfer(address(this).balance);

        return true;
    }

    function cancel(bytes _serializedTransaction) 
        requireInState(State.Initialized)
        public returns (bool)
    {
        // Check Owner
        require(msg.sender == getOwner(_serializedTransaction));

        state = State.Cancelled;
        getOwner(_serializedTransaction).transfer(address(this).balance);
        return true;
    }

    function proxy(address _to, bytes _data, bytes _serializedTransaction)
        requireInState(State.Success)
        public payable returns (bool)
    {
        require(msg.sender == getOwner(_serializedTransaction));
        return _to.call.value(msg.value)(_data);
    }

    function getOwner(bytes _serializedTransaction)
        requireCorrectData(_serializedTransaction)
        public view returns (address owner)
    {
        assembly {
            owner := mload(add(_serializedTransaction, 0x120))
        }
    }

}