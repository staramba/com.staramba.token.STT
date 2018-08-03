pragma solidity ^0.4.24;

contract RelocationToken {
    // function of possible new contract to recieve tokenbalance to relocate - to be protected by msg.sender == StarambaToken
    function recieveRelocation(address _creditor, uint _balance) external returns (bool);
}
