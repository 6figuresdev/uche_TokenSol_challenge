cat > contracts/Token.sol << 'EOF'
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

    mapping(address => mapping(address => uint256)) private _allowances;

    address[] private _holders;
    mapping(address => uint256) private _holderIndex;
    mapping(address => uint256) private _dividends;

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function transfer(address to, uint256 value) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external override returns (bool) {
        _allowances[msg.sender][spender] = value;
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        uint256 current = _allowances[from][msg.sender];
        require(current >= value, "Token: transfer exceeds allowance");
        _allowances[from][msg.sender] = current.sub(value);
        _transfer(from, to, value);
        return true;
    }

    function mint() external payable override {
        require(msg.value > 0, "Token: no ETH supplied");
        balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
        totalSupply = totalSupply.add(msg.value);
        _addHolder(msg.sender);
    }

    function burn(address payable dest) external override {
        uint256 amount = balanceOf[msg.sender];
        require(amount > 0, "Token: no tokens to burn");
        balanceOf[msg.sender] = 0;
        totalSupply = totalSupply.sub(amount);
        _removeHolder(msg.sender);
        (bool ok, ) = dest.call{value: amount}("");
        require(ok, "Token: ETH transfer failed");
    }

    function getNumTokenHolders() external view override returns (uint256) {
        return _holders.length;
    }

    function getTokenHolder(uint256 index) external view override returns (address) {
        if (index == 0 || index > _holders.length) return address(0);
        return _holders[index - 1];
    }

    function recordDividend() external payable override {
        require(msg.value > 0, "Token: no ETH supplied");
        uint256 supply = totalSupply;
        uint256 len = _holders.length;
        for (uint256 i = 0; i < len; i++) {
            address holder = _holders[i];
            uint256 bal = balanceOf[holder];
            if (bal > 0) {
                _dividends[holder] = _dividends[holder].add(msg.value.mul(bal).div(supply));
            }
        }
    }

    function getWithdrawableDividend(address payee) external view override returns (uint256) {
        return _dividends[payee];
    }

    function withdrawDividend(address payable dest) external override {
        uint256 amount = _dividends[msg.sender];
        require(amount > 0, "Token: no dividend to withdraw");
        _dividends[msg.sender] = 0;
        (bool ok, ) = dest.call{value: amount}("");
        require(ok, "Token: ETH transfer failed");
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(balanceOf[from] >= value, "Token: insufficient balance");
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        if (value > 0) {
            if (balanceOf[from] == 0) _removeHolder(from);
            _addHolder(to);
        }
    }

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
        address last = _holders[lastIdx - 1];
        if (idx != lastIdx) {
            _holders[idx - 1] = last;
            _holderIndex[last] = idx;
        }
        _holders.pop();
        _holderIndex[account] = 0;
    }
}
EOF
