// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "../../../../contracts/openzeppelin-contracts/utils/Context.sol";

/**
 * @dev 
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions that operates per id of DAO of your contract.
 * Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract DAOPausable is Context {

    event PausedAll(address account);
    event UnPausedAll(address account);

    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(uint id, address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(uint id, address account);

    mapping(uint => bool) private _paused;
    bool private _pausedAll;
    /**
     * @dev Modifier to make a function callable only when the DAO is not paused.
     *
     * Requirements:
     *
     * - The DAO must not be paused.
     */
    modifier whenNotPaused(uint id) {
        _requireNotPaused(id);
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the DAO is paused.
     *
     * Requirements:
     *
     * - The DAO must be paused.
     */
    modifier whenPaused(uint id) {
        _requirePaused(id);
        _;
    }

    /**
     * @dev Returns true if the DAO is paused, and false otherwise.
     */
    function paused(uint id) public view virtual returns (bool) {
        return _paused[id];
    }

    /**
     * @dev Returns true if the all function of DAO is paused, and false otherwise.
     */
    function pausedAll() public view virtual returns (bool) {
        return _pausedAll;
    }

    /**
     * @dev Throws if the DAO is paused.
     */
    function _requireNotPaused(uint id) internal view virtual {
        require(!_pausedAll, "DP0-RN0-500");
        require(!paused(id), "DP0-RN0-510");
    }

    /**
     * @dev Throws if the DAO is not paused.
     */
    function _requirePaused(uint id) internal view virtual {
        require(paused(id) || _pausedAll, "DP0-RP0-500");
    }

    function _pauseAll() internal virtual {
        require(!_pausedAll, "DP0-PA0-500");
        _pausedAll = true;
        emit PausedAll(_msgSender());
    }

    function _unpauseAll() internal virtual {
        require(_pausedAll, "DP0-UA0-500");
        _pausedAll = false;
        emit UnPausedAll(_msgSender());
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The DAO must not be paused.
     */
    function _pause(uint id) internal virtual whenNotPaused(id) {
        _paused[id] = true;
        emit Paused(id, _msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The DAO must be paused.
     */
    function _unpause(uint id) internal virtual whenPaused(id) {
        _paused[id] = false;
        emit Unpaused(id, _msgSender());
    }
}
