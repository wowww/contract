// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;


import "../SpellBase.sol";
import "../Payment/IPayment.sol";
import "../../Station/IStation.sol";
import "../../Registry/IMelterRegistry.sol";
import "../../Registry/IPteRegistry.sol";
import "../../Router/IFundRouter.sol";
/**
    This spell use for relocate receiver
 */

contract RelocateSpell is SpellBase, IPaymentStruct, IStationStruct {

    struct Params {
        address receiver;
        uint daoId;
        uint agendaId;
        bytes32 hashed;
        bytes32 name;
    }

    address immutable private _payment;
    address immutable private _melter;
    IPteRegistry immutable private _pteRegistry;

    event Relocated(bytes32 newName, address newReceiver);

    constructor(
        address governance,
        address station,
        address spellRegistry,
        address pteRegistry,
        address payment,
        address melter
    )
        SpellBase(governance, station, spellRegistry) 
    {
        _pteRegistry = IPteRegistry(pteRegistry);
        _payment = payment;
        _melter = melter;
    }

    /**
     * @dev execute spell
     */
    function cast(Params memory input) external onlyGovernance returns(bool) {
        (bool status, ) = _payment.call(
            abi.encodeWithSelector(
                IPayment.changeReceiver.selector,
                input.daoId,
                input.hashed,
                input.name,
                input.receiver
            )
        );
        if(status) {
            emit Relocated(input.name, input.receiver);
            
            return true;
        }else {
            return false;
        }
    }

    function isValidParams(bytes calldata params, uint daoId) external view virtual override returns(bool) {
        bytes4 paramsSelector = params[0] |
            (bytes4(params[1]) >> 8) |
            (bytes4(params[2]) >> 16) |
            (bytes4(params[3]) >> 24);

        Params memory inputs = abi.decode(params[4:], (Params));
        
        require(paramsSelector == this.cast.selector, "RS2-IV0-540");
        require(_isValidDaoId(inputs.daoId, daoId), "RS2-IV0-510");
        require(inputs.agendaId <= IGovernance(_governance).getCurrentId(inputs.daoId), "RS2-IV0-511");

        bytes32 hashed = IPayment(_payment).getBusinessHash(inputs.daoId, inputs.agendaId);
        require(hashed == inputs.hashed, "RS2-IV0-541");
        require(IPayment(_payment).isValidBusinessInfo(inputs.daoId, inputs.hashed), "RS2-IV0-050");

        if(_pteRegistry.isRegistered(inputs.name)) {
            require(_pteRegistry.getRegisteredPte(inputs.name) == inputs.receiver, "RS2-IV0-520");
        }else {
            require(IMelterRegistry(_melter).isMelter(inputs.receiver), "RS2-IV0-521");
        }

        return true;
    }
}