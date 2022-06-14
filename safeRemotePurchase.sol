// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;
contract Purchase {
    uint public value;
    address payable public seller;
    address payable public buyer;
    uint public confirmPurchaseTime; // added for onlyBuyerOrAfter5Min

    enum State { Created, Locked, Inactive } // removed Release
    // The state variable has a default value of the first member, `State.created`
    State public state;

    modifier condition(bool condition_) {
        require(condition_);
        _;
    }

    /// Only the buyer can call this function.
    error OnlyBuyer();
    /// Only the seller can call this function.
    error OnlySeller();
    /// The function cannot be called at the current state.
    error InvalidState();
    /// The provided value has to be even.
    error ValueNotEven();
    /// Only the buyer or seller 5 min after confirmPurchase can call this function.
    error onlyBuyerOrTimePassed();

    modifier onlyBuyer() {
        if (msg.sender != buyer)
            revert OnlyBuyer();
        _;
    }

    modifier onlySeller() {
        if (msg.sender != seller)
            revert OnlySeller();
        _;
    }

    modifier inState(State state_) {
        if (state != state_)
            revert InvalidState();
        _;
    }

    modifier onlyBuyerOrAfter5Min() {
        // block.timestamp - confirmPurchaseTime is always positive since this
        // modifier runs after setting Locked state, which is set in confirmPurchase
        // which also sets confirmPurchaseTime
        if (!(msg.sender == buyer || 5*60 <= block.timestamp - confirmPurchaseTime))
            revert onlyBuyerOrTimePassed();
        _;
    }

    event Aborted();
    event PurchaseConfirmed();
    // event ItemReceived();
    // event SellerRefunded();
    event PurchaseCompleted(); // new event which is not the same as ItemReceived && SellerRefunded

    // Ensure that `msg.value` is an even number.
    // Division will truncate if it is an odd number.
    // Check via multiplication that it wasn't an odd number.
    constructor() payable {
        seller = payable(msg.sender);
        value = msg.value / 2;
        if ((2 * value) != msg.value)
            revert ValueNotEven();
    }

    /// Abort the purchase and reclaim the ether.
    /// Can only be called by the seller before
    /// the contract is locked.
    function abort()
        external
        onlySeller
        inState(State.Created)
    {
        emit Aborted();
        state = State.Inactive;
        // We use transfer here directly. It is
        // reentrancy-safe, because it is the
        // last call in this function and we
        // already changed the state.
        seller.transfer(address(this).balance);
    }

    /// Confirm the purchase as buyer.
    /// Transaction has to include `2 * value` ether.
    /// The ether will be locked until confirmReceived
    /// is called.
    function confirmPurchase()
        external
        inState(State.Created)
        condition(msg.value == (2 * value))
        payable
    {
        emit PurchaseConfirmed();
        buyer = payable(msg.sender);
        confirmPurchaseTime = block.timestamp;
        state = State.Locked;
    }

    // /// Confirm that you (the buyer) received the item.
    // /// This will release the locked ether.
    // function confirmReceived()
    //     external
    //     onlyBuyer
    //     inState(State.Locked)
    // {
    //     emit ItemReceived();
    //     // It is important to change the state first because
    //     // otherwise, the contracts called using `send` below
    //     // can call in again here.
    //     state = State.Release;

    //     buyer.transfer(value);
    // }

    // /// This function refunds the seller, i.e.
    // /// pays back the locked funds of the seller.
    // function refundSeller()
    //     external
    //     onlySeller
    //     inState(State.Release)
    // {
    //     emit SellerRefunded();
    //     // It is important to change the state first because
    //     // otherwise, the contracts called using `send` below
    //     // can call in again here.
    //     state = State.Inactive;

    //     seller.transfer(3 * value);
    // }

    /// Sends coins to buyer and seller resp.
    /// Can be called by buyer or 5 min after confirmPurchase
    function completePurchase()
        external
        onlyBuyerOrAfter5Min
        inState(State.Locked)
    {
        emit PurchaseCompleted();
        // It is important to change the state first because
        // otherwise, the contracts called using `send` below
        // can call in again here.
        state = State.Inactive;

        buyer.transfer(value);
        seller.transfer(3 * value);
    }
}