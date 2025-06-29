# Stablecoin Project

A decentralized stablecoin implementation built with Solidity and Foundry,
featuring algorithmic stability mechanisms and exogenous crypto collateral.

## Overview

This project implements a stablecoin system with the following key
characteristics:

- **🎯 Relative Stability**: Pegged to the US Dollar using Chainlink Price Feeds
- **⚙️ Algorithmic Stability**: Decentralized minting and burning mechanism
- **🔒 Exogenous Collateral**: Backed by cryptocurrency assets (wETH, wBTC)

## Features

### Core Mechanisms

1. **Price Stability**
   - Chainlink Price Feeds integration for accurate USD pricing
   - Exchange functions for ETH & BTC to stablecoin conversion
2. **Collateral Management**
   - Over-collateralization requirement for minting
   - Support for Wrapped Ethereum (wETH)
   - Support for Wrapped Bitcoin (wBTC)
3. **Algorithmic Controls**
   - Automated minting based on collateral ratios
   - Burning mechanism to maintain peg stability
   - Liquidation system for under-collateralized positions

## Prerequisites

- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [Foundry](https://getfoundry.sh/)

## Installation

1. Clone the repository:

```bash
git clone <repository-url>
cd stablecoin
```

2. Install dependencies:

```bash
forge install
```

3. Build the project:

```bash
forge build
```

## Usage

### Testing

Run the test suite:

```bash
forge test
```

Run tests with verbosity:

```bash
forge test -vvv
```

### Deployment

Deploy to local network:

```bash
anvil
```

In a new terminal:

```bash
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --private-key <private-key> --broadcast
```

### Gas Snapshots

```bash
forge snapshot
```

### Format Code

```bash
forge fmt
```

## Architecture

```
src/
├── StableCoin.sol          # Main stablecoin contract
├── StableCoinEngine.sol    # Core stability mechanisms
├── libraries/
│   ├── OracleLib.sol       # Chainlink price feed integration
│   └── ReentrancyGuard.sol # Security implementations
└── interfaces/
    ├── IERC20.sol          # Token interface
    └── AggregatorV3Interface.sol # Chainlink interface
```

## Smart Contract Design

### Key Components

- **StableCoin**: ERC20 token implementation with mint/burn controls
- **StableCoinEngine**: Core logic for collateral management and stability
- **Price Oracles**: Chainlink integration for real-time price feeds
- **Collateral Tokens**: Support for wETH and wBTC as backing assets

### Security Features

- Reentrancy protection
- Access control mechanisms
- Liquidation safety checks
- Price feed validation

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Solidity style guide
- Ensure all tests pass
- Add tests for new features
- Update documentation as needed

## Testing

The project uses Foundry's testing framework with the following test categories:

- **Unit Tests**: Individual contract function testing
- **Integration Tests**: Multi-contract interaction testing
- **Fuzz Tests**: Property-based testing with random inputs
- **Invariant Tests**: System-wide property verification

## Deployment Networks

| Network          | Contract Address | Status         |
| ---------------- | ---------------- | -------------- |
| Ethereum Mainnet | TBD              | Planned        |
| Sepolia Testnet  | TBD              | In Development |
| Local (Anvil)    | Dynamic          | Development    |

## Risk Considerations

⚠️ **Important**: This is experimental software. Use at your own risk.

- Smart contract risk
- Collateral volatility risk
- Oracle failure risk
- Liquidation risk
- Regulatory risk

## Resources

- [Foundry Documentation](https://book.getfoundry.sh/)
- [Chainlink Price Feeds](https://docs.chain.link/data-feeds/price-feeds)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Ethereum Development](https://ethereum.org/en/developers/)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file
for details.

## Acknowledgments

- OpenZeppelin for security implementations
- Chainlink for price feed infrastructure
- Foundry team for the development framework
- Ethereum community for DeFi innovations

---

**⚠️ Disclaimer**: This software is provided "as is" without warranty. Always
perform due diligence and consider professional audit before production use.
