// SPDX-License-Identifier: MIT
pragma solidity ^0.4.24;

library SafeMath {

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;
        return c;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);
        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

contract owned {
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
    }
}

interface tokenRecipient {
    function receiveApproval(
        address _from,
        uint256 _value,
        address _token,
        bytes _extraData
    ) external;
}

contract tokenBase is owned {
    using SafeMath for uint256;
    string public name;
    string public symbol;
    uint256 public DecPrecision= 10**18;
    uint256 public totalSupply;
    bool public released = true;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );
    event Burn(address indexed from, uint256 value);

    constructor(
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol
    ) public {
        totalSupply = initialSupply * DecPrecision;
        balanceOf[msg.sender] = totalSupply;
        name = tokenName;
        symbol = tokenSymbol;
    }

    function release() public onlyOwner {
        require(owner == msg.sender);
        released = !released;
    }

    modifier onlyReleased() {
        require(released);
        _;
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _value
    ) internal onlyReleased {
        require(_to != address(0));
        require(balanceOf[_from] >= _value);
        require(balanceOf[_to] + _value > balanceOf[_to]);

        uint256 previousBalances = balanceOf[_from].add(balanceOf[_to]);
        balanceOf[_from] = balanceOf[_from].sub(_value);
        balanceOf[_to] = balanceOf[_to].add(_value);
        emit Transfer(_from, _to, _value);
        assert(balanceOf[_from].add(balanceOf[_to]) == previousBalances);
    }

    /**
     * Transfer tokens
     *
     * Send `_value` tokens to `_to` from your account
     *
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transfer(address _to, uint256 _value)
        public
        onlyReleased
        returns (bool success)
    {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    /**
     * Transfer tokens from other address
     *
     * Send `_value` tokens to `_to` in behalf of `_from`
     *
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public onlyReleased returns (bool success) {
        require(_value <= allowance[_from][msg.sender]);
        allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value);
        _transfer(_from, _to, _value);
        return true;
    }

    /**
     * Set allowance for other address
     *
     * Allows `_spender` to spend no more than `_value` tokens in your behalf
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     */
    function approve(address _spender, uint256 _value)
        public
        onlyReleased
        returns (bool success)
    {
        require(_spender != address(0));
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function approveAndCall(
        address _spender,
        uint256 _value,
        bytes _extraData
    ) public onlyReleased returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }

    /**
     * Destroy tokens
     *
     * Remove `_value` tokens from the system irreversibly
     *
     * @param _value the amount of money to burn
     */
    function burn(uint256 _value) public onlyReleased returns (bool success) {
        require(balanceOf[msg.sender] >= _value); // Check if the sender has enough
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(_value); // Subtract from the sender
        totalSupply = totalSupply.sub(_value); // Updates totalSupply
        emit Burn(msg.sender, _value);
        return true;
    }

    /**
     * Destroy tokens from other account
     *
     * Remove `_value` tokens from the system irreversibly on behalf of `_from`.
     *
     * @param _from the address of the sender
     * @param _value the amount of money to burn
     */
    function burnFrom(address _from, uint256 _value)
        public
        onlyReleased
        returns (bool success)
    {
        require(balanceOf[_from] >= _value); // Check if the targeted balance is enough
        require(_value <= allowance[_from][msg.sender]); // Check allowance
        balanceOf[_from] = balanceOf[_from].sub(_value); // Subtract from the targeted balance
        allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value); // Subtract from the sender's allowance
        totalSupply = totalSupply.sub(_value); // Update totalSupply
        emit Burn(_from, _value);
        return true;
    }
}

contract DOTR is owned, tokenBase {
    mapping(address => bool) public frozenAccount;
    event FrozenFunds(address target, bool frozen);

    constructor(
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol
    ) public tokenBase(initialSupply, tokenName, tokenSymbol) {}

    function _transfer(
        address _from,
        address _to,
        uint256 _value
    ) internal onlyReleased {
        require(_to != address(0)); 
        require(balanceOf[_from] >= _value);
        require(balanceOf[_to] + _value >= balanceOf[_to]); 
        require(!frozenAccount[_from]);
        require(!frozenAccount[_to]);

        balanceOf[_from] = balanceOf[_from].sub(_value); // Subtract from the sender
        balanceOf[_to] = balanceOf[_to].add(_value); // Add the same to the recipient
        emit Transfer(_from, _to, _value);
    }

    /// @notice `freeze? Prevent | Allow` `target` from sending & receiving tokens
    /// @param target Address to be frozen
    /// @param freeze either to freeze it or not
    function freezeAccount(address target, bool freeze) public onlyOwner {
        frozenAccount[target] = freeze;
        emit FrozenFunds(target, freeze);
    }
}
