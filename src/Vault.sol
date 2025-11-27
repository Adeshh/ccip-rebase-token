// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    error Vault__RedeemFailed();

    IRebaseToken private immutable i_rebaseToken;

    event Deposited(address indexed user, uint256 amount);
    event Redeemed(address indexed user, uint256 amount);

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    /**
     * @notice Deposit the ETH into the vault.
     * @dev The ETH is deposited into the vault and the rebase token is minted to the user.
     */
    function deposit() external payable {
        uint256 intrestRate = i_rebaseToken.getIntrestRate();
        i_rebaseToken.mint(msg.sender, msg.value, intrestRate);
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @notice Redeem the rebase token from the vault.
     * @param _amount The amount of rebase token to redeem.
     * @dev The rebase token is burned from the user and the ETH is sent to the user.
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        i_rebaseToken.burn(msg.sender, _amount);
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeemed(msg.sender, _amount);
    }

    function getRebaseToken() external view returns (address) {
        return address(i_rebaseToken);
    }
}
