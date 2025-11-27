// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author @Adeshh
 * @notice This token is a cross-chain rebase token that incentivise people to deposit in vault for intrest/rewards.
 *         The Intrest rate is always decreasing. Each user in vault have different intrest rate based on the global intrest rate at the time of deposit.
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__IntrestRateCanOnlyDecrease(uint256 oldIntrestRate, uint256 newIntrestRate);

    uint256 private constant PRICISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private s_intrestRate = (5 * PRICISION_FACTOR) / 1e8; //10^-8 == 1/10^8 line is same as 5e10 per sec but written like this for precision
    mapping(address user => uint256 intrestRate) private s_userIntrestRate;
    mapping(address user => uint256 timestamp) private s_userLastUpdatedTimestamp;

    event IntrestRateSet(uint256 indexed newIntrestRate);

    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    function revokeMintAndBurnRole(address _account) external onlyOwner {
        _revokeRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @notice Set the intrest rate for the token.
     * @param _newIntrestRate The new intrest rate to set.
     * @dev The intrest rate can only decrease.
     */
    function setIntrestRate(uint256 _newIntrestRate) external onlyOwner {
        if (_newIntrestRate > s_intrestRate) {
            revert RebaseToken__IntrestRateCanOnlyDecrease(s_intrestRate, _newIntrestRate);
        }
        s_intrestRate = _newIntrestRate;
        emit IntrestRateSet(_newIntrestRate);
    }

    /**
     * @notice Get the principle balance of the user. This is the number of token that have been minted to user,
     *         not including the intrest that has accumulated since the last time user interacted with the protocol.
     * @param _user The user to get the principle balance of.
     * @return The principle balance of the user.
     */
    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @notice Mint the token to the user when they deposit in vault.
     * @param _to The user to mint the token to.
     * @param _amount The amount of token to mint.
     */
    function mint(address _to, uint256 _amount, uint256 _intrestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedIntrest(_to);
        s_userIntrestRate[_to] = _intrestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice Burn the token from the user.
     * @param _from The user to burn the token from.
     * @param _amount The amount of token to burn.
     * @dev If _amount is type(uint256).max, then the user will burn all their tokens.
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedIntrest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice Get the balance of the user including the intrest that has accumulated since the last update.
     *         (principle balance + intrest rate that has accrued)
     * @param _user The user to get the balance of.
     * @return The balance of the user.
     */
    function balanceOf(address _user) public view override returns (uint256) {
        return super.balanceOf(_user) * _calculateUserAccumulatedIntrestSinceLastUpdate(_user) / PRICISION_FACTOR;
    }

    /**
     * @notice Transfer the token to the recipient.
     * @param _recipient The recipient to transfer the token to.
     * @param _amount The amount of token to transfer.
     * @dev If _amount is type(uint256).max, then the user will transfer all their tokens.
     * @dev If the recipient has no balance, then the intrest rate of the recipient will be set to the intrest rate of the sender.
     */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedIntrest(msg.sender);
        _mintAccruedIntrest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userIntrestRate[_recipient] = s_userIntrestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice Transfer the token from the sender to the recipient.
     * @param _sender The sender to transfer the token from.
     * @param _recipient The recipient to transfer the token to.
     * @param _amount The amount of token to transfer.
     * @dev If _amount is type(uint256).max, then the user will transfer all their tokens.
     * @dev If the recipient has no balance, then the intrest rate of the recipient will be set to the intrest rate of the sender.
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedIntrest(_sender);
        _mintAccruedIntrest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userIntrestRate[_recipient] = s_userIntrestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    /**
     * @notice Mint the intrest that has accumulated since the last interaction with protocol (e.g. burn, mint, transfer) to the user.
     * @param _user The user to mint the intrest for.
     * @notice follows the steps as below:
     * 1. find current balance of the rebase token that have been minted to the user.
     * 2. Calculate their current balance including any intrest -> balanceOf(user)
     * 3. calculate the number of tokens that needs to be minted to the user -> (2) - (1)
     * 4. Call _mint to mint the tokens to the user.
     */
    function _mintAccruedIntrest(address _user) internal {
        uint256 PreviousPrincipleBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIncrease = currentBalance - PreviousPrincipleBalance;
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        _mint(_user, balanceIncrease);
    }

    /**
     * @notice Calculate the intrest that has accumulated since the last update.
     * @param _user The user to calculate the intrest for.
     * @return linearIntrest The intrest that has accumulated since the last update.
     * @notice We need to calculate the intrest that has accumulated since the last update which is a linear growth with time.
     * 1. calculate the time elapsed since the last update.
     * 2. calculate the amount of linear growth.
     * 3. formula: pricipleAmount + (pricipleAmount * intrestRate * timeElapsed)
     *           = pricipleAmount * (1 + intrestRate * timeElapsed)
     */
    function _calculateUserAccumulatedIntrestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearIntrest)
    {
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearIntrest = (PRICISION_FACTOR + (s_userIntrestRate[_user] * timeElapsed));
    }

    /**
     * @notice Get the intrest rate for a user.
     * @param _user The user to get the intrest rate for.
     * @return The intrest rate for the user.
     */
    function getUserIntrestRate(address _user) external view returns (uint256) {
        return s_userIntrestRate[_user];
    }

    /**
     * @notice Get the global intrest rate. Any future depositor will have this intrest rate.
     * @return The global intrest rate.
     */
    function getIntrestRate() external view returns (uint256) {
        return s_intrestRate;
    }
}
