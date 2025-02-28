# Mayan-swiftX

Mayan-swiftX is a custom swap order implementation built on top of the Mayan Swift protocol. This extension enables the following functionalities:

1. **Limit Orders**: Execute orders based on specified price targets.
2. **Conditional Orders**: Execute orders based on predefined conditions.
3. **Recurring Cross-Chain Swaps**: Facilitate automated swaps across different blockchains at regular intervals.

With Mayan-swiftX, users can enhance their trading strategies by leveraging these advanced order types, providing greater flexibility and control over their transactions.

## How It Works

1. A user signs a custom ERC20 order and sends it to the Searchbox API.
2. Anyone can call this API to retrieve the order or orders to validate and create on Mayan Swift.
3. The executor is paid, and the user receives the requested tokens.