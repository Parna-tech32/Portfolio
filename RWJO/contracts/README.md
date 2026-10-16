## Foundry

# RWJO — Reputation-Weighted Jury Oracle

**A decentralized oracle framework for reliable price verification, anomaly detection, and dispute resolution.**

RWJO (Reputation-Weighted Jury Oracle) is a blockchain-based system designed to improve the reliability of price data used by decentralized applications. It combines multi-layer validation, reputation-weighted jury decisions, and dispute resolution to help identify suspicious or unreliable price submissions.

## Overview

Decentralized applications such as lending protocols rely on accurate price information. Incorrect or manipulated prices can cause liquidations, financial losses, and protocol instability.

RWJO addresses this challenge through a layered verification process that evaluates incoming price data and escalates suspicious cases for additional verification.

### Key Features

- **Multi-layer verification:** Processes price submissions through multiple validation stages.
- **Source reliability:** Evaluates the reliability of incoming data sources.
- **Tiered response mechanism:** Applies different levels of scrutiny depending on the detected risk.
- **Reputation-weighted jury:** Uses juror reputation to influence dispute decisions.
- **Dispute resolution:** Supports handling and resolving contested price submissions.
- **Smart contract testing:** Includes Solidity tests for core contract functionality.
- **Interactive frontend:** Provides a dashboard for exploring oracle activity and system status.
- **Development and demo tools:** Includes supporting backend and demonstration components.

## Architecture

RWJO is organized into three major layers:

1. **Layer 1 — Source Reliability:** Evaluates incoming data and source reliability.
2. **Layer 2 — Tiered Response:** Applies increasingly strict verification when suspicious behavior is detected.
3. **Layer 3 — RWJO Dispute Resolution:** Handles disputes and jury-based resolution.

The frontend and supporting backend provide an interface for interacting with and demonstrating the system.

## Technology Stack

| Component | Technologies |
|---|---|
| Smart contracts | Solidity |
| Contract development and testing | Foundry, Forge |
| Blockchain integration | Ethereum-compatible tooling |
| Frontend | HTML, CSS, JavaScript, Vue.js |
| Backend | Python, Flask |
| Oracle-related tooling | Chainlink VRF integration |
| Version control | Git, GitHub |

## Project Structure

```text
RWJO/
├── contracts/          # Smart contracts and Foundry tests
│   ├── script/         # Deployment scripts
│   ├── src/            # Contract source code
│   └── test/           # Solidity tests
├── frontend/           # Main dashboard frontend
├── cryptics/
│   ├── backend/        # Supporting backend
│   ├── demo/           # Demonstration resources
│   └── frontend/       # Additional project interface
└── README.md
```

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/Parna-tech32/Portfolio.git
cd Portfolio/RWJO
```

### 2. Set up the smart contracts

Install [Foundry](https://getfoundry.sh/) if it is not already installed.

```bash
cd contracts
forge install
forge build
forge test
```

If dependencies are already configured, review the project's existing Foundry configuration and dependency setup before running these commands.

### 3. Run the frontend

For the standalone frontend, inspect its `package.json` to determine the required commands. For a Vite-based frontend, the usual workflow is:

```bash
cd ../frontend
npm install
npm run dev
```

### 4. Configure the backend

The backend under `cryptics/backend/` may require Python dependencies and environment variables. Follow its own setup instructions and keep private keys, API keys, and other secrets out of GitHub.

## Testing

The smart contracts include Foundry test files for checking contract behavior and interactions.

Run the test suite from the contracts directory:

```bash
forge test -vv
```

Additional test scenarios can cover source reliability, tiered responses, dispute resolution, and jury decisions.

## Security Considerations

- Never commit private keys, seed phrases, API keys, or production credentials.
- Store sensitive configuration in environment variables.
- Test contracts locally before deploying them to a public network.
- Review contract permissions, oracle assumptions, and dispute-resolution edge cases before production use.

## Project Goal

RWJO explores how reputation, layered validation, and dispute resolution can work together to make blockchain oracle systems more robust against unreliable or manipulated data.

**Project category:** Blockchain · Smart Contracts · Decentralized Oracles · Web3 Security

---

*Developed as a blockchain engineering project exploring oracle reliability and decentralized dispute resolution.*
**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
