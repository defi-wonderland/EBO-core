# EBO - Epoch Block Oracle

> [!CAUTION]  
> The code has not been audited yet, tread with caution.

> [!CAUTION] 
> After the established thawing period the losing pledgers can withdraw their stake from Horizon.  
> Rewards from dispute escalations should be claimed or the losing pledgers slashed before that period ends to ensure that funds are available. 
    

## Overview

EBO is a mechanism for clock synchronization in the multichain world. It allows The Graph to permissionlessly sync up clocks between the protocol chain (Arbitrum) and multiple other chains supported by them to pay rewards to indexers. 

## Setup

This project uses [Foundry](https://book.getfoundry.sh/). To build it locally, run:

```sh
git clone git@github.com:defi-wonderland/EBO-core.git
cd EBO-core
yarn install
yarn build
```

### Available Commands

Make sure to set `ARBITRUM_RPC` environment variable before running end-to-end tests.

| Yarn Command            | Description                                                |
| ----------------------- | ---------------------------------------------------------- |
| `yarn build`            | Compile all contracts.                                     |
| `yarn coverage`         | See `forge coverage` report.                               |
| `yarn deploy:arbitrum`  | Deploy the contracts to Arbitrum mainnet.                  |
| `yarn test`             | Run all unit and integration tests.                        |
| `yarn test:unit`        | Run unit tests.                                            |
| `yarn test:deep`        | Run unit tests with 5000 fuzz runs.                        |
| `yarn test:integration` | Run integration tests.                                     |

## Design

EBO uses [Prophet](https://docs.prophet.tech/). A versatile and fully adaptable optimistic oracle solution that allows users to set custom modules to achieve the functionality they need. It works by implementing multiple modules to get the resulting block in other chains for an epoch in the protocol chain.

### Modules

**RequestModule**

The custom EBORequestModule holds the parameters for the request. Including the epoch and the requested chain to fetch the data.

**ResponseModule**

EBO uses the [BondedResponseModule](https://github.com/defi-wonderland/prophet-modules/blob/dev/solidity/contracts/modules/response/BondedResponseModule.sol) built for Prophet which allows users to respond to a request by locking a bond.


**DisputeModule**

Prophet's [BondEscalationModule](https://github.com/defi-wonderland/prophet-modules/blob/dev/solidity/contracts/modules/dispute/BondEscalationModule.sol) is used to solve disputes by starting a bond escalation process.

**ResolutionModule**

[ArbitratorModule](https://github.com/defi-wonderland/prophet-modules/blob/dev/solidity/contracts/modules/resolution/ArbitratorModule.sol) allows an arbitrator appointed by The Graph's council to be the ultimate source of truth in case a dispute can't be closed by bond escalation.

**FinalityModule**

The new EBOFinalityModule emits events with the finalized data so it can be indexed by a subgraph.


### Periphery

**AccountingExtension**

Provides integration with The Graph's [Horizon Staking](https://thegraph.com/blog/graph-horizon/) contract for bonding tokens. 

**EBORequestCreator**

Simplifies request creation and validates requested data. 

> [!WARNING]  
> Only allows one pair of epoch-chainId request to be active at a time.  

**CouncilArbitrator**

Simplifies the interaction by The Graph's arbitrator with the ResolutionModule by doing multiple actions in one transaction.

### Flows

![Alt text](EBO_flows.png?raw=true)

## Setup

1. Install Foundry by following the instructions from [their repository](https://github.com/foundry-rs/foundry#installation).
2. Copy the `.env.example` file to `.env` and fill in the variables.
3. Install the dependencies by running: `yarn install`. In case there is an error with the commands, run `foundryup` and try them again.

## Build

The default way to build the code is suboptimal but fast, you can run it via:

```bash
yarn build
```

In order to build a more optimized code ([via IR](https://docs.soliditylang.org/en/v0.8.15/ir-breaking-changes.html#solidity-ir-based-codegen-changes)), run:

```bash
yarn build:optimized
```

## Running tests

Unit tests should be isolated from any externalities, while Integration usually run in a fork of the blockchain. In this boilerplate you will find example of both.

In order to run both unit and integration tests, run:

```bash
yarn test
```

In order to just run unit tests, run:

```bash
yarn test:unit
```

In order to run unit tests and run way more fuzzing than usual (5x), run:

```bash
yarn test:unit:deep
```

In order to just run integration tests, run:

```bash
yarn test:integration
```

In order to just run the echidna fuzzing campaign (requires [Echidna](https://github.com/crytic/building-secure-contracts/blob/master/program-analysis/echidna/introduction/installation.md) installed), run:

```bash
yarn test:fuzz
```

In order to just run the symbolic execution tests (requires [Halmos](https://github.com/a16z/halmos/blob/main/README.md#installation) installed), run:

```bash
yarn test:symbolic
```

In order to check your current code coverage, run:

```bash
yarn coverage
```

<br>

## Deploy & verify

### Setup

Configure the `.env` variables.

Import your private keys into Foundry's encrypted keystore:

```bash
cast wallet import $ARBITRUM_DEPLOYER_NAME --interactive
```

### Arbitrum

```bash
yarn deploy:arbitrum
```

The deployments are stored in ./broadcast

See the [Foundry Book for available options](https://book.getfoundry.sh/reference/forge/forge-create.html).

## Licensing
TODO

## Contributors

EBO was built with ❤️ by [Wonderland](https://defi.sucks).

Wonderland is a team of top Web3 researchers, developers, and operators who believe that the future needs to be open-source, permissionless, and decentralized.

[DeFi sucks](https://defi.sucks), but Wonderland is here to make it better.