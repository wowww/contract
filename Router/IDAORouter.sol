// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../Governance/IGovernance.sol";

/**
 * @title IDAORouter
 * @author Wemade Pte, Ltd
 *
 */

interface IDAORouter is IGovernanceStruct {

    function disposeDT(uint id, address dt, uint toBurn, uint toReward) external;
    function pause(uint id) external;
}

