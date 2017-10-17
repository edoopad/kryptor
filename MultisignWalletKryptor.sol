pragma solidity ^0.4.17;

// ----------------------------------------------------------------------------------------------
// Kryptor Token by EdooPAD Inc.
// An ERC20 standard
//
// author: EdooPAD Inc.
// Contact: william@edoopad.com 

contract ERC20Interface {
    // Get the total token supply
    function totalSupply() public constant returns (uint256 _totalSupply);
 
    // Get the account balance of another account with address _owner
    function balanceOf(address _owner) public constant returns (uint256 balance);
 
    // Send _value amount of tokens to address _to
    function transfer(address _to, uint256 _value) public returns (bool success);
  
    // Triggered when tokens are transferred.
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
 
    // Triggered whenever approve(address _spender, uint256 _value) is called.
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}
 
contract Kryptor is ERC20Interface {
    uint public constant decimals = 10;

    string public constant symbol = "Kryptor";
    string public constant name = "Kryptor";

    uint private constant icoSupplyRatio = 30;  // percentage of _icoSupply in _totalSupply. Preset: 30%
    uint private constant bonusRatio = 20;   // sale bonus percentage
    uint private constant bonusBound = 10;  // First 10% of totalSupply get bonus
    uint private constant initialPrice = 5000; // Initially, 5000KR KR = 1 ETH

    bool public _selling = true;
    uint public _totalSupply = 10 ** 19; // total supply is 10^19 unit, equivalent to 10^9 KRC
    uint public _originalBuyPrice = (10 ** 18) / (initialPrice * 10**decimals); // original buy in wei of one unit. Ajustable.

    // Owner of this contract
    address public owner;
 
    // Balances KRC for each account
    mapping(address => uint256) balances;
    
    // _icoSupply is the avalable unit. Initially, it is _totalSupply
    // uint public _icoSupply = _totalSupply - (_totalSupply * bonusBound)/100 * bonusRatio;
    uint public _icoSupply = (_totalSupply * icoSupplyRatio) / 100;
    
    // amount of units with bonus
    uint public bonusRemain = (_totalSupply * bonusBound) / 100;//10% _totalSupply

    /* Functions with this modifier can only be executed by the owner
     */
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert();
        }
        _;
    }

    /* Functions with this modifier can only be executed by users except owners
     */
    modifier onlyNotOwner() {
        if (msg.sender == owner) {
            revert();
        }
        _;
    }

    /* Functions with this modifier check on sale status
     * Only allow sale if _selling is on
     */
    modifier onSale() {
        if (!_selling || (_icoSupply <= 0) ) { 
            revert();
        }
        _;
    }

    /* Functions with this modifier check the validity of original buy price
     */
    modifier validOriginalBuyPrice() {
        if(_originalBuyPrice <= 0) {
            revert();
        }
        _;
    }

    /// @dev Constructor
    function KR() 
        public {
        owner = msg.sender;
        balances[owner] = _totalSupply;
    }
    
    /// @dev Gets totalSupply
    /// @return Total supply
    function totalSupply()
        public 
        constant 
        returns (uint256) {
        return _totalSupply;
    }
 
    /// @dev Gets account's balance
    /// @param _addr Address of the account
    /// @return Account balance
    function balanceOf(address _addr) 
        public
        constant 
        returns (uint256) {
        return balances[_addr];
    }
 
    /// @dev Transfers the balance from Multisig wallet to an account
    /// @param _to Recipient address
    /// @param _amount Transfered amount in unit
    /// @return Transfer status
    function transfer(address _to, uint256 _amount)
        public 
        returns (bool) {
        // if sender's balance has enough unit and amount > 0, 
        //      and the sum is not overflow,
        // then do transfer 
        if ( (balances[msg.sender] >= _amount) &&
             (_amount > 0) && 
             (balances[_to] + _amount > balances[_to]) ) {  

            balances[msg.sender] -= _amount;
            balances[_to] += _amount;
            Transfer(msg.sender, _to, _amount);
            
            return true;

        } else {
            return false;
        }
    }

    /// @dev Enables sale 
    function turnOnSale() onlyOwner 
        public {
        _selling = true;
    }

    /// @dev Disables sale
    function turnOffSale() onlyOwner 
        public {
        _selling = false;
    }

    /// @dev Gets selling status
    function isSellingNow() 
        public 
        constant
        returns (bool) {
        return _selling;
    }

    /// @dev Updates buy price (owner ONLY)
    /// @param newBuyPrice New buy price (in unit)
    function setBuyPrice(uint newBuyPrice) onlyOwner 
        public {
        _originalBuyPrice = newBuyPrice;
    }
    
    /*
     *  Exchange wei for KR.
     *  modifier _icoSupply > 0
     *  if requestedCoin > _icoSupply 
     *      revert
     *  
     *  Buy transaction must follow this policy:
     *      if requestedCoin < bonusRemain
     *          actualCoin = requestedCoin + 20%requestedCoin
     *          bonusRemain -= requestedCoin
     *          _icoSupply -= requestedCoin
     *      else
     *          actualCoin = requestedCoin + 20%bonusRemain
     *          _icoSupply -= requested
     *          bonusRemain = 0
     *
     *   Return: 
     *       amount: actual amount of units sold.
     *
     *   NOTE: msg.value is in wei
     */ 
    /// @dev Buys KR
    /// @return Amount of actual sold units 
    function buy() payable onlyNotOwner validOriginalBuyPrice onSale 
        public
        returns (uint256 amount) {
        // convert buy amount in wei to number of unit want to buy
        uint requestedUnits = msg.value / _originalBuyPrice ;
        
        //check requestedUnits > _icoSupply
        if(requestedUnits > _icoSupply){
            revert();
        }
        
        // amount of KR bought
        uint actualSoldUnits = 0;

        // If bonus is available and requested amount of units is less than bonus amount
        if (requestedUnits < bonusRemain) {
            // calculate actual sold units with bonus to the requested amount of units
            actualSoldUnits = requestedUnits + ((requestedUnits*bonusRatio) / 100); 
            // decrease _icoSupply
            _icoSupply -= requestedUnits;
            
            // decrease available bonus amount
            bonusRemain -= requestedUnits;
        }
        else {
            // calculate actual sold units with bonus - if available - to the requested amount of units
            actualSoldUnits = requestedUnits + (bonusRemain * bonusRatio) / 100;
            
            // otherwise, decrease _icoSupply by the requested amount
            _icoSupply -= requestedUnits;

            // no more bonus
            bonusRemain = 0;
        }

        // prepare transfer data
        balances[owner] -= actualSoldUnits;
        balances[msg.sender] += actualSoldUnits;

        //transfer ETH to owner
        owner.transfer(msg.value);
        
        // submit transfer
        Transfer(owner, msg.sender, requestedUnits);

        return requestedUnits;
    }
    
    ///  Fallback function allows to buy ether.
    function()
        public
        payable
    {
        buy();
    }

    /// @dev Withdraws Ether in contract (Owner only)
    function withdraw() onlyOwner 
        public 
        returns (bool) {
        return owner.send(this.balance);
    }
}


