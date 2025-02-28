# Mayan-swiftX

Mayan-swiftX is a custom swap order implementation built on top of the Mayan Swift protocol. This extension enables the following functionalities:

1. **Limit Orders**: Execute orders based on specified price targets.
2. **Conditional Orders**: Execute orders based on predefined conditions.
3. **Recurring Cross-Chain Swaps**: Facilitate automated swaps across different blockchains at regular intervals.

With Mayan-swiftX, users can enhance their trading strategies by leveraging these advanced order types, providing greater flexibility and control over their transactions.

## How It Works (Users)

1. A user signs a custom ERC20 order and sends it to the Searchbox API.
2. Anyone can call this API to retrieve the order or orders, validate them, and create them on Mayan Swift.
3. The executor is compensated, and the user receives the requested tokens.

## How It Works (Developers)

1. A developer integrates the Searchbox API, takes the user's input parameters, and may specify one or more executors. They then build an order and call the `createAndPublish` function.
2. It is the responsibility of the specified executor to execute the order on Mayan Swift.