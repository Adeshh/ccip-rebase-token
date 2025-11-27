# CCIP Rebase Token

A cross-chain rebase token implementation using Chainlink CCIP (Cross-Chain Interoperability Protocol) that incentivizes users to deposit ETH in a vault for interest/rewards. The token accrues linear interest over time, and users can bridge their tokens across chains while preserving their interest rate.

## 🚀 Features

- **Rebase Token with Interest**: Tokens accrue linear interest over time based on a user-specific interest rate
- **Cross-Chain Bridging**: Bridge tokens between chains (e.g., Sepolia ↔ Arbitrum Sepolia) using Chainlink CCIP
- **Interest Rate Preservation**: When bridging, users maintain their original interest rate from the source chain
- **Decreasing Global Interest Rate**: The protocol rewards early users with higher interest rates
- **Vault Integration**: Deposit ETH to receive rebase tokens, redeem tokens to withdraw ETH

## 📋 Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (latest version)
- [Git](https://git-scm.com/)
- Access to RPC endpoints for Sepolia and Arbitrum Sepolia (for testing)

## 🛠️ Installation

1. Clone the repository:
```bash
git clone git@github.com:Adeshh/ccip-rebase-token.git
cd ccip-rebase-token
```

2. Install dependencies:
```bash
forge install
```

3. Build the project:
```bash
forge build
```

## 📁 Project Structure

```
ccip-rebase-token/
├── src/
│   ├── RebaseToken.sol          # Main rebase token contract with interest accrual
│   ├── RebaseTokenPool.sol       # CCIP token pool for cross-chain bridging
│   ├── Vault.sol                 # Vault contract for ETH deposits/redemptions
│   └── interfaces/
│       └── IRebaseToken.sol      # Interface for RebaseToken
├── test/
│   ├── RebaseToken.t.sol         # Unit tests for RebaseToken
│   └── CrossChain.t.sol          # Cross-chain integration tests
├── script/
│   ├── Deployer.s.sol            # Deployment scripts
│   ├── ConfigurePool.s.sol       # Pool configuration scripts
│   ├── BridgeTokens.s.sol        # Token bridging scripts
│   └── Interactions.s.sol        # Interaction scripts
└── lib/                          # Dependencies (CCIP, OpenZeppelin, Chainlink Local)
```

## 🎯 Key Concepts

### Interest Rate System

- **Global Interest Rate**: Starts at `5e10` per second and can only decrease
- **User Interest Rate**: Set when a user first receives tokens (via deposit or transfer)
- **Linear Interest**: Interest accrues linearly over time: `balance = principle * (1 + rate * time)`
- **Interest Preservation**: When bridging, the user's interest rate is preserved and sent to the destination chain

### Cross-Chain Bridging

- **Lock & Burn**: On the source chain, tokens are burned and the user's interest rate is encoded in `destPoolData`
- **Release & Mint**: On the destination chain, tokens are minted with the preserved interest rate
- **CCIP Integration**: Uses Chainlink CCIP for secure, verified cross-chain messaging

## 🧪 Testing

### Run All Tests

```bash
forge test
```

### Run Specific Test Suites

```bash
# Unit tests only
forge test --match-contract RebaseTokenTest

# Cross-chain tests only
forge test --match-contract CrossChainTest
```

### Cross-Chain Testing Setup

Cross-chain tests require RPC access to Sepolia and Arbitrum Sepolia networks. Configure RPC URLs in `foundry.toml` or use environment variables:

```bash
export SEPOLIA_RPC_URL="your-sepolia-rpc-url"
export ARB_SEPOLIA_RPC_URL="your-arbitrum-sepolia-rpc-url"
forge test --match-test testBridgeAllTokens
```

**Recommended RPC Providers:**
- [Alchemy](https://www.alchemy.com/) (free tier available)
- [Infura](https://www.infura.io/) (free tier available)
- [QuickNode](https://www.quicknode.com/) (free tier available)

### Test Coverage

```bash
forge coverage
```

## 📝 Usage Examples

### Deposit ETH and Receive Tokens

```solidity
// User deposits ETH into vault
vault.deposit{value: 1 ether}();

// User receives rebase tokens with current global interest rate
uint256 balance = rebaseToken.balanceOf(user);
uint256 interestRate = rebaseToken.getUserIntrestRate(user);
```

### Bridge Tokens Cross-Chain

```solidity
// Approve router to spend tokens
IERC20(token).approve(routerAddress, amount);

// Create CCIP message
Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
    receiver: abi.encode(user),
    data: "",
    tokenAmounts: tokenAmounts,
    feeToken: linkAddress,
    extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 300_000}))
});

// Send cross-chain message
IRouterClient(routerAddress).ccipSend(destinationChainSelector, message);
```

### Redeem Tokens for ETH

```solidity
// Redeem all tokens
vault.redeem(type(uint256).max);

// Or redeem specific amount
vault.redeem(amount);
```

## 🚀 Deployment

### Deploy to Local Network

1. Start a local Anvil node:
```bash
anvil
```

2. Deploy contracts:
```bash
forge script script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url http://localhost:8545 --broadcast
```

### Deploy to Testnet

1. Set up environment variables:
```bash
export PRIVATE_KEY="your-private-key"
export SEPOLIA_RPC_URL="your-sepolia-rpc-url"
export ARB_SEPOLIA_RPC_URL="your-arbitrum-sepolia-rpc-url"
```

2. Deploy to Sepolia:
```bash
forge script script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

3. Configure pools for cross-chain:
```bash
forge script script/ConfigurePool.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast
```

## 🔐 Security Considerations

- **Access Control**: Only authorized addresses (with `MINT_AND_BURN_ROLE`) can mint/burn tokens
- **Interest Rate**: Global interest rate can only decrease, preventing manipulation
- **CCIP Security**: Leverages Chainlink's battle-tested CCIP protocol for cross-chain messaging
- **Rate Limiting**: Token pools support rate limiting for additional security

## 📚 Contract Details

### RebaseToken

- **Inherits**: `ERC20`, `Ownable`, `AccessControl`
- **Key Functions**:
  - `mint()`: Mint tokens with a specific interest rate
  - `burn()`: Burn tokens from a user
  - `balanceOf()`: Get balance including accrued interest
  - `principleBalanceOf()`: Get balance without interest
  - `getUserIntrestRate()`: Get user's interest rate
  - `setIntrestRate()`: Owner can decrease global interest rate

### RebaseTokenPool

- **Inherits**: `TokenPool` (CCIP)
- **Key Functions**:
  - `lockOrBurn()`: Burn tokens and encode interest rate for cross-chain transfer
  - `releaseOrMint()`: Mint tokens on destination chain with preserved interest rate

### Vault

- **Key Functions**:
  - `deposit()`: Deposit ETH and receive rebase tokens
  - `redeem()`: Redeem rebase tokens for ETH

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- [Chainlink CCIP](https://chain.link/cross-chain) for cross-chain infrastructure
- [OpenZeppelin](https://openzeppelin.com/) for secure contract libraries
- [Foundry](https://book.getfoundry.sh/) for the development framework

## 📞 Contact

- Author: [@Adeshh](https://github.com/Adeshh)
- Repository: [ccip-rebase-token](https://github.com/Adeshh/ccip-rebase-token)
