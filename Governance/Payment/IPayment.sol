// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IPaymentStruct {
    
    struct Recipient {
        address account;        // recipient address
        bytes32 name;           // recipient name
        uint ratio;             // recipient ratio
    }

    struct PInfo {
        address fundAddr;    // token address, if 0 = wemix coin
        address receiver;    // receiver address
        bytes32 name;        // receiver name
        bytes32 hashed;      // hash for verify
        bytes32 desc;        // desc
        uint daoId;          // dao id
        uint agendaId;       // agenda id
        uint amount;         // amount to be used
        uint revenueRatio;   // ratio of to treasury when the business revenue was deposited
        uint burnRatio;      // ratio of to burn
        uint performRatio;   // ratio of to pte when the business start
        uint incomeRatio;    // ratio of to pte when the business revenue was deposited
        
        Recipient[] creators;   // information of creators
    }
}
interface IPayment is IPaymentStruct {
    function setInfo(bytes memory, uint, uint) external;
    function changeRevenueDistribution(uint, bytes32, uint, uint, uint) external;
    function changeDTDistribution(uint, bytes32, uint) external;
    function changeReceiver(uint, bytes32, bytes32, address) external;
    
    function getBusinessInfo(uint, bytes32) external view returns (PInfo memory);
    function getPerformFee(uint, bytes32, uint) external view returns (uint);
    function getIncomeFee(uint, bytes32, uint) external view returns (uint);
    function getRevenueDistributionInfo(uint, bytes32, uint) external view returns (address[] memory, uint[] memory);
    function getPurchasedDTDisposeInfo(uint, bytes32, uint) external view returns (uint, uint);
    function getBusinessHash(uint, uint) external view returns (bytes32);
    function isValidReceiver(uint, bytes32, address) external view returns (bool);
    function isValidBusinessInfo(uint, bytes32) external view returns (bool);
}