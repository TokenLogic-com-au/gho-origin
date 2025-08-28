## Overview

These contracts in conjunction work to onboard/offboard Gho Stability Modules on any network. They allow the Aave DAO to offer GHO liquidity (and potentially earn fees) by swapping to/from GHO against a specified asset.

The contracts work in tandem to ultimately fund a GSM/GSM4626 instance.

### [OwnableFacilitator](/src/contracts/facilitators/gsm/OwnableFacilitator.sol)

This contract is to be deployed on Ethereum Mainnet and serves to mint GHO. The DAO needs to grant this contract a mint capacity on the GHO token and then the OwnableFacilitator can mint up to that amount. The OwnableFacilitator can also burn tokens it receives back.

The OwnableFacilitator can mint to any address (like a GhoReserve) up to the remaining amount of capacity.

### [GhoReserve](/src/contracts/facilitators/gsm/GhoReserve.sol)

The GhoReserve acts as a liquidity hub for multiple entities to draw GHO from. Multiple GSMs can be onboarded onto a GhoReserve with a line of credit to draw from and pay back as swaps take place.

The GhoReserve is funded by the OwnableFacilitator on Mainnet, or it will receive bridged GHO via governance.

### [Gsm](/src/contracts/facilitators/gsm/Gsm.sol)

The Gho Stability Module contract provides buy/sell facilities to go to/from an underlying asset to/from GHO. Via the GhoGsmSteward, exposure caps (to underlying) and Gho caps can be adjusted, as well as fees paid to buy/sell.

The GSM can be offboarded by seizing it and repaying all GHO back to the GhoReserve it drew from.

### [Gsm4626](/src/contracts/facilitators/gsm/Gsm4626.sol)

The Gho Stability Module 4626 to contract offers the same behavior as the regular GSM but it is to be used with ERC4626 vault shares as the underlying asset instead of an ERC20 asset.
