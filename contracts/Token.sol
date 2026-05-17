pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //
  // ------------------------------------------ //

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);

  mapping (address => mapping (address => uint256)) private _allowances;
  address[] private _holders;
  mapping (address => uint256) private _holderIndex;
  mapping (address => uint256) private _dividends;

  function _addHolder(address account) internal {
    if (_holderIndex[account] == 0) {
      _holders.push(account);
      _holderIndex[account] = _holders.length;
    }
  }

  function _removeHolder(address account) internal {
    uint256 idx = _holderIndex[account];
    if (idx == 0) return;
    uint256 lastIdx = _holders.length;
    if (idx != lastIdx) {
      address last = _holders[lastIdx - 1];
      _holders[idx - 1] = last;
      _holderIndex[last] = idx;
    }
    _holders.pop();
    _holderIndex[account] = 0;
  }

  function _transfer(address from, address to, uint256 value) internal {
    require(to != address(0), "Transfer to zero address");
    require(balanceOf[from] >= value, "Insufficient balance");
    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    if (value > 0) {
      _addHolder(to);
      if (balanceOf[from] == 0) _removeHolder(from);
    }
    emit Transfer(from, to, value);
  }

  // IERC20

  function allowance(address owner, address spender) external view override returns (uint256) {
    return _allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    _transfer(msg.sender, to, value);
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    require(spender != address(0), "Approve to zero address");
    _allowances[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    require(_allowances[from][msg.sender] >= value, "Allowance exceeded");
    _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);
    _transfer(from, to, value);
    return true;
  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0, "Must send ETH");
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);
    _addHolder(msg.sender);
    emit Transfer(address(0), msg.sender, msg.value);
  }

  function burn(address payable dest) external override {
    uint256 amount = balanceOf[msg.sender];
    require(amount > 0, "No tokens to burn");
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);
    _removeHolder(msg.sender);
    emit Transfer(msg.sender, address(0), amount);
    dest.transfer(amount);
  }

  // IDividends

  function getNumTokenHolders() external view override returns (uint256) {
    return _holders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    require(index >= 1 && index <= _holders.length, "Index out of bounds");
    return _holders[index - 1];
  }

  function recordDividend() external payable override {
    require(msg.value > 0, "Must send ETH");
    require(totalSupply > 0, "No supply");
    for (uint256 i = 0; i < _holders.length; i++) {
      address holder = _holders[i];
      uint256 share = msg.value.mul(balanceOf[holder]).div(totalSupply);
      _dividends[holder] = _dividends[holder].add(share);
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return _dividends[payee];
  }

  function withdrawDividend(address payable dest) external override {
    uint256 amount = _dividends[msg.sender];
    require(amount > 0, "No dividend");
    _dividends[msg.sender] = 0;
    dest.transfer(amount);
  }
}