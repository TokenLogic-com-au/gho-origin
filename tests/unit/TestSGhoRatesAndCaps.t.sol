// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './TestSGhoBase.t.sol';

contract TestSGhoRatesAndCaps is TestSGhoBase {
  // ========================================
  // ADMINISTRATIVE FUNCTIONS TESTS
  // ========================================
  function test_setTargetRate_event() external {
    vm.startPrank(yManager);
    uint16 newRate = 2000; // 20% APR
    vm.expectEmit(true, true, true, true, address(sgho));
    emit IsGho.TargetRateUpdated(newRate);
    sgho.setTargetRate(newRate);
    vm.stopPrank();
    assertEq(sgho.targetRate(), newRate, 'Target rate should be updated');
  }

  function test_revert_setTargetRate_exceedsMaxRate() external {
    vm.startPrank(yManager);
    uint16 newRate = MAX_SAFE_RATE + 1;
    vm.expectRevert(IsGho.RateMustBeLessThanMaxRate.selector);
    sgho.setTargetRate(newRate);
    vm.stopPrank();
  }

  function test_setTargetRate_atMaxRate() external {
    vm.startPrank(yManager);
    sgho.setTargetRate(MAX_SAFE_RATE);
    vm.stopPrank();
    assertEq(sgho.targetRate(), MAX_SAFE_RATE, 'Target rate should be updated to max rate');
  }

  function test_setSupplyCap_event() external {
    vm.startPrank(yManager);
    uint160 newSupplyCap = 1000 ether;
    vm.expectEmit(true, true, true, true, address(sgho));
    emit IsGho.SupplyCapUpdated(newSupplyCap);
    sgho.setSupplyCap(newSupplyCap);
    vm.stopPrank();
    assertEq(sgho.supplyCap(), newSupplyCap, 'Supply cap should be updated');
  }

  function test_setTargetRate() external {
    uint16 newRate = 2000; // 20% APR

    vm.startPrank(yManager);
    sgho.setTargetRate(newRate);
    vm.stopPrank();

    assertEq(sgho.targetRate(), newRate, 'Target rate not set correctly');
  }

  function test_revert_setTargetRate_notYieldManager() external {
    uint16 newRate = 2000; // 20% APR

    vm.startPrank(user1);
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        user1,
        sgho.YIELD_MANAGER_ROLE()
      )
    );
    sgho.setTargetRate(newRate);
    vm.stopPrank();
  }

  function test_revert_setTargetRate_rateGreaterThanMaxRate() external {
    uint16 newRate = 5001; // 50.01% APR
    vm.startPrank(yManager);
    vm.expectRevert(IsGho.RateMustBeLessThanMaxRate.selector);
    sgho.setTargetRate(newRate);
    vm.stopPrank();
  }

  // ========================================
  // SUPPLY CAP & LIMITS TESTS
  // ========================================

  function test_revert_deposit_exceedsCap() external {
    vm.startPrank(user1);
    uint256 amount = SUPPLY_CAP + 1;
    vm.expectRevert(
      abi.encodeWithSelector(ERC4626.ERC4626ExceededMaxDeposit.selector, user1, amount, SUPPLY_CAP)
    );
    sgho.deposit(amount, user1);
    vm.stopPrank();
  }

  function test_revert_mint_exceedsCap() external {
    vm.startPrank(user1);
    uint256 shares = sgho.convertToShares(SUPPLY_CAP) + 1;
    uint256 maxShares = sgho.maxMint(user1);
    vm.expectRevert(
      abi.encodeWithSelector(ERC4626.ERC4626ExceededMaxMint.selector, user1, shares, maxShares)
    );
    sgho.mint(shares, user1);
    vm.stopPrank();
  }

  function test_deposit_atCap() external {
    vm.startPrank(user1);
    sgho.deposit(SUPPLY_CAP, user1);
    assertEq(sgho.totalAssets(), SUPPLY_CAP, 'Total assets should equal supply cap');
    // The contract balance will be the supply cap plus the 1 GHO donated in setUp
    assertEq(
      gho.balanceOf(address(sgho)),
      SUPPLY_CAP + 1 ether,
      'Contract balance should be supply cap + initial donation'
    );
    vm.stopPrank();
  }

  function test_maxDeposit_atCap() external {
    vm.startPrank(user1);
    sgho.deposit(SUPPLY_CAP, user1);
    vm.stopPrank();

    // Max deposit should be 0 when at cap
    assertEq(sgho.maxDeposit(user2), 0, 'maxDeposit should be 0 when at supply cap');
    assertEq(sgho.maxMint(user2), 0, 'maxMint should be 0 when at supply cap');
  }

  function test_maxDeposit_partialCap() external {
    vm.startPrank(user1);
    uint256 depositAmount = SUPPLY_CAP / 2;
    sgho.deposit(depositAmount, user1);
    vm.stopPrank();

    // Max deposit should be remaining capacity
    assertEq(
      sgho.maxDeposit(user2),
      SUPPLY_CAP - depositAmount,
      'maxDeposit should be remaining capacity'
    );
    uint256 expectedMaxMint = sgho.convertToShares(SUPPLY_CAP - depositAmount);
    assertEq(
      sgho.maxMint(user2),
      expectedMaxMint,
      'maxMint should be remaining capacity in shares'
    );
  }

  // ========================================
  // EVENT TESTS
  // ========================================

  function test_ExchangeRateUpdateEvent_basic() external {
    // Set a target rate to ensure yield accrual
    vm.startPrank(yManager);
    sgho.setTargetRate(1000); // 10% APR
    vm.stopPrank();

    // Initial state
    uint256 initialYieldIndex = sgho.yieldIndex();

    // Skip time to accrue yield
    vm.warp(block.timestamp + 30 days);

    uint256 emulatedYieldIndex = _emulateYieldIndex(initialYieldIndex, 1000, 30 days);

    // Trigger yield update by depositing - should emit event
    vm.startPrank(user1);
    vm.expectEmit(true, true, true, true, address(sgho));
    emit IsGho.ExchangeRateUpdate(block.timestamp, emulatedYieldIndex);
    sgho.deposit(100 ether, user1);
    vm.stopPrank();

    // Verify yield index has increased
    uint256 newYieldIndex = sgho.yieldIndex();
    assertTrue(newYieldIndex > initialYieldIndex, 'Yield index should increase after time passes');
    assertEq(sgho.lastUpdate(), block.timestamp, 'Last update should be current timestamp');
  }
}
