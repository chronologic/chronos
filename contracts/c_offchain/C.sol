pragma solidity ^0.4.24;

contract C_Offchain {
    struct User {
        uint256 deposit;
        mapping (bytes32 => bool) nonces;
    }

    // /x19 /xc1 where /x19 is required and /xc1 for chronos v.1
    bytes4 constant SIG_PREFIX = hex"19c1";

    bytes4 constant CALL_PREFIX = bytes4(keccak256("execute(bytes,bytes)"));

    mapping(address => User) users;

    function deposit()
        public payable returns (bool)
    {
        users[msg.sender].deposit += msg.value;
    }

    function execute(
        address _to,
        uint256 _value,
        bytes _data,
        bytes32 _nonce,
        uint256 _gasPrice,
        uint256 _gasLimit,
        address _gasToken,
        bytes _sigs
    )
        public payable
    {
        uint256 startGas = gasleft();
        require(startGas >= _gasLimit);

        bytes32 sigHash = getHash(_to, _value, _data, _nonce, _gasPrice, _gasLimit, _gasToken);
        
        User storage user = users[recover(sigHash, _sigs, 0)];

        require(user.nonces[_nonce] == false);

        user.nonces[_nonce] = true;
        
        _to.call.gas(_gasLimit).value(_value)(_data);

        uint256 gasUsed = 21000 + (startGas - gasleft());
        uint256 refundAmt = gasUsed * _gasPrice;
        address(msg.sender).transfer(refundAmt);
    }

    // function verifySignature(bytes32 _hash, bytes _sigs)
    //     public view returns (bool)
    // {


    // }

    function recover(bytes32 _hash, bytes _sigs, uint256 _pos)
        public pure returns (address)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = sigSplit(_sigs, _pos);

        return ecrecover(_hash,v,r,s);
    }

    function sigSplit(bytes _sigs, uint256 _pos)
        public pure returns (uint8 v, bytes32 r, bytes32 s)
    {
        uint pos = _pos + 1;

        // The signature is a compact form of 
        //  {bytes32 r}{bytes32 s}{uint8 v}
        // Compact meaning uint8 is not padded to bytes32
        assembly {
            r := mload(add(_sigs, mul(0x20, pos)))
            s := mload(add(_sigs, mul(0x40, pos)))

            v := and(mload(add(_sigs, mul(0x60, pos))), 0xff)
        }

        require(v == 27 || v == 28);
    }

    function getHash(
        address _to,
        uint256 _value,
        bytes _data,
        bytes32 _nonce,
        uint256 _gasPrice,
        uint256 _gasLimit,
        address _gasToken
    )
        public returns (bytes32)
    {
        return keccak256(
            SIG_PREFIX,
            address(this),
            _to,
            _value,
            keccak256(_data),
            _nonce,
            _gasPrice,
            _gasLimit,
            _gasToken,
            CALL_PREFIX,
            0
        );
    }


}