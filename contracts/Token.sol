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

  mapping(address => mapping(address => uint256)) internal allowances;
  address[] internal holders;
  mapping(address => uint256) internal holderIndex; // 1-based, 0 = not in list
  mapping(address => uint256) internal withdrawableDividends;

  function _addHolder(address account) internal {
    if (balanceOf[account] > 0 && holderIndex[account] == 0) {
      holders.push(account);
      holderIndex[account] = holders.length;
    }
  }

  function _removeHolder(address account) internal {
    if (balanceOf[account] == 0 && holderIndex[account] != 0) {
      uint256 idx = holderIndex[account];
      address lastAddr = holders[holders.length - 1];
      holders[idx - 1] = lastAddr;
      holders.pop();
      holderIndex[lastAddr] = idx;
      holderIndex[account] = 0;
    }
  }

  // IERC20

  function allowance(address owner, address spender) external view override returns (uint256) {
    return allowances[owner][spender];
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    allowances[msg.sender][spender] = value;
    return true;
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    require(to != address(0), "invalid to");
    require(balanceOf[msg.sender] >= value, "insufficient balance");
    balanceOf[msg.sender] = balanceOf[msg.sender].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    _removeHolder(msg.sender);
    _addHolder(to);
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    require(to != address(0), "invalid to");
    require(balanceOf[from] >= value, "insufficient balance");
    require(allowances[from][msg.sender] >= value, "insufficient allowance");
    allowances[from][msg.sender] = allowances[from][msg.sender].sub(value);
    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    _removeHolder(from);
    _addHolder(to);
    return true;
  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0, "no eth");
    totalSupply = totalSupply.add(msg.value);
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    _addHolder(msg.sender);
  }

  function burn(address payable dest) external override {
    uint256 amount = balanceOf[msg.sender];
    require(amount > 0, "no tokens");
    totalSupply = totalSupply.sub(amount);
    balanceOf[msg.sender] = 0;
    _removeHolder(msg.sender);
    dest.transfer(amount);
  }

  // IDividends

  function getNumTokenHolders() external view override returns (uint256) {
    return holders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    if (index > 0 && index <= holders.length) {
      return holders[index - 1];
    }
    return address(0);
  }

  function recordDividend() external payable override {
    require(msg.value > 0, "no eth supplied");
    require(totalSupply > 0, "no supply");

    uint256 remaining = msg.value;

    for (uint256 i = 0; i < holders.length; i++) {
      address account = holders[i];
      uint256 balance = balanceOf[account];
      if (balance == 0) {
        continue;
      }
      uint256 share = msg.value.mul(balance).div(totalSupply);
      if (share > 0) {
        withdrawableDividends[account] = withdrawableDividends[account].add(share);
        remaining = remaining.sub(share);
      }
    }

    // any remaining wei due to division rounding stays in the contract
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return withdrawableDividends[payee];
  }

  function withdrawDividend(address payable dest) external override {
    uint256 amount = withdrawableDividends[msg.sender];
    require(amount > 0, "no dividend");
    withdrawableDividends[msg.sender] = 0;
    dest.transfer(amount);
  }
}