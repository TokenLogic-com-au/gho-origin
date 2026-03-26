// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';

import {IAccessControl} from 'src/contracts/dependencies/openzeppelin-contracts/contracts/access/IAccessControl.sol';
import {TransparentUpgradeableProxy} from 'src/contracts/dependencies/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {IGsm} from 'src/contracts/facilitators/gsm/interfaces/IGsm.sol';
import {GhoRouter} from 'src/contracts/misc/GhoRouter.sol';
import {sGhoSteward, IsGhoSteward} from 'src/contracts/misc/sGhoSteward.sol';
import {IsGho} from 'src/contracts/sgho/interfaces/IsGho.sol';
import {sGho} from 'src/contracts/sgho/sGho.sol';
import {IPool} from 'aave-v3-origin/contracts/interfaces/IPool.sol';
import {DataTypes} from 'aave-v3-origin/contracts/protocol/libraries/types/DataTypes.sol';

contract DeploySGHOandGhoRouter is Script {
  error ZeroAddress(string name);
  error ValueTooLarge(string name, uint256 value);
  error InvalidConfig(string reason);

  address internal constant MAINNET_GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
  address internal constant MAINNET_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address internal constant MAINNET_AAVE_V3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
  uint256 internal constant RAY_TO_BPS = 1e23;
  uint256 internal constant DEFAULT_SGHO_SUPPLY_CAP = 400_000_000e18;
  uint16 internal constant DEFAULT_AMP_BPS = 100_00;
  uint16 internal constant DEFAULT_FIXED_RATE_BPS = 550;
  uint16 internal constant MAX_SAFE_RATE_BPS = 50_00;

  // Current mainnet sGHO is still the interim stkGHO-derived token.
  // This cap keeps staging close to today's scale without guessing above total GHO supply.
  address internal constant CURRENT_MAINNET_SGHO = 0x1a88Df1cFe15Af22B3c4c783D4e6F7F9e0C1885d;
  // https://etherscan.io/address/0xFeeb6FE430B7523fEF2a38327241eE7153779535
  address internal constant GSM_USDC = 0xFeeb6FE430B7523fEF2a38327241eE7153779535;
  // https://etherscan.io/address/0x535b2f7C20B9C83d70e519cf9991578eF9816B7B
  address internal constant GSM_USDT = 0x535b2f7C20B9C83d70e519cf9991578eF9816B7B;

  struct Config {
    uint256 deployerPrivateKey;
    address ghoToken;
    address sghoOwner;
    address proxyAdminOwner;
    address routerOwner;
    address pauseGuardian;
    address tokenRescuer;
    address stewardOwner;
    address riskCouncil;
    address aavePool;
    uint160 sghoSupplyCap;
    uint16 amplificationBps;
    uint16 floatRateBps;
    uint16 fixedRateBps;
    bool deploySteward;
    bool seedRateConfig;
    bool useMainnetGsmDefaults;
  }

  /// @notice Deploys sGHO behind a transparent proxy, wires a staging-safe steward, then deploys GhoRouter.
  /// @dev Required env vars:
  /// - SGHO_OWNER
  /// - PROXY_ADMIN_OWNER
  /// @dev Optional env vars:
  /// - GHO_TOKEN (defaults to mainnet GHO)
  /// - SGHO_SUPPLY_CAP (defaults to 400_000_000e18)
  /// - ROUTER_OWNER (defaults to SGHO_OWNER)
  /// - SGHO_PAUSE_GUARDIAN (defaults to SGHO_OWNER)
  /// - SGHO_TOKEN_RESCUER (defaults to SGHO_OWNER)
  /// - SGHO_STEWARD_OWNER (defaults to SGHO_OWNER)
  /// - SGHO_RISK_COUNCIL (defaults to SGHO_OWNER)
  /// - SGHO_DEPLOY_STEWARD (defaults to true)
  /// - SGHO_SEED_RATE_CONFIG (defaults to true)
  /// - SGHO_AAVE_POOL (defaults to Aave v3 Ethereum pool)
  /// - SGHO_USE_AAVE_USDC_FLOAT_RATE (defaults to true)
  /// - SGHO_FLOAT_RATE_BPS (used when SGHO_USE_AAVE_USDC_FLOAT_RATE=false)
  /// - SGHO_AMP_BPS (defaults to 100_00)
  /// - SGHO_FIXED_RATE_BPS (defaults to 550)
  /// - ENABLE_MAINNET_GSMS (defaults to true on mainnet-like forks)
  /// - ROUTER_PRIVATE_KEY (defaults to PRIVATE_KEY when set)
  function run()
    external
    returns (address sghoImpl, address sghoProxy, address steward, address ghoRouter)
  {
    Config memory config = _loadConfig();
    uint16 targetRateBps = _previewTargetRate(config);

    if (config.deployerPrivateKey != 0) {
      vm.startBroadcast(config.deployerPrivateKey);
    } else {
      vm.startBroadcast(config.sghoOwner);
    }

    sghoImpl = address(new sGho());
    sghoProxy = address(
      new TransparentUpgradeableProxy(
        sghoImpl,
        config.proxyAdminOwner,
        abi.encodeCall(sGho.initialize, (config.ghoToken, config.sghoSupplyCap, config.sghoOwner))
      )
    );

    _grantSghoRoles(sghoProxy, config);

    if (config.deploySteward) {
      steward = address(new sGhoSteward(config.stewardOwner, config.riskCouncil, sghoProxy));
      IAccessControl(sghoProxy).grantRole(IsGho(sghoProxy).YIELD_MANAGER_ROLE(), steward);

      if (config.seedRateConfig) {
        sGhoSteward(steward).setRateConfig(
          IsGhoSteward.RateConfig({
            amplification: config.amplificationBps,
            floatRate: config.floatRateBps,
            fixedRate: config.fixedRateBps
          })
        );
      }
    }

    ghoRouter = address(new GhoRouter(config.routerOwner, config.ghoToken, sghoProxy));
    _configureDefaultGsms(GhoRouter(ghoRouter), config);

    vm.stopBroadcast();

    console2.log('sGHO owner', config.sghoOwner);
    console2.log('sGHO proxy admin', config.proxyAdminOwner);
    console2.log('sGHO supply cap', uint256(config.sghoSupplyCap));
    console2.log('sGHO float rate bps', uint256(config.floatRateBps));
    console2.log('sGHO fixed rate bps', uint256(config.fixedRateBps));
    console2.log('sGHO target rate bps', uint256(targetRateBps));
    console2.log('sGHO implementation', sghoImpl);
    console2.log('sGHO proxy', sghoProxy);
    if (steward != address(0)) console2.log('sGHO steward', steward);
    console2.log('GhoRouter', ghoRouter);
  }

  function _grantSghoRoles(address sghoProxy, Config memory config) internal {
    IAccessControl acl = IAccessControl(sghoProxy);
    bytes32 pauseGuardianRole = IsGho(sghoProxy).PAUSE_GUARDIAN_ROLE();
    bytes32 tokenRescuerRole = IsGho(sghoProxy).TOKEN_RESCUER_ROLE();

    if (!acl.hasRole(pauseGuardianRole, config.pauseGuardian)) {
      acl.grantRole(pauseGuardianRole, config.pauseGuardian);
    }

    if (!acl.hasRole(tokenRescuerRole, config.tokenRescuer)) {
      acl.grantRole(tokenRescuerRole, config.tokenRescuer);
    }
  }

  function _configureDefaultGsms(GhoRouter router, Config memory config) internal {
    if (!config.useMainnetGsmDefaults) {
      console2.log('Skipping default GSM allowlist; environment is not mainnet-like');
      console2.log('chain id', block.chainid);
      console2.log('GHO token', config.ghoToken);
      return;
    }

    if (_setGsmAllowed(router, GSM_USDC)) {
      console2.log('Enabled default GSM', GSM_USDC);
    } else {
      console2.log('Deferring default GSM allowlist to post-deploy transaction', GSM_USDC);
    }

    if (_setGsmAllowed(router, GSM_USDT)) {
      console2.log('Enabled default GSM', GSM_USDT);
    } else {
      console2.log('Deferring default GSM allowlist to post-deploy transaction', GSM_USDT);
    }
  }

  function _loadConfig() internal view returns (Config memory config) {
    config.deployerPrivateKey = vm.envOr(
      'ROUTER_PRIVATE_KEY',
      vm.envOr('PRIVATE_KEY', uint256(0))
    );
    config.ghoToken = vm.envOr('GHO_TOKEN', MAINNET_GHO);
    config.sghoOwner = vm.envAddress('SGHO_OWNER');
    config.proxyAdminOwner = vm.envAddress('PROXY_ADMIN_OWNER');
    config.routerOwner = vm.envOr('ROUTER_OWNER', config.sghoOwner);
    config.pauseGuardian = vm.envOr('SGHO_PAUSE_GUARDIAN', config.sghoOwner);
    config.tokenRescuer = vm.envOr('SGHO_TOKEN_RESCUER', config.sghoOwner);
    config.stewardOwner = vm.envOr('SGHO_STEWARD_OWNER', config.sghoOwner);
    config.riskCouncil = vm.envOr('SGHO_RISK_COUNCIL', config.sghoOwner);
    config.aavePool = vm.envOr('SGHO_AAVE_POOL', MAINNET_AAVE_V3_POOL);
    config.deploySteward = vm.envOr('SGHO_DEPLOY_STEWARD', true);
    config.seedRateConfig = vm.envOr('SGHO_SEED_RATE_CONFIG', true);

    uint256 supplyCap = vm.envOr('SGHO_SUPPLY_CAP', DEFAULT_SGHO_SUPPLY_CAP);
    if (supplyCap > type(uint160).max) {
      revert ValueTooLarge('SGHO_SUPPLY_CAP', supplyCap);
    }
    config.sghoSupplyCap = uint160(supplyCap);

    config.amplificationBps = _loadUint16('SGHO_AMP_BPS', DEFAULT_AMP_BPS);
    config.fixedRateBps = _loadUint16('SGHO_FIXED_RATE_BPS', DEFAULT_FIXED_RATE_BPS);
    if (vm.envOr('SGHO_USE_AAVE_USDC_FLOAT_RATE', true)) {
      config.floatRateBps = _getAaveUsdcLiquidityRateBps(config.aavePool);
    } else {
      config.floatRateBps = _loadUint16('SGHO_FLOAT_RATE_BPS', 0);
    }

    config.useMainnetGsmDefaults = vm.envOr('ENABLE_MAINNET_GSMS', _isMainnetLike(config.ghoToken));

    if (config.sghoOwner == address(0)) revert ZeroAddress('SGHO_OWNER');
    if (config.proxyAdminOwner == address(0)) revert ZeroAddress('PROXY_ADMIN_OWNER');
    if (config.routerOwner == address(0)) revert ZeroAddress('ROUTER_OWNER');
    if (config.pauseGuardian == address(0)) revert ZeroAddress('SGHO_PAUSE_GUARDIAN');
    if (config.tokenRescuer == address(0)) revert ZeroAddress('SGHO_TOKEN_RESCUER');
    if (config.stewardOwner == address(0)) revert ZeroAddress('SGHO_STEWARD_OWNER');
    if (config.riskCouncil == address(0)) revert ZeroAddress('SGHO_RISK_COUNCIL');
    if (config.aavePool == address(0)) revert ZeroAddress('SGHO_AAVE_POOL');

    if (config.ghoToken == address(0)) revert ZeroAddress('GHO_TOKEN');
    if (config.deployerPrivateKey != 0 && vm.addr(config.deployerPrivateKey) != config.sghoOwner) {
      revert InvalidConfig('ROUTER_PRIVATE_KEY/PRIVATE_KEY must match SGHO_OWNER');
    }
    if (config.proxyAdminOwner == config.sghoOwner) {
      revert InvalidConfig('PROXY_ADMIN_OWNER must differ from SGHO_OWNER');
    }
    if (config.proxyAdminOwner == config.pauseGuardian) {
      revert InvalidConfig('PROXY_ADMIN_OWNER must differ from SGHO_PAUSE_GUARDIAN');
    }
    if (config.proxyAdminOwner == config.tokenRescuer) {
      revert InvalidConfig('PROXY_ADMIN_OWNER must differ from SGHO_TOKEN_RESCUER');
    }
    if (config.seedRateConfig && !config.deploySteward) {
      revert InvalidConfig('SGHO_SEED_RATE_CONFIG requires SGHO_DEPLOY_STEWARD=true');
    }
    if (config.seedRateConfig && config.stewardOwner != config.sghoOwner) {
      revert InvalidConfig('SGHO_STEWARD_OWNER must equal SGHO_OWNER when seeding rate config');
    }
    if (config.ghoToken == MAINNET_GHO && CURRENT_MAINNET_SGHO.code.length == 0) {
      revert InvalidConfig('Current mainnet sGHO reference missing code');
    }
    if (_previewTargetRate(config) > MAX_SAFE_RATE_BPS) {
      revert InvalidConfig('Configured sGHO target rate exceeds MAX_SAFE_RATE');
    }
  }

  function _loadUint16(string memory key, uint16 defaultValue) internal view returns (uint16 value) {
    uint256 rawValue = vm.envOr(key, uint256(defaultValue));
    if (rawValue > type(uint16).max) {
      revert ValueTooLarge(key, rawValue);
    }
    return uint16(rawValue);
  }

  function _getAaveUsdcLiquidityRateBps(address pool) internal view returns (uint16) {
    DataTypes.ReserveDataLegacy memory reserveData = IPool(pool).getReserveData(MAINNET_USDC);
    uint256 liquidityRateBps = uint256(reserveData.currentLiquidityRate) / RAY_TO_BPS;
    if (liquidityRateBps > type(uint16).max) {
      revert ValueTooLarge('SGHO_FLOAT_RATE_BPS', liquidityRateBps);
    }
    return uint16(liquidityRateBps);
  }

  function _previewTargetRate(Config memory config) internal pure returns (uint16) {
    uint256 targetRate = (uint256(config.amplificationBps) * config.floatRateBps) / 100_00 + config.fixedRateBps;
    if (targetRate > type(uint16).max) {
      revert ValueTooLarge('SGHO_TARGET_RATE_BPS', targetRate);
    }
    return uint16(targetRate);
  }

  function _setGsmAllowed(GhoRouter router, address gsm) internal returns (bool success) {
    (success, ) = address(router).call(abi.encodeCall(GhoRouter.setGsmAllowed, (gsm, true)));
  }

  function _isMainnetLike(address ghoToken) internal view returns (bool) {
    if (ghoToken != MAINNET_GHO) {
      return false;
    }

    if (GSM_USDC.code.length == 0 || GSM_USDT.code.length == 0) {
      return false;
    }

    if (block.chainid == 1 || block.chainid == 9991) {
      return true;
    }

    try IGsm(GSM_USDC).GHO_TOKEN() returns (address ghoTokenFromGsmUsdc) {
      if (ghoTokenFromGsmUsdc != ghoToken) {
        return false;
      }
    } catch {
      return false;
    }

    try IGsm(GSM_USDT).GHO_TOKEN() returns (address ghoTokenFromGsmUsdt) {
      return ghoTokenFromGsmUsdt == ghoToken;
    } catch {
      return false;
    }
  }
}
