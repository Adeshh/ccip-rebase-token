# CCIP Rebase Token

## Running Tests

### Cross-Chain Tests

Cross-chain tests require RPC access to Sepolia and Arbitrum Sepolia networks. If you encounter RPC timeout errors, you can set custom RPC URLs using environment variables:

```bash
export SEPOLIA_RPC_URL="your-sepolia-rpc-url"
export ARB_SEPOLIA_RPC_URL="your-arbitrum-sepolia-rpc-url"
forge test --match-test testBridgeAllTokens
```

Or set them inline:
```bash
SEPOLIA_RPC_URL="your-url" ARB_SEPOLIA_RPC_URL="your-url" forge test --match-test testBridgeAllTokens
```

### Recommended RPC Providers

- **Alchemy**: https://www.alchemy.com/ (free tier available)
- **Infura**: https://www.infura.io/ (free tier available)
- **QuickNode**: https://www.quicknode.com/ (free tier available)

### Public RPC Endpoints (may have rate limits)

The default configuration uses public RPC endpoints which may timeout on free tiers. Consider using a paid RPC service for reliable testing.

