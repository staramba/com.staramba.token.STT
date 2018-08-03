pragma solidity ^0.4.24;

import "./StandardToken.sol";
import "./RelocationToken.sol";

contract TestRelocationToken is StandardToken, RelocationToken {
    
    function recieveRelocation(address _creditor, uint _balance) 
    external
    returns (bool) {
        uint256 oldBalance = balances[_creditor];
        balances[_creditor] = SafeMath.add(oldBalance, _balance);
        return true;
    }
}