/// @title Multisignature wallet - Allows multiple parties to agree on transactions before execution.

contract MultiSigWallet {

    event Confirmation(address sender, bytes32 transactionId);
    event Revocation(address sender, bytes32 transactionId);
    event Submission(bytes32 transactionId);
    event Execution(bytes32 transactionId);
    event Deposit(address sender, uint value);
    event OwnerAddition(address owner);
    event OwnerRemoval(address owner);
    event RequirementChange(uint required);
    event CoinCreation(address coin);

    mapping (bytes32 => Transaction) public transactions;
    mapping (bytes32 => mapping (address => bool)) public confirmations;
    mapping (address => bool) public isOwner;
    address[] owners;
    bytes32[] transactionList;
    uint public required;

    struct Transaction {
        address destination;
        uint value;
        bytes data;
        uint nonce;
        bool executed;
    }

    modifier onlyWallet() {
        if (msg.sender != address(this))
            revert();
        _;
    }

    modifier ownerDoesNotExist(address owner) {
        if (isOwner[owner])
            revert();
        _;
    }

    modifier ownerExists(address owner) {
        if (!isOwner[owner])
            revert();
        _;
    }

    modifier confirmed(bytes32 transactionId, address owner) {
        if (!confirmations[transactionId][owner])
            revert();
        _;
    }

    modifier notConfirmed(bytes32 transactionId, address owner) {
        if (confirmations[transactionId][owner])
            revert();
        _;
    }

    modifier notExecuted(bytes32 transactionId) {
        if (transactions[transactionId].executed)
            revert();
        _;
    }

    modifier notNull(address destination) {
        if (destination == 0)
            revert();
        _;
    }

    modifier validRequirement(uint _ownerCount, uint _required) {
        if (   _required > _ownerCount
            || _required == 0
            || _ownerCount == 0)
            revert();
        _;
    }

    /// @dev Allows to add a new owner. Transaction has to be sent by wallet.
    /// @param owner Address of new owner.
    function addOwner(address owner)
        external
        onlyWallet
        ownerDoesNotExist(owner)
    {
        isOwner[owner] = true;
        owners.push(owner);
        OwnerAddition(owner);
    }

    /// @dev Allows to remove an owner. Transaction has to be sent by wallet.
    /// @param owner Address of owner.
    function removeOwner(address owner)
        external
        onlyWallet
        ownerExists(owner)
    {
        isOwner[owner] = false;
        for (uint i=0; i<owners.length - 1; i++)
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                break;
            }
        owners.length -= 1;
        if (required > owners.length)
            changeRequirement(owners.length);
        OwnerRemoval(owner);
    }

    /// @dev Update the minimum required owner for transaction validation
    /// @param _required number of owners
    function changeRequirement(uint _required)
        public
        onlyWallet
        validRequirement(owners.length, _required)
    {
        required = _required;
        RequirementChange(_required);
    }

    /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @param nonce 
    /// @return transactionId.
    function addTransaction(address destination, uint value, bytes data, uint nonce)
        private
        notNull(destination)
        returns (bytes32 transactionId)
    {
        // transactionId = sha3(destination, value, data, nonce);
        transactionId = keccak256(destination, value, data, nonce);
        if (transactions[transactionId].destination == 0) {
            transactions[transactionId] = Transaction({
                destination: destination,
                value: value,
                data: data,
                nonce: nonce,
                executed: false
            });
            transactionList.push(transactionId);
            Submission(transactionId);
        }
    }

    /// @dev Allows an owner to submit and confirm a transaction.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @param nonce 
    /// @return transactionId.
    function submitTransaction(address destination, uint value, bytes data, uint nonce)
        external
        ownerExists(msg.sender)
        returns (bytes32 transactionId)
    {
        transactionId = addTransaction(destination, value, data, nonce);
        confirmTransaction(transactionId);
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param transactionId transaction Id.
    function confirmTransaction(bytes32 transactionId)
        public
        ownerExists(msg.sender)
        notConfirmed(transactionId, msg.sender)
    {
        confirmations[transactionId][msg.sender] = true;
        Confirmation(msg.sender, transactionId);
        executeTransaction(transactionId);
    }

    
    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param transactionId transaction Id.
    function executeTransaction(bytes32 transactionId)
        public
        notExecuted(transactionId)
    {
        if (isConfirmed(transactionId)) {
            Transaction storage txn = transactions[transactionId]; 
            txn.executed = true;
            if (!txn.destination.call.value(txn.value)(txn.data))
                revert();
                // What happen with txn.executed when revert() is executed?
            Execution(transactionId);
        }
    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param transactionId transaction Id.
    function revokeConfirmation(bytes32 transactionId)
        external
        ownerExists(msg.sender)
        confirmed(transactionId, msg.sender)
        notExecuted(transactionId)
    {
        confirmations[transactionId][msg.sender] = false;
        Revocation(msg.sender, transactionId);
    }

    /// @dev Contract constructor sets initial owners and required number of confirmations.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    function MultiSigWallet(address[] _owners, uint _required)
        validRequirement(_owners.length, _required)
        public 
    {
        for (uint i=0; i<_owners.length; i++) {
            // WHY Not included in this code?
            // if (isOwner[_owners[i]] || _owners[i] == 0)
            //     throw;
            isOwner[_owners[i]] = true;
        }
        owners = _owners;
        required = _required;
    }

    ///  Fallback function allows to deposit ether.
    function()
        public
        payable
    {
        if (msg.value > 0)
            Deposit(msg.sender, msg.value);
    }

    /// @dev Returns the confirmation status of a transaction.
    /// @param transactionId transaction Id.
    /// @return Confirmation status.
    function isConfirmed(bytes32 transactionId)
        public
        constant
        returns (bool)
    {
        uint count = 0;
        for (uint i=0; i<owners.length; i++)
            if (confirmations[transactionId][owners[i]])
                count += 1;
            if (count == required)
                return true;
    }

    /*
     * Web3 call functions
     */
    /// @dev Returns number of confirmations of a transaction.
    /// @param transactionId transaction Id.
    /// @return Number of confirmations.
    function confirmationCount(bytes32 transactionId)
        external
        constant
        returns (uint count)
    {
        for (uint i=0; i<owners.length; i++)
            if (confirmations[transactionId][owners[i]])
                count += 1;
    }

    ///  @dev Return list of transactions after filters are applied
    ///  @param isPending pending status
    ///  @return List of transactions
    function filterTransactions(bool isPending)
        private
        constant
        returns (bytes32[] _transactionList)
    {
        bytes32[] memory _transactionListTemp = new bytes32[](transactionList.length);
        uint count = 0;
        for (uint i=0; i<transactionList.length; i++)
            if (   isPending && !transactions[transactionList[i]].executed
                || !isPending && transactions[transactionList[i]].executed)
            {
                _transactionListTemp[count] = transactionList[i];
                count += 1;
            }
        _transactionList = new bytes32[](count);
        for (i=0; i<count; i++)
            if (_transactionListTemp[i] > 0)
                _transactionList[i] = _transactionListTemp[i];
    }

    /// @dev Returns list of pending transactions
    function getPendingTransactions()
        external
        constant
        returns (bytes32[])
    {
        return filterTransactions(true);
    }

    /// @dev Returns list of executed transactions
    function getExecutedTransactions()
        external
        constant
        returns (bytes32[])
    {
        return filterTransactions(false);
    }
    

    /// @dev Create new coin.
    function createCoin()
        external
        onlyWallet
    {
        CoinCreation(new Kryptor());
    }
}