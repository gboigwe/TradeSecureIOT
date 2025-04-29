# TradeSecure: Automated Escrow for Physical Goods

A decentralized escrow platform built on the Stacks blockchain that secures e-commerce transactions involving physical goods through IoT verification and Bitcoin settlement security.

![TradeSecure Logo](https://example.com/tradesecure-logo.png)

## Overview

TradeSecure enables secure transactions between buyers and sellers of physical goods by leveraging blockchain technology and IoT device verification. The platform resolves the trust issues in online marketplaces by providing:

- **Multi-stage escrow** holding funds until delivery conditions are met
- **IoT verification** of physical delivery through trusted devices
- **Dispute resolution** with decentralized arbitration
- **Bitcoin settlement** security through Stacks blockchain integration

Unlike traditional escrow services, TradeSecure is fully decentralized, transparent, and offers automated verification of real-world delivery events.

## Core Features

### For Buyers
- Secure payment holding until goods are verifiably delivered
- IoT-verified proof of delivery
- Protection against fraudulent sellers
- Efficient dispute resolution if issues arise

### For Sellers
- Guaranteed payment upon verified delivery
- Reduced chargeback fraud
- Transparent shipping verification
- Reputation building on a trusted platform

### Technical Highlights
- Smart contracts written in Clarity on Stacks blockchain
- IoT device integration for package tracking and verification
- Bitcoin-level security for transaction settlement
- Decentralized dispute resolution system

## Smart Contract Architecture

The system is composed of several interoperating smart contracts:

1. **Escrow Contract (`escrow-contract.clar`)**
   - Core funds management and escrow logic
   - Multi-stage release with verification triggers
   - Support for STX and SIP-010 tokens

2. **Verification Oracle (`verification-oracle.clar`)**
   - Interfaces with IoT devices for delivery verification
   - Manages trusted oracle network
   - Validates real-world delivery events

3. **Device Registry (`device-registry.clar`)**
   - Manages approved IoT devices and manufacturers
   - Ensures device authenticity and trusted data
   - Handles firmware and capability verification

4. **Dispute Resolution (`dispute-resolution.clar`)**
   - Handles conflicts between buyers and sellers
   - Manages arbitration processes
   - Implements voting mechanisms for resolution

5. **Main Contract (`tradesecure-main.clar`)**
   - Central hub connecting all platform components
   - User profile management
   - Transaction template management

## Installation and Setup

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) - Stacks blockchain development environment
- [Node.js](https://nodejs.org) (v14 or higher)
- [Stacks Wallet](https://www.hiro.so/wallet) for interacting with the live platform

### Development Environment Setup

1. Clone the repository
```bash
git clone https://github.com/your-username/tradesecure.git
cd tradesecure
```

2. Install dependencies
```bash
npm install
```

3. Start the local Clarinet development chain
```bash
clarinet integrate
```

4. Deploy contracts to local development chain
```bash
clarinet deploy
```

### Frontend Development

1. Start the development server
```bash
npm run dev
```

2. Build for production
```bash
npm run build
```

## Usage Guide

### Creating an Escrow Transaction

1. **Select a Transaction Template**
   - Choose from predefined templates or create custom escrow terms
   - Set shipping timeframes and required verification types

2. **Set Up Transaction Details**
   - Specify buyer and seller addresses
   - Set transaction amount and payment token
   - Add metadata about the goods being transacted

3. **Fund the Escrow**
   - Buyer deposits funds into the escrow contract
   - Funds are locked until delivery conditions are met

4. **Track Shipping Status**
   - Seller marks package as shipped
   - IoT devices track package in transit
   - Real-time verification data is recorded on-chain

5. **Verify Delivery**
   - IoT devices confirm delivery to specified location
   - Multiple verification types ensure delivery accuracy
   - Smart contract processes verification data

6. **Complete Transaction**
   - Upon successful verification, funds are released to seller
   - Transaction is recorded as completed
   - Reputation scores are updated for both parties

### Dispute Resolution Process

If issues arise during the transaction:

1. Either party can initiate a dispute with supporting evidence
2. Dispute enters evidence gathering phase
3. Qualified arbiters review evidence and vote on resolution
4. Funds are distributed according to arbitration outcome

## IoT Integration

TradeSecure supports several types of IoT devices for verification:

- **NFC Tags**: For package authentication
- **GPS Trackers**: For location verification
- **Environmental Sensors**: For condition-sensitive goods
- **QR Code Scanners**: For delivery confirmation

Device manufacturers can register with the platform to become trusted verification sources.

## Contract Addresses (Testnet)

- Main Contract: `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.tradesecure-main`
- Escrow Contract: `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.escrow-contract`
- Verification Oracle: `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.verification-oracle`
- Device Registry: `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.device-registry`
- Dispute Resolution: `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.dispute-resolution`

## Bitcoin Integration Strategy

TradeSecure leverages Stacks' unique connection to Bitcoin to provide:

1. **Settlement Security**: Final settlement anchored to Bitcoin's security
2. **Collateral Options**: Allow Bitcoin to be used as transaction collateral
3. **Value Stability**: Option to lock transaction value in BTC to mitigate volatility
4. **Proof of Transfer**: Utilize Stacks' PoX mechanism for enhanced security

## Security Considerations

The TradeSecure platform incorporates multiple security measures:

- **Multi-signature Controls**: For high-value transactions
- **Timelock Mechanisms**: Automatic resolution after timeout periods
- **Verification Thresholds**: Multiple confirmations required for fund release
- **Oracle Network Consensus**: Distributed verification to prevent tampering
- **Firmware Verification**: Ensures IoT devices run authentic software

## Contributing

We welcome contributions to the TradeSecure platform:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please read our [Contributing Guide](CONTRIBUTING.md) for details on our code of conduct and development process.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact and Support

- Website: [tradesecure.io](https://tradesecure.io)
- Email: support@tradesecure.io
- Twitter: [@TradeSecure](https://twitter.com/TradeSecure)
- Discord: [TradeSecure Community](https://discord.gg/tradesecure)

## Acknowledgments

- [Stacks Foundation](https://stacks.org) for their support
- [Clarity Language](https://clarity-lang.org) documentation and community
- All early testers and contributors
