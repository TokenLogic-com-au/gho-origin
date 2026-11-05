// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../TestGhoBase.t.sol';
import {IPermissionedGsm} from 'src/contracts/facilitators/gsm/interfaces/IPermissionedGsm.sol';

/**
 * @dev Covers the swap gating added by `PermissionedGsm`/`PermissionedGsm4626`, which the
 * inherited GSM suites do not exercise since they grant the `BUY_ASSET_ROLE` and `SELL_ASSET_ROLE`
 * to every originator. Run against both versions through the concrete suites below.
 */
abstract contract TestPermissionedGsmAccessBase is TestGhoBase {
  Gsm internal GSM;
  IERC20 internal UNDERLYING;
  address internal unauthorizedAddr;
  address internal gsmSignerAddr;
  uint256 internal gsmSignerKey;

  function setUp() public {
    GSM = _gsm();
    UNDERLYING = _underlying();
    unauthorizedAddr = makeAddr('unauthorized');
    (gsmSignerAddr, gsmSignerKey) = makeAddrAndKey('gsmSigner');

    ghoFaucet(unauthorizedAddr, DEFAULT_GSM_GHO_AMOUNT * 2);
    _mintUnderlying(unauthorizedAddr, DEFAULT_GSM_USDX_AMOUNT);
    vm.startPrank(unauthorizedAddr);
    GHO_TOKEN.approve(address(GSM), type(uint256).max);
    UNDERLYING.approve(address(GSM), type(uint256).max);
    vm.stopPrank();

    _mintUnderlying(ALICE, DEFAULT_GSM_USDX_AMOUNT);
    vm.startPrank(ALICE);
    UNDERLYING.approve(address(GSM), DEFAULT_GSM_USDX_AMOUNT);
    GSM.sellAsset(DEFAULT_GSM_USDX_AMOUNT, ALICE);
    vm.stopPrank();
  }

  function _isPermissionedGsm() internal pure override returns (bool) {
    return true;
  }

  function _gsm() internal view virtual returns (Gsm);

  function _underlying() internal view virtual returns (IERC20);

  function _mintUnderlying(address to, uint256 amount) internal virtual;

  function _insufficientBalanceError(
    address account,
    uint256 needed
  ) internal pure virtual returns (bytes memory);

  function testRoleIdentifiers() public view {
    assertEq(
      IPermissionedGsm(address(GSM)).BUY_ASSET_ROLE(),
      GSM_BUY_ASSET_ROLE,
      'Unexpected BUY_ASSET_ROLE identifier'
    );
    assertEq(
      IPermissionedGsm(address(GSM)).SELL_ASSET_ROLE(),
      GSM_SELL_ASSET_ROLE,
      'Unexpected SELL_ASSET_ROLE identifier'
    );
  }

  function testRevertBuyAssetUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        unauthorizedAddr,
        GSM_BUY_ASSET_ROLE
      )
    );
    vm.prank(unauthorizedAddr);
    GSM.buyAsset(DEFAULT_GSM_USDX_AMOUNT, unauthorizedAddr);
  }

  function testRevertSellAssetUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        unauthorizedAddr,
        GSM_SELL_ASSET_ROLE
      )
    );
    vm.prank(unauthorizedAddr);
    GSM.sellAsset(DEFAULT_GSM_USDX_AMOUNT, unauthorizedAddr);
  }

  function testRevertBuyAssetWithOnlySellRole() public {
    GSM.grantRole(GSM_SELL_ASSET_ROLE, unauthorizedAddr);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        unauthorizedAddr,
        GSM_BUY_ASSET_ROLE
      )
    );
    vm.prank(unauthorizedAddr);
    GSM.buyAsset(DEFAULT_GSM_USDX_AMOUNT, unauthorizedAddr);
  }

  function testRevertSellAssetWithOnlyBuyRole() public {
    GSM.grantRole(GSM_BUY_ASSET_ROLE, unauthorizedAddr);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        unauthorizedAddr,
        GSM_SELL_ASSET_ROLE
      )
    );
    vm.prank(unauthorizedAddr);
    GSM.sellAsset(DEFAULT_GSM_USDX_AMOUNT, unauthorizedAddr);
  }

  function testRevertBuyAssetWithSigUnauthorizedSigner() public {
    uint256 deadline = block.timestamp + 1 hours;
    (address signer, uint256 signerKey) = makeAddrAndKey('unauthorizedSigner');
    ghoFaucet(signer, DEFAULT_GSM_GHO_AMOUNT * 2);
    vm.prank(signer);
    GHO_TOKEN.approve(address(GSM), type(uint256).max);

    bytes32 digest = _getBuyAssetTypedDataHash(
      address(GSM),
      EIP712Types.BuyAssetWithSig({
        originator: signer,
        minAmount: DEFAULT_GSM_USDX_AMOUNT,
        receiver: signer,
        nonce: GSM.nonces(signer),
        deadline: deadline
      })
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        signer,
        GSM_BUY_ASSET_ROLE
      )
    );
    vm.prank(ALICE);
    GSM.buyAssetWithSig(
      signer,
      DEFAULT_GSM_USDX_AMOUNT,
      signer,
      deadline,
      abi.encodePacked(r, s, v)
    );
  }

  function testRevertSellAssetWithSigUnauthorizedSigner() public {
    uint256 deadline = block.timestamp + 1 hours;
    (address signer, uint256 signerKey) = makeAddrAndKey('unauthorizedSigner');
    _mintUnderlying(signer, DEFAULT_GSM_USDX_AMOUNT);
    vm.prank(signer);
    UNDERLYING.approve(address(GSM), type(uint256).max);

    bytes32 digest = _getSellAssetTypedDataHash(
      address(GSM),
      EIP712Types.SellAssetWithSig({
        originator: signer,
        maxAmount: DEFAULT_GSM_USDX_AMOUNT,
        receiver: signer,
        nonce: GSM.nonces(signer),
        deadline: deadline
      })
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        signer,
        GSM_SELL_ASSET_ROLE
      )
    );
    vm.prank(ALICE);
    GSM.sellAssetWithSig(
      signer,
      DEFAULT_GSM_USDX_AMOUNT,
      signer,
      deadline,
      abi.encodePacked(r, s, v)
    );
  }

  function testSellAssetWithSigAuthorizedSignerUnauthorizedRelayer() public {
    uint256 deadline = block.timestamp + 1 hours;
    _mintUnderlying(gsmSignerAddr, DEFAULT_GSM_USDX_AMOUNT);
    vm.prank(gsmSignerAddr);
    UNDERLYING.approve(address(GSM), type(uint256).max);

    bytes memory signature;
    {
      bytes32 digest = _getSellAssetTypedDataHash(
        address(GSM),
        EIP712Types.SellAssetWithSig({
          originator: gsmSignerAddr,
          maxAmount: DEFAULT_GSM_USDX_AMOUNT,
          receiver: gsmSignerAddr,
          nonce: GSM.nonces(gsmSignerAddr),
          deadline: deadline
        })
      );
      (uint8 v, bytes32 r, bytes32 s) = vm.sign(gsmSignerKey, digest);
      signature = abi.encodePacked(r, s, v);
    }

    assertTrue(
      GSM.hasRole(GSM_SELL_ASSET_ROLE, gsmSignerAddr),
      'Signer does not hold the SELL_ASSET_ROLE'
    );
    assertFalse(
      GSM.hasRole(GSM_SELL_ASSET_ROLE, unauthorizedAddr),
      'Relayer unexpectedly holds the SELL_ASSET_ROLE'
    );

    uint256 signerGhoBefore = GHO_TOKEN.balanceOf(gsmSignerAddr);
    uint256 signerUnderlyingBefore = UNDERLYING.balanceOf(gsmSignerAddr);
    uint256 relayerGhoBefore = GHO_TOKEN.balanceOf(unauthorizedAddr);
    uint256 relayerUnderlyingBefore = UNDERLYING.balanceOf(unauthorizedAddr);

    vm.prank(unauthorizedAddr);
    (uint256 assetAmount, uint256 ghoBought) = GSM.sellAssetWithSig(
      gsmSignerAddr,
      DEFAULT_GSM_USDX_AMOUNT,
      gsmSignerAddr,
      deadline,
      signature
    );
    assertEq(assetAmount, DEFAULT_GSM_USDX_AMOUNT, 'Unexpected sold asset amount');
    assertEq(
      GHO_TOKEN.balanceOf(gsmSignerAddr),
      signerGhoBefore + ghoBought,
      'Unexpected signer GHO balance'
    );
    assertEq(
      UNDERLYING.balanceOf(gsmSignerAddr),
      signerUnderlyingBefore - assetAmount,
      'Unexpected signer underlying balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(unauthorizedAddr),
      relayerGhoBefore,
      'Unexpected relayer GHO balance'
    );
    assertEq(
      UNDERLYING.balanceOf(unauthorizedAddr),
      relayerUnderlyingBefore,
      'Unexpected relayer underlying balance'
    );
  }

  function testBuyAssetWithSigAuthorizedSignerUnauthorizedRelayer() public {
    uint256 deadline = block.timestamp + 1 hours;
    ghoFaucet(gsmSignerAddr, DEFAULT_GSM_GHO_AMOUNT * 2);
    vm.prank(gsmSignerAddr);
    GHO_TOKEN.approve(address(GSM), type(uint256).max);

    bytes memory signature;
    {
      bytes32 digest = _getBuyAssetTypedDataHash(
        address(GSM),
        EIP712Types.BuyAssetWithSig({
          originator: gsmSignerAddr,
          minAmount: DEFAULT_GSM_USDX_AMOUNT,
          receiver: gsmSignerAddr,
          nonce: GSM.nonces(gsmSignerAddr),
          deadline: deadline
        })
      );
      (uint8 v, bytes32 r, bytes32 s) = vm.sign(gsmSignerKey, digest);
      signature = abi.encodePacked(r, s, v);
    }

    assertTrue(
      GSM.hasRole(GSM_BUY_ASSET_ROLE, gsmSignerAddr),
      'Signer does not hold the BUY_ASSET_ROLE'
    );
    assertFalse(
      GSM.hasRole(GSM_BUY_ASSET_ROLE, unauthorizedAddr),
      'Relayer unexpectedly holds the BUY_ASSET_ROLE'
    );

    uint256 signerGhoBefore = GHO_TOKEN.balanceOf(gsmSignerAddr);
    uint256 signerUnderlyingBefore = UNDERLYING.balanceOf(gsmSignerAddr);
    uint256 relayerGhoBefore = GHO_TOKEN.balanceOf(unauthorizedAddr);
    uint256 relayerUnderlyingBefore = UNDERLYING.balanceOf(unauthorizedAddr);

    vm.prank(unauthorizedAddr);
    (uint256 assetAmount, uint256 ghoSold) = GSM.buyAssetWithSig(
      gsmSignerAddr,
      DEFAULT_GSM_USDX_AMOUNT,
      gsmSignerAddr,
      deadline,
      signature
    );
    assertEq(assetAmount, DEFAULT_GSM_USDX_AMOUNT, 'Unexpected bought asset amount');
    assertEq(
      GHO_TOKEN.balanceOf(gsmSignerAddr),
      signerGhoBefore - ghoSold,
      'Unexpected signer GHO balance'
    );
    assertEq(
      UNDERLYING.balanceOf(gsmSignerAddr),
      signerUnderlyingBefore + assetAmount,
      'Unexpected signer underlying balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(unauthorizedAddr),
      relayerGhoBefore,
      'Unexpected relayer GHO balance'
    );
    assertEq(
      UNDERLYING.balanceOf(unauthorizedAddr),
      relayerUnderlyingBefore,
      'Unexpected relayer underlying balance'
    );
  }

  function testBuyAssetAfterBuyRoleGranted() public {
    GSM.grantRole(GSM_BUY_ASSET_ROLE, unauthorizedAddr);

    vm.prank(unauthorizedAddr);
    (uint256 assetAmount, ) = GSM.buyAsset(DEFAULT_GSM_USDX_AMOUNT, unauthorizedAddr);
    assertEq(assetAmount, DEFAULT_GSM_USDX_AMOUNT, 'Unexpected bought asset amount');
  }

  function testSellAssetAfterSellRoleGranted() public {
    GSM.grantRole(GSM_SELL_ASSET_ROLE, unauthorizedAddr);

    vm.prank(unauthorizedAddr);
    (uint256 assetAmount, ) = GSM.sellAsset(DEFAULT_GSM_USDX_AMOUNT, unauthorizedAddr);
    assertEq(assetAmount, DEFAULT_GSM_USDX_AMOUNT, 'Unexpected sold asset amount');
  }

  function testRevertBuyAssetAfterBuyRoleRevoked() public {
    assertTrue(GSM.hasRole(GSM_BUY_ASSET_ROLE, ALICE), 'Alice does not hold the BUY_ASSET_ROLE');
    GSM.revokeRole(GSM_BUY_ASSET_ROLE, ALICE);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        ALICE,
        GSM_BUY_ASSET_ROLE
      )
    );
    vm.prank(ALICE);
    GSM.buyAsset(DEFAULT_GSM_USDX_AMOUNT, ALICE);
  }

  function testSellAssetAfterBuyRoleRevoked() public {
    GSM.revokeRole(GSM_BUY_ASSET_ROLE, ALICE);
    _mintUnderlying(ALICE, DEFAULT_GSM_USDX_AMOUNT);

    vm.startPrank(ALICE);
    UNDERLYING.approve(address(GSM), DEFAULT_GSM_USDX_AMOUNT);
    (uint256 assetAmount, ) = GSM.sellAsset(DEFAULT_GSM_USDX_AMOUNT, ALICE);
    vm.stopPrank();
    assertEq(assetAmount, DEFAULT_GSM_USDX_AMOUNT, 'Unexpected sold asset amount');
  }

  function testRevertFrozenBeforeRoleCheck() public {
    vm.prank(address(GHO_GSM_SWAP_FREEZER));
    GSM.setSwapFreeze(true);

    vm.expectRevert('GSM_FROZEN');
    vm.prank(unauthorizedAddr);
    GSM.buyAsset(DEFAULT_GSM_USDX_AMOUNT, unauthorizedAddr);
  }

  function testRevertSeizedBeforeRoleCheck() public {
    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GSM.seize();

    vm.expectRevert('GSM_SEIZED');
    vm.prank(unauthorizedAddr);
    GSM.buyAsset(DEFAULT_GSM_USDX_AMOUNT, unauthorizedAddr);
  }

  function testPermissionedByDefault() public view {
    assertFalse(
      IPermissionedGsm(address(GSM)).getIsBuyAccessOpen(),
      'Unexpected buy access status'
    );
    assertFalse(
      IPermissionedGsm(address(GSM)).getIsSellAccessOpen(),
      'Unexpected sell access status'
    );
  }

  function testSetBuyAccessOpen() public {
    vm.expectEmit(true, true, true, true, address(GSM));
    emit IPermissionedGsm.BuyAccessOpenUpdated(address(this), true);
    IPermissionedGsm(address(GSM)).setBuyAccessOpen(true);
    assertTrue(IPermissionedGsm(address(GSM)).getIsBuyAccessOpen(), 'Unexpected buy access status');
    assertFalse(
      IPermissionedGsm(address(GSM)).getIsSellAccessOpen(),
      'Unexpected sell access status'
    );

    vm.expectEmit(true, true, true, true, address(GSM));
    emit IPermissionedGsm.BuyAccessOpenUpdated(address(this), false);
    IPermissionedGsm(address(GSM)).setBuyAccessOpen(false);
    assertFalse(
      IPermissionedGsm(address(GSM)).getIsBuyAccessOpen(),
      'Unexpected buy access status'
    );
  }

  function testSetSellAccessOpen() public {
    vm.expectEmit(true, true, true, true, address(GSM));
    emit IPermissionedGsm.SellAccessOpenUpdated(address(this), true);
    IPermissionedGsm(address(GSM)).setSellAccessOpen(true);
    assertTrue(
      IPermissionedGsm(address(GSM)).getIsSellAccessOpen(),
      'Unexpected sell access status'
    );
    assertFalse(
      IPermissionedGsm(address(GSM)).getIsBuyAccessOpen(),
      'Unexpected buy access status'
    );

    vm.expectEmit(true, true, true, true, address(GSM));
    emit IPermissionedGsm.SellAccessOpenUpdated(address(this), false);
    IPermissionedGsm(address(GSM)).setSellAccessOpen(false);
    assertFalse(
      IPermissionedGsm(address(GSM)).getIsSellAccessOpen(),
      'Unexpected sell access status'
    );
  }

  function testRevertSetBuyAccessOpenUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        unauthorizedAddr,
        GSM_CONFIGURATOR_ROLE
      )
    );
    vm.prank(unauthorizedAddr);
    IPermissionedGsm(address(GSM)).setBuyAccessOpen(true);
  }

  function testRevertSetSellAccessOpenUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        unauthorizedAddr,
        GSM_CONFIGURATOR_ROLE
      )
    );
    vm.prank(unauthorizedAddr);
    IPermissionedGsm(address(GSM)).setSellAccessOpen(true);
  }

  function testRevertSetBuyAccessOpenAlreadyOpen() public {
    IPermissionedGsm(address(GSM)).setBuyAccessOpen(true);

    vm.expectRevert('GSM_NO_CHANGE_IN_BUY_ACCESS');
    IPermissionedGsm(address(GSM)).setBuyAccessOpen(true);
  }

  function testRevertSetBuyAccessOpenAlreadyRestricted() public {
    vm.expectRevert('GSM_NO_CHANGE_IN_BUY_ACCESS');
    IPermissionedGsm(address(GSM)).setBuyAccessOpen(false);
  }

  function testRevertSetSellAccessOpenAlreadyOpen() public {
    IPermissionedGsm(address(GSM)).setSellAccessOpen(true);

    vm.expectRevert('GSM_NO_CHANGE_IN_SELL_ACCESS');
    IPermissionedGsm(address(GSM)).setSellAccessOpen(true);
  }

  function testRevertSetSellAccessOpenAlreadyRestricted() public {
    vm.expectRevert('GSM_NO_CHANGE_IN_SELL_ACCESS');
    IPermissionedGsm(address(GSM)).setSellAccessOpen(false);
  }

  function testSwapWhenAccessOpen() public {
    IPermissionedGsm(address(GSM)).setBuyAccessOpen(true);
    IPermissionedGsm(address(GSM)).setSellAccessOpen(true);

    vm.startPrank(unauthorizedAddr);
    (uint256 soldAmount, ) = GSM.sellAsset(DEFAULT_GSM_USDX_AMOUNT, unauthorizedAddr);
    (uint256 boughtAmount, ) = GSM.buyAsset(DEFAULT_GSM_USDX_AMOUNT, unauthorizedAddr);
    vm.stopPrank();

    assertEq(soldAmount, DEFAULT_GSM_USDX_AMOUNT, 'Unexpected sold asset amount');
    assertEq(boughtAmount, DEFAULT_GSM_USDX_AMOUNT, 'Unexpected bought asset amount');
  }

  function testBuyAssetWhenOnlyBuyAccessOpen() public {
    IPermissionedGsm(address(GSM)).setBuyAccessOpen(true);

    vm.prank(unauthorizedAddr);
    (uint256 boughtAmount, ) = GSM.buyAsset(DEFAULT_GSM_USDX_AMOUNT, unauthorizedAddr);
    assertEq(boughtAmount, DEFAULT_GSM_USDX_AMOUNT, 'Unexpected bought asset amount');

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        unauthorizedAddr,
        GSM_SELL_ASSET_ROLE
      )
    );
    vm.prank(unauthorizedAddr);
    GSM.sellAsset(DEFAULT_GSM_USDX_AMOUNT, unauthorizedAddr);
  }

  function testSellAssetWhenOnlySellAccessOpen() public {
    IPermissionedGsm(address(GSM)).setSellAccessOpen(true);

    vm.prank(unauthorizedAddr);
    (uint256 soldAmount, ) = GSM.sellAsset(DEFAULT_GSM_USDX_AMOUNT, unauthorizedAddr);
    assertEq(soldAmount, DEFAULT_GSM_USDX_AMOUNT, 'Unexpected sold asset amount');

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        unauthorizedAddr,
        GSM_BUY_ASSET_ROLE
      )
    );
    vm.prank(unauthorizedAddr);
    GSM.buyAsset(DEFAULT_GSM_USDX_AMOUNT, unauthorizedAddr);
  }

  function testRevertSwapAfterAccessClosed() public {
    IPermissionedGsm(address(GSM)).setBuyAccessOpen(true);
    IPermissionedGsm(address(GSM)).setSellAccessOpen(true);
    IPermissionedGsm(address(GSM)).setBuyAccessOpen(false);
    IPermissionedGsm(address(GSM)).setSellAccessOpen(false);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        unauthorizedAddr,
        GSM_BUY_ASSET_ROLE
      )
    );
    vm.prank(unauthorizedAddr);
    GSM.buyAsset(DEFAULT_GSM_USDX_AMOUNT, unauthorizedAddr);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        unauthorizedAddr,
        GSM_SELL_ASSET_ROLE
      )
    );
    vm.prank(unauthorizedAddr);
    GSM.sellAsset(DEFAULT_GSM_USDX_AMOUNT, unauthorizedAddr);
  }

  function testBuyAssetWithSigUnauthorizedSignerWhenAccessOpen() public {
    IPermissionedGsm(address(GSM)).setBuyAccessOpen(true);

    uint256 deadline = block.timestamp + 1 hours;
    (address signer, uint256 signerKey) = makeAddrAndKey('unauthorizedSigner');
    ghoFaucet(signer, DEFAULT_GSM_GHO_AMOUNT * 2);
    vm.prank(signer);
    GHO_TOKEN.approve(address(GSM), type(uint256).max);

    bytes memory signature;
    {
      bytes32 digest = _getBuyAssetTypedDataHash(
        address(GSM),
        EIP712Types.BuyAssetWithSig({
          originator: signer,
          minAmount: DEFAULT_GSM_USDX_AMOUNT,
          receiver: signer,
          nonce: GSM.nonces(signer),
          deadline: deadline
        })
      );
      (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
      signature = abi.encodePacked(r, s, v);
    }

    assertFalse(
      GSM.hasRole(GSM_BUY_ASSET_ROLE, signer),
      'Signer unexpectedly holds the BUY_ASSET_ROLE'
    );
    assertFalse(
      GSM.hasRole(GSM_BUY_ASSET_ROLE, unauthorizedAddr),
      'Relayer unexpectedly holds the BUY_ASSET_ROLE'
    );

    uint256 signerGhoBefore = GHO_TOKEN.balanceOf(signer);
    uint256 signerUnderlyingBefore = UNDERLYING.balanceOf(signer);
    uint256 relayerGhoBefore = GHO_TOKEN.balanceOf(unauthorizedAddr);
    uint256 relayerUnderlyingBefore = UNDERLYING.balanceOf(unauthorizedAddr);

    vm.prank(unauthorizedAddr);
    (uint256 assetAmount, uint256 ghoSold) = GSM.buyAssetWithSig(
      signer,
      DEFAULT_GSM_USDX_AMOUNT,
      signer,
      deadline,
      signature
    );
    assertEq(assetAmount, DEFAULT_GSM_USDX_AMOUNT, 'Unexpected bought asset amount');
    assertEq(
      GHO_TOKEN.balanceOf(signer),
      signerGhoBefore - ghoSold,
      'Unexpected signer GHO balance'
    );
    assertEq(
      UNDERLYING.balanceOf(signer),
      signerUnderlyingBefore + assetAmount,
      'Unexpected signer underlying balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(unauthorizedAddr),
      relayerGhoBefore,
      'Unexpected relayer GHO balance'
    );
    assertEq(
      UNDERLYING.balanceOf(unauthorizedAddr),
      relayerUnderlyingBefore,
      'Unexpected relayer underlying balance'
    );
  }

  function testSellAssetWithSigUnauthorizedSignerWhenAccessOpen() public {
    IPermissionedGsm(address(GSM)).setSellAccessOpen(true);

    uint256 deadline = block.timestamp + 1 hours;
    (address signer, uint256 signerKey) = makeAddrAndKey('unauthorizedSigner');
    _mintUnderlying(signer, DEFAULT_GSM_USDX_AMOUNT);
    vm.prank(signer);
    UNDERLYING.approve(address(GSM), type(uint256).max);

    bytes memory signature;
    {
      bytes32 digest = _getSellAssetTypedDataHash(
        address(GSM),
        EIP712Types.SellAssetWithSig({
          originator: signer,
          maxAmount: DEFAULT_GSM_USDX_AMOUNT,
          receiver: signer,
          nonce: GSM.nonces(signer),
          deadline: deadline
        })
      );
      (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
      signature = abi.encodePacked(r, s, v);
    }

    assertFalse(
      GSM.hasRole(GSM_SELL_ASSET_ROLE, signer),
      'Signer unexpectedly holds the SELL_ASSET_ROLE'
    );
    assertFalse(
      GSM.hasRole(GSM_SELL_ASSET_ROLE, unauthorizedAddr),
      'Relayer unexpectedly holds the SELL_ASSET_ROLE'
    );

    uint256 signerGhoBefore = GHO_TOKEN.balanceOf(signer);
    uint256 signerUnderlyingBefore = UNDERLYING.balanceOf(signer);
    uint256 relayerGhoBefore = GHO_TOKEN.balanceOf(unauthorizedAddr);
    uint256 relayerUnderlyingBefore = UNDERLYING.balanceOf(unauthorizedAddr);

    vm.prank(unauthorizedAddr);
    (uint256 assetAmount, uint256 ghoBought) = GSM.sellAssetWithSig(
      signer,
      DEFAULT_GSM_USDX_AMOUNT,
      signer,
      deadline,
      signature
    );
    assertEq(assetAmount, DEFAULT_GSM_USDX_AMOUNT, 'Unexpected sold asset amount');
    assertEq(
      GHO_TOKEN.balanceOf(signer),
      signerGhoBefore + ghoBought,
      'Unexpected signer GHO balance'
    );
    assertEq(
      UNDERLYING.balanceOf(signer),
      signerUnderlyingBefore - assetAmount,
      'Unexpected signer underlying balance'
    );
    assertEq(
      GHO_TOKEN.balanceOf(unauthorizedAddr),
      relayerGhoBefore,
      'Unexpected relayer GHO balance'
    );
    assertEq(
      UNDERLYING.balanceOf(unauthorizedAddr),
      relayerUnderlyingBefore,
      'Unexpected relayer underlying balance'
    );
  }

  function testSwapRolesAdminIsDefaultAdmin() public view {
    assertEq(
      GSM.getRoleAdmin(GSM_BUY_ASSET_ROLE),
      DEFAULT_ADMIN_ROLE,
      'Unexpected BUY_ASSET_ROLE admin'
    );
    assertEq(
      GSM.getRoleAdmin(GSM_SELL_ASSET_ROLE),
      DEFAULT_ADMIN_ROLE,
      'Unexpected SELL_ASSET_ROLE admin'
    );
  }

  function testAdminGrantsAndRevokesSwapRoles() public {
    assertTrue(GSM.hasRole(DEFAULT_ADMIN_ROLE, address(this)), 'Test is not the admin');

    GSM.grantRole(GSM_BUY_ASSET_ROLE, unauthorizedAddr);
    GSM.grantRole(GSM_SELL_ASSET_ROLE, unauthorizedAddr);
    assertTrue(GSM.hasRole(GSM_BUY_ASSET_ROLE, unauthorizedAddr), 'BUY_ASSET_ROLE not granted');
    assertTrue(GSM.hasRole(GSM_SELL_ASSET_ROLE, unauthorizedAddr), 'SELL_ASSET_ROLE not granted');

    GSM.revokeRole(GSM_BUY_ASSET_ROLE, unauthorizedAddr);
    GSM.revokeRole(GSM_SELL_ASSET_ROLE, unauthorizedAddr);
    assertFalse(GSM.hasRole(GSM_BUY_ASSET_ROLE, unauthorizedAddr), 'BUY_ASSET_ROLE not revoked');
    assertFalse(GSM.hasRole(GSM_SELL_ASSET_ROLE, unauthorizedAddr), 'SELL_ASSET_ROLE not revoked');
  }

  function testRevertSwapRolesManagedByNonAdmin() public {
    bytes32[6] memory roles = [
      GSM_CONFIGURATOR_ROLE,
      GSM_TOKEN_RESCUER_ROLE,
      GSM_SWAP_FREEZER_ROLE,
      GSM_LIQUIDATOR_ROLE,
      GSM_BUY_ASSET_ROLE,
      GSM_SELL_ASSET_ROLE
    ];
    for (uint256 i = 0; i < roles.length; i++) {
      address holder = makeAddr(string.concat('roleHolder', vm.toString(i)));
      GSM.grantRole(roles[i], holder);

      vm.expectRevert(
        abi.encodeWithSelector(
          IAccessControl.AccessControlUnauthorizedAccount.selector,
          holder,
          DEFAULT_ADMIN_ROLE
        )
      );
      vm.prank(holder);
      GSM.grantRole(GSM_BUY_ASSET_ROLE, unauthorizedAddr);

      vm.expectRevert(
        abi.encodeWithSelector(
          IAccessControl.AccessControlUnauthorizedAccount.selector,
          holder,
          DEFAULT_ADMIN_ROLE
        )
      );
      vm.prank(holder);
      GSM.grantRole(GSM_SELL_ASSET_ROLE, unauthorizedAddr);

      vm.expectRevert(
        abi.encodeWithSelector(
          IAccessControl.AccessControlUnauthorizedAccount.selector,
          holder,
          DEFAULT_ADMIN_ROLE
        )
      );
      vm.prank(holder);
      GSM.revokeRole(GSM_BUY_ASSET_ROLE, ALICE);

      vm.expectRevert(
        abi.encodeWithSelector(
          IAccessControl.AccessControlUnauthorizedAccount.selector,
          holder,
          DEFAULT_ADMIN_ROLE
        )
      );
      vm.prank(holder);
      GSM.revokeRole(GSM_SELL_ASSET_ROLE, ALICE);
    }
  }

  function testBuyAssetToReceiverWithoutRole() public {
    address receiver = makeAddr('receiver');
    ghoFaucet(ALICE, DEFAULT_GSM_GHO_AMOUNT * 2);
    vm.prank(ALICE);
    GHO_TOKEN.approve(address(GSM), type(uint256).max);

    assertTrue(GSM.hasRole(GSM_BUY_ASSET_ROLE, ALICE), 'Alice does not hold the BUY_ASSET_ROLE');
    assertFalse(
      GSM.hasRole(GSM_BUY_ASSET_ROLE, receiver),
      'Receiver unexpectedly holds the BUY_ASSET_ROLE'
    );

    uint256 aliceGhoBefore = GHO_TOKEN.balanceOf(ALICE);
    uint256 aliceUnderlyingBefore = UNDERLYING.balanceOf(ALICE);

    vm.prank(ALICE);
    (uint256 assetAmount, uint256 ghoSold) = GSM.buyAsset(DEFAULT_GSM_USDX_AMOUNT, receiver);
    assertEq(assetAmount, DEFAULT_GSM_USDX_AMOUNT, 'Unexpected bought asset amount');
    assertEq(GHO_TOKEN.balanceOf(ALICE), aliceGhoBefore - ghoSold, 'Unexpected Alice GHO balance');
    assertEq(
      UNDERLYING.balanceOf(ALICE),
      aliceUnderlyingBefore,
      'Unexpected Alice underlying balance'
    );
    assertEq(UNDERLYING.balanceOf(receiver), assetAmount, 'Unexpected receiver underlying balance');
    assertEq(GHO_TOKEN.balanceOf(receiver), 0, 'Unexpected receiver GHO balance');
  }

  function testSellAssetToReceiverWithoutRole() public {
    address receiver = makeAddr('receiver');
    _mintUnderlying(ALICE, DEFAULT_GSM_USDX_AMOUNT);
    vm.prank(ALICE);
    UNDERLYING.approve(address(GSM), type(uint256).max);

    assertTrue(GSM.hasRole(GSM_SELL_ASSET_ROLE, ALICE), 'Alice does not hold the SELL_ASSET_ROLE');
    assertFalse(
      GSM.hasRole(GSM_SELL_ASSET_ROLE, receiver),
      'Receiver unexpectedly holds the SELL_ASSET_ROLE'
    );

    uint256 aliceGhoBefore = GHO_TOKEN.balanceOf(ALICE);
    uint256 aliceUnderlyingBefore = UNDERLYING.balanceOf(ALICE);

    vm.prank(ALICE);
    (uint256 assetAmount, uint256 ghoBought) = GSM.sellAsset(DEFAULT_GSM_USDX_AMOUNT, receiver);
    assertEq(assetAmount, DEFAULT_GSM_USDX_AMOUNT, 'Unexpected sold asset amount');
    assertEq(
      UNDERLYING.balanceOf(ALICE),
      aliceUnderlyingBefore - assetAmount,
      'Unexpected Alice underlying balance'
    );
    assertEq(GHO_TOKEN.balanceOf(ALICE), aliceGhoBefore, 'Unexpected Alice GHO balance');
    assertEq(GHO_TOKEN.balanceOf(receiver), ghoBought, 'Unexpected receiver GHO balance');
    assertEq(UNDERLYING.balanceOf(receiver), 0, 'Unexpected receiver underlying balance');
  }

  function testRevertBuyAssetUnauthorizedToReceiverWithRole() public {
    assertTrue(GSM.hasRole(GSM_BUY_ASSET_ROLE, ALICE), 'Alice does not hold the BUY_ASSET_ROLE');

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        unauthorizedAddr,
        GSM_BUY_ASSET_ROLE
      )
    );
    vm.prank(unauthorizedAddr);
    GSM.buyAsset(DEFAULT_GSM_USDX_AMOUNT, ALICE);
  }

  function testRevertSellAssetUnauthorizedToReceiverWithRole() public {
    assertTrue(GSM.hasRole(GSM_SELL_ASSET_ROLE, ALICE), 'Alice does not hold the SELL_ASSET_ROLE');

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        unauthorizedAddr,
        GSM_SELL_ASSET_ROLE
      )
    );
    vm.prank(unauthorizedAddr);
    GSM.sellAsset(DEFAULT_GSM_USDX_AMOUNT, ALICE);
  }

  function testFuzzRevertBuyAssetUnauthorizedOriginator(address originator) public {
    // The proxy admin cannot call through the proxy
    vm.assume(originator != SHORT_EXECUTOR);
    vm.assume(!GSM.hasRole(GSM_BUY_ASSET_ROLE, originator));

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        originator,
        GSM_BUY_ASSET_ROLE
      )
    );
    vm.prank(originator);
    GSM.buyAsset(DEFAULT_GSM_USDX_AMOUNT, originator);
  }

  function testFuzzRevertSellAssetUnauthorizedOriginator(address originator) public {
    // The proxy admin cannot call through the proxy
    vm.assume(originator != SHORT_EXECUTOR);
    vm.assume(!GSM.hasRole(GSM_SELL_ASSET_ROLE, originator));

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        originator,
        GSM_SELL_ASSET_ROLE
      )
    );
    vm.prank(originator);
    GSM.sellAsset(DEFAULT_GSM_USDX_AMOUNT, originator);
  }

  function testRevertBuyAssetUnauthorizedBeforeZeroAmount() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        unauthorizedAddr,
        GSM_BUY_ASSET_ROLE
      )
    );
    vm.prank(unauthorizedAddr);
    GSM.buyAsset(0, unauthorizedAddr);

    GSM.grantRole(GSM_BUY_ASSET_ROLE, unauthorizedAddr);
    vm.expectRevert('INVALID_AMOUNT');
    vm.prank(unauthorizedAddr);
    GSM.buyAsset(0, unauthorizedAddr);
  }

  function testRevertSellAssetUnauthorizedBeforeZeroAmount() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        unauthorizedAddr,
        GSM_SELL_ASSET_ROLE
      )
    );
    vm.prank(unauthorizedAddr);
    GSM.sellAsset(0, unauthorizedAddr);

    GSM.grantRole(GSM_SELL_ASSET_ROLE, unauthorizedAddr);
    vm.expectRevert('INVALID_AMOUNT');
    vm.prank(unauthorizedAddr);
    GSM.sellAsset(0, unauthorizedAddr);
  }

  function testRevertBuyAssetUnauthorizedBeforeInsufficientLiquidity() public {
    uint256 amount = GSM.getAvailableLiquidity() + 1;

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        unauthorizedAddr,
        GSM_BUY_ASSET_ROLE
      )
    );
    vm.prank(unauthorizedAddr);
    GSM.buyAsset(amount, unauthorizedAddr);

    GSM.grantRole(GSM_BUY_ASSET_ROLE, unauthorizedAddr);
    vm.expectRevert('INSUFFICIENT_AVAILABLE_EXOGENOUS_ASSET_LIQUIDITY');
    vm.prank(unauthorizedAddr);
    GSM.buyAsset(amount, unauthorizedAddr);
  }

  function testRevertSellAssetUnauthorizedBeforeExposureCap() public {
    uint256 amount = uint256(GSM.getExposureCap()) + 1;

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        unauthorizedAddr,
        GSM_SELL_ASSET_ROLE
      )
    );
    vm.prank(unauthorizedAddr);
    GSM.sellAsset(amount, unauthorizedAddr);

    GSM.grantRole(GSM_SELL_ASSET_ROLE, unauthorizedAddr);
    vm.expectRevert('EXOGENOUS_ASSET_EXPOSURE_TOO_HIGH');
    vm.prank(unauthorizedAddr);
    GSM.sellAsset(amount, unauthorizedAddr);
  }

  function testRevertBuyAssetUnauthorizedBeforeInsufficientBalance() public {
    address originator = makeAddr('noBalance');
    vm.prank(originator);
    GHO_TOKEN.approve(address(GSM), type(uint256).max);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        originator,
        GSM_BUY_ASSET_ROLE
      )
    );
    vm.prank(originator);
    GSM.buyAsset(DEFAULT_GSM_USDX_AMOUNT, originator);

    GSM.grantRole(GSM_BUY_ASSET_ROLE, originator);
    vm.expectRevert(stdError.arithmeticError);
    vm.prank(originator);
    GSM.buyAsset(DEFAULT_GSM_USDX_AMOUNT, originator);
  }

  function testRevertSellAssetUnauthorizedBeforeInsufficientBalance() public {
    address originator = makeAddr('noBalance');
    vm.prank(originator);
    UNDERLYING.approve(address(GSM), type(uint256).max);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        originator,
        GSM_SELL_ASSET_ROLE
      )
    );
    vm.prank(originator);
    GSM.sellAsset(DEFAULT_GSM_USDX_AMOUNT, originator);

    GSM.grantRole(GSM_SELL_ASSET_ROLE, originator);
    vm.expectRevert(_insufficientBalanceError(originator, DEFAULT_GSM_USDX_AMOUNT));
    vm.prank(originator);
    GSM.sellAsset(DEFAULT_GSM_USDX_AMOUNT, originator);
  }

  function _canSwap(address originator, bool isBuy) internal view returns (bool) {
    return IPermissionedGsm(address(GSM)).canSwap(originator, isBuy);
  }

  function _swapRole(bool isBuy) internal pure returns (bytes32) {
    return isBuy ? GSM_BUY_ASSET_ROLE : GSM_SELL_ASSET_ROLE;
  }

  function _setAccessOpen(bool isBuy, bool open) internal {
    if (isBuy) {
      IPermissionedGsm(address(GSM)).setBuyAccessOpen(open);
    } else {
      IPermissionedGsm(address(GSM)).setSellAccessOpen(open);
    }
  }

  function _assertCanSwapMatchesSwap(
    address originator,
    bool isBuy,
    bytes memory revertData
  ) internal {
    bool expected = revertData.length == 0;
    assertEq(_canSwap(originator, isBuy), expected, 'Unexpected view result');
    uint256 snapshotId = vm.snapshotState();
    vm.prank(originator);
    (bool success, bytes memory returnData) = address(GSM).call(
      isBuy
        ? abi.encodeCall(GSM.buyAsset, (DEFAULT_GSM_USDX_AMOUNT, originator))
        : abi.encodeCall(GSM.sellAsset, (DEFAULT_GSM_USDX_AMOUNT, originator))
    );
    vm.revertToState(snapshotId);

    assertEq(success, expected, 'View result does not match the swap outcome');
    if (!success) {
      assertEq(returnData, revertData, 'Unexpected swap revert data');
    }
  }

  function _roleRevertData(address originator, bool isBuy) internal pure returns (bytes memory) {
    return
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        originator,
        _swapRole(isBuy)
      );
  }

  function testCanSwapRoleAndFlagTruthTable() public {
    address holder = makeAddr('holder');
    address otherSideHolder = makeAddr('otherSideHolder');

    for (uint256 i = 0; i < 2; i++) {
      bool isBuy = i == 0;
      GSM.grantRole(_swapRole(isBuy), holder);
      GSM.grantRole(_swapRole(!isBuy), otherSideHolder);

      assertFalse(_canSwap(unauthorizedAddr, isBuy), 'Closed without role');
      assertTrue(_canSwap(holder, isBuy), 'Closed with matching role');
      assertFalse(_canSwap(otherSideHolder, isBuy), 'Closed with only the other side role');

      _setAccessOpen(isBuy, true);
      assertTrue(_canSwap(unauthorizedAddr, isBuy), 'Open without role');
      assertTrue(_canSwap(holder, isBuy), 'Open with matching role');
      assertFalse(_canSwap(unauthorizedAddr, !isBuy), 'Opening one side opened the other');
      assertFalse(_canSwap(holder, !isBuy), 'Opening one side opened the other for a holder');
      assertTrue(_canSwap(otherSideHolder, !isBuy), 'Other side role lost after opening');

      _setAccessOpen(isBuy, false);
      assertFalse(_canSwap(unauthorizedAddr, isBuy), 'Closed again without role');

      GSM.revokeRole(_swapRole(isBuy), holder);
      GSM.revokeRole(_swapRole(!isBuy), otherSideHolder);
    }
  }

  function testCanSwapWhenFrozen() public {
    address holder = makeAddr('holder');
    GSM.grantRole(GSM_BUY_ASSET_ROLE, holder);
    GSM.grantRole(GSM_SELL_ASSET_ROLE, holder);

    vm.prank(address(GHO_GSM_SWAP_FREEZER));
    GSM.setSwapFreeze(true);
    for (uint256 i = 0; i < 2; i++) {
      bool isBuy = i == 0;
      assertFalse(_canSwap(holder, isBuy), 'Frozen with role');
      _setAccessOpen(isBuy, true);
      assertFalse(_canSwap(unauthorizedAddr, isBuy), 'Frozen with access open');
      _setAccessOpen(isBuy, false);
    }

    vm.prank(address(GHO_GSM_SWAP_FREEZER));
    GSM.setSwapFreeze(false);
    assertTrue(_canSwap(holder, true), 'Unfrozen buy with role');
    assertTrue(_canSwap(holder, false), 'Unfrozen sell with role');
    assertFalse(_canSwap(unauthorizedAddr, true), 'Unfrozen buy without role');
  }

  function testCanSwapWhenSeized() public {
    address holder = makeAddr('holder');
    GSM.grantRole(GSM_BUY_ASSET_ROLE, holder);
    GSM.grantRole(GSM_SELL_ASSET_ROLE, holder);
    IPermissionedGsm(address(GSM)).setBuyAccessOpen(true);
    IPermissionedGsm(address(GSM)).setSellAccessOpen(true);

    vm.prank(address(GHO_GSM_LAST_RESORT_LIQUIDATOR));
    GSM.seize();

    for (uint256 i = 0; i < 2; i++) {
      bool isBuy = i == 0;
      assertFalse(_canSwap(holder, isBuy), 'Seized with role');
      assertFalse(_canSwap(unauthorizedAddr, isBuy), 'Seized with access open');
    }
  }

  function testCanSwapMatchesSwap() public {
    for (uint256 i = 0; i < 2; i++) {
      bool isBuy = i == 0;

      _assertCanSwapMatchesSwap(unauthorizedAddr, isBuy, _roleRevertData(unauthorizedAddr, isBuy));

      _setAccessOpen(isBuy, true);
      _assertCanSwapMatchesSwap(unauthorizedAddr, isBuy, '');
      _setAccessOpen(isBuy, false);

      GSM.grantRole(_swapRole(!isBuy), unauthorizedAddr);
      _assertCanSwapMatchesSwap(unauthorizedAddr, isBuy, _roleRevertData(unauthorizedAddr, isBuy));
      GSM.revokeRole(_swapRole(!isBuy), unauthorizedAddr);

      GSM.grantRole(_swapRole(isBuy), unauthorizedAddr);
      _assertCanSwapMatchesSwap(unauthorizedAddr, isBuy, '');
      GSM.revokeRole(_swapRole(isBuy), unauthorizedAddr);
    }
  }

  function testCanSwapIsGlobalAndCallerIndependent() public {
    assertTrue(GSM.canSwap(), 'Unexpected global swap state');
    assertFalse(_canSwap(unauthorizedAddr, true), 'Unexpected originator buy state');
    assertFalse(_canSwap(unauthorizedAddr, false), 'Unexpected originator sell state');

    vm.prank(unauthorizedAddr);
    assertTrue(GSM.canSwap(), 'Global swap state depends on the caller');

    vm.expectRevert(_roleRevertData(unauthorizedAddr, true));
    vm.prank(unauthorizedAddr);
    GSM.buyAsset(DEFAULT_GSM_USDX_AMOUNT, unauthorizedAddr);
  }

  function testFuzzCanSwapOriginator(
    address originator,
    bool isBuy,
    bool hasSwapRole,
    bool otherSideRole,
    bool open
  ) public {
    GSM.revokeRole(_swapRole(isBuy), originator);
    if (hasSwapRole) {
      GSM.grantRole(_swapRole(isBuy), originator);
    }
    if (otherSideRole) {
      GSM.grantRole(_swapRole(!isBuy), originator);
    }
    if (open) {
      _setAccessOpen(isBuy, true);
    }

    assertEq(_canSwap(originator, isBuy), open || hasSwapRole, 'Unexpected originator swap state');
  }
}

