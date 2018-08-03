pragma solidity ^0.4.24;

import "./StandardToken.sol";
import "./RelocationToken.sol";

/**
 * @title The STT Token contract.
 *
 * Credit: Taking ideas from BAT token and NET token
 */
 /*is StandardToken */
contract newToken is StandardToken, RelocationToken {

    // Token metadata
    string public constant name = "StarambaToken";
    string public constant symbol = "STT";
    uint256 public constant decimals = 18;
    string public constant version = "1";

    uint256 public TOKEN_CREATION_CAP = 1000 * (10**6) * 10**decimals; // 1000 million STTs
    uint256 public constant TOKEN_MIN = 1 * 10**decimals;              // 1 STT

    address public STTadmin1;      // First administrator for multi-sig mechanism
    address public STTadmin2;      // Second administrator for multi-sig mechanism
    address public oldContract;
    
    // Contracts current state (transactions still paused during sale or already publicly available)
    bool public transactionsActive;

    // Indicate if the token is in relocation mode
    bool public relocationActive;
    address public newTokenContractAddress;

    // How often was the supply adjusted ? (See STT Whitepaper Version 1.0 from 23. May 2018 )
    uint8 supplyAdjustmentCount = 0;

    // Keep track of holders and icoBuyers
    mapping (address => bool) public isHolder; // track if a user is a known token holder to the smart contract - important for payouts later
    address[] public holders;                  // array of all known holders - important for payouts later

    // Store the hashes of admins' msg.data
    mapping (address => bytes32) private multiSigHashes;

    // Declare vendor keys
    mapping (address => bool) public vendors;

    // Count amount of vendors for easier verification of correct contract deployment
    uint8 public vendorCount;

    // Events used for logging
    event LogDeliverSTT(address indexed _to, uint256 _value);
    //event Log

    modifier onlyVendor() {
        require(vendors[msg.sender] == true);
        _;
    }

    modifier isTransferable() {
        require (transactionsActive == true);
        _;
    }

    modifier onlyOwner() {
        // check if transaction sender is admin.
        require (msg.sender == STTadmin1 || msg.sender == STTadmin2);
        // if yes, store his msg.data. 
        multiSigHashes[msg.sender] = keccak256(msg.data);
        // check if his stored msg.data hash equals to the one of the other admin
        if ((multiSigHashes[STTadmin1]) == (multiSigHashes[STTadmin2])) {
            // if yes, both admins agreed - continue.
            _;

            // Reset hashes after successful execution
            multiSigHashes[STTadmin1] = 0x0;
            multiSigHashes[STTadmin2] = 0x0;
        } else {
            // if not (yet), return.
            return;
        }
    }

    /**
     * @dev Create a new STTToken contract.
     *
     *  _admin1 The first admin account that owns this contract.
     *  _admin2 The second admin account that owns this contract.
     *  _vendors List of exactly 10 addresses that are allowed to deliver tokens.
     */
    constructor(address _admin1, address _admin2, address[] _vendors, address _oldContract)
    public
    {
        // Check if the parameters make sense

        // admin1 and admin2 address must be set and must be different
        require (_admin1 != 0x0);
        require (_admin2 != 0x0);
        require (_admin1 != _admin2);
        require (_oldContract != 0x0);
        oldContract = _oldContract;

        // 10 vendor instances for delivering token purchases
        require (_vendors.length == 10);

        totalSupply = 0;

        // define state
        STTadmin1 = _admin1;
        STTadmin2 = _admin2;

        for (uint8 i = 0; i < _vendors.length; i++){
            vendors[_vendors[i]] = true;
            vendorCount++;
        }
    }

    // Overridden method to check for end of fundraising before allowing transfer of tokens
    function transfer(address _to, uint256 _value)
    public // Only allow token transfer after the fundraising has ended
    isTransferable
    returns (bool success)
    {
        
        bool result = super.transfer(_to, _value);
        if (result) {
            trackHolder(_to); // track the owner for later payouts
        }
        return result;
    }

    // Overridden method to check for end of fundraising before allowing transfer of tokens
    function transferFrom(address _from, address _to, uint256 _value)
    public
    isTransferable // Only allow token transfer after the fundraising has ended
    returns (bool success)
    {
        bool result = super.transferFrom(_from, _to, _value);
        if (result) {
            trackHolder(_to); // track the owner for later payouts
        }
        return result;
    }

    // Allow for easier balance checking
    function getBalanceOf(address _owner)
    public
    view
    returns (uint256 _balance)
    {
        return balances[_owner];
    }
    
    function recieveRelocation(address _creditor, uint _balance) external returns (bool) {
        require (msg.sender == oldContract);
        balances[_creditor] = SafeMath.add(balances[_creditor], _balance);
        return true;
    }
    

    // Perform an atomic swap between two token contracts 
    function relocate()
    external 
    {
        // Check if relocation was activated
        require (relocationActive == true);
        
        // Define new token contract is
        RelocationToken newSTT = RelocationToken(newTokenContractAddress);

        // Burn the old balance
        uint256 balance = balances[msg.sender];
        balances[msg.sender] = 0;

        // Perform the relocation of balances to new contract
        require(newSTT.recieveRelocation(msg.sender, balance));
    }

    // Allows to figure out the amount of known token holders
    function getHolderCount()
    public
    view
    returns (uint256 _holderCount)
    {
        return holders.length;
    }

    // Allows for easier retrieval of holder by array index
    function getHolder(uint256 _index)
    public
    view
    returns (address _holder)
    {
        return holders[_index];
    }

    function trackHolder(address _to)
    private
    returns (bool success)
    {
        // Check if the recipient is a known token holder
        if (isHolder[_to] == false) {
            // if not, add him to the holders array and mark him as a known holder
            holders.push(_to);
            isHolder[_to] = true;
        }
        return true;
    }


    /// @dev delivers STT tokens from Leondra (Leondrino Exchange Germany)
    function deliverTokens(address _buyer, uint256 _amount)
    external
    onlyVendor
    {
        require(_amount >= TOKEN_MIN);

        uint256 checkedSupply = SafeMath.add(totalSupply, _amount);
        require(checkedSupply <= TOKEN_CREATION_CAP);

        // Adjust the balance
        uint256 oldBalance = balances[_buyer];
        balances[_buyer] = SafeMath.add(oldBalance, _amount);
        totalSupply = checkedSupply;

        trackHolder(_buyer);

        // Log the creation of these tokens
        emit LogDeliverSTT(_buyer, _amount);
    }

    /// @dev Creates new STT tokens
    function deliverTokensBatch(address[] _buyer, uint256[] _amount)
    external
    onlyVendor
    {
        require(_buyer.length == _amount.length);

        for (uint8 i=0; i < _buyer.length; i++) {
            require(_amount[i] >= TOKEN_MIN);
            require(_buyer[i] != 0x0);

            uint256 checkedSupply = SafeMath.add(totalSupply, _amount[i]);
            require(checkedSupply <= TOKEN_CREATION_CAP);

            // Adjust the balance
            uint256 oldBalance = balances[_buyer[i]];
            balances[_buyer[i]] = SafeMath.add(oldBalance, _amount[i]);
            totalSupply = checkedSupply;

            trackHolder(_buyer[i]);

            // Log the creation of these tokens
            emit LogDeliverSTT(_buyer[i], _amount[i]);
        }
    }

    function transactionSwitch() 
    external 
    onlyOwner
    {
        transactionsActive = !transactionsActive;
    }

    // For eventual later moving to another token contract
    function relocationSwitch(address _newContract) 
    external 
    onlyOwner
    {   
        require(_newContract != 0x0);
        newTokenContractAddress = _newContract;
        relocationActive = !relocationActive;
    }


    // Adjust the cap according to the white paper terms (See STT Whitepaper Version 1.0 from 23. May 2018 )
    function adjustCap()
    external
    onlyOwner
    {
        require (supplyAdjustmentCount < 4);
        TOKEN_CREATION_CAP = SafeMath.add(TOKEN_CREATION_CAP, 50 * (10**6) * 10**decimals); // 50 million STTs
        supplyAdjustmentCount++;
    }
}