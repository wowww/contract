// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../../../../contracts/openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GovernanceProxy is ERC1967Proxy {
    
    /**
     * @param _logic Governance contract address
     * @param _data initProxy function
     */
     constructor(
        address _logic,
        bytes memory _data
    ) payable ERC1967Proxy(_logic, _data) {}
}
