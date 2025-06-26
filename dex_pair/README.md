## DEX AMM (Automated Market Maker) on Stacks Blockchain

This project implements a simple decentralized exchange smart contract with an automated market maker (AMM) model on the Stacks blockchain using Clarity.

### 🧱 Features
- Liquidity provision for two SIP-010 compliant tokens
- Swapping from Token A to Token B
- Reserve tracking and liquidity share calculation

### 📦 Requirements
- [Clarinet](https://docs.hiro.so/clarinet/get-started)
- Node.js (for testing with Clarinet + TypeScript)

### 🚀 Project Setup
```bash
clarinet check       # Syntax & type checking
clarinet console     # Run REPL for smart contract
clarinet test        # Run tests (ensure TypeScript tests are written)
```

### 🔍 Files Structure
```
contracts/
  dex-amm.clar       # Main Clarity smart contract

Clarinet.toml        # Project metadata
README.md            # This guide
```

### 🔧 Deployment
Use Clarinet devnet to deploy:
```bash
clarinet deploy