contract TestPermissionedGsmAccess is TestPermissionedGsmAccessBase {
  function _gsm() internal view override returns (Gsm) {
    return GHO_GSM;
  }

  function _underlying() internal view override returns (IERC20) {
    return IERC20(address(USDX_TOKEN));
  }

  function _mintUnderlying(address to, uint256 amount) internal override {
    vm.prank(FAUCET);
    USDX_TOKEN.mint(to, amount);
  }

  function _insufficientBalanceError(
    address account,
    uint256 needed
  ) internal pure override returns (bytes memory) {
    return
      abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, account, 0, needed);
  }
}

contract TestPermissionedGsm4626Access is TestPermissionedGsmAccessBase {
  function _gsm() internal view override returns (Gsm) {
    return Gsm(address(GHO_GSM_4626));
  }

  function _underlying() internal view override returns (IERC20) {
    return IERC20(address(USDX_4626_TOKEN));
  }

  function _mintUnderlying(address to, uint256 amount) internal override {
    _mintVaultAssets(USDX_4626_TOKEN, USDX_TOKEN, to, amount);
  }

  function _insufficientBalanceError(
    address,
    uint256
  ) internal pure override returns (bytes memory) {
    return abi.encodeWithSignature('Error(string)', 'ERC20: transfer amount exceeds balance');
  }
}
