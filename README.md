# 🛒 MarketBTC – Bitcoin-Native Decentralized Marketplace

## Overview

**MarketBTC** is a decentralized marketplace protocol built on the [Stacks blockchain](https://www.stacks.co), enabling direct peer-to-peer commerce with **Bitcoin settlement**. It supports **brand registration**, **product listings**, **auctions**, and **trust-based reviews**, all powered by **Clarity smart contracts**. The system leverages Stacks' ability to settle transactions on Bitcoin, delivering the security of BTC with the programmability of Clarity.

---

## ✨ Key Features

* **Bitcoin-Native Settlement**: All transactions settle through the Stacks protocol directly onto Bitcoin.
* **Direct Sales & Auctions**: Flexible commerce with support for fixed-price products and time-limited auctions.
* **Brand System**: Merchants register brands with optional verification by contract owner.
* **Reputation via Reviews**: Buyers can leave reviews to build brand and product reputation.
* **Platform Fees & Escrow**: Transparent 2.5% fee system with escrowed auction logic for secure settlement.
* **Completely Trustless**: No third-party custodians or centralized controls required.

---

## 📦 System Architecture

```
 +------------------------+
 |   Users (Buyers/Sellers)  |
 +------------------------+
              |
              v
 +------------------------+
 |  MarketBTC Smart Contract |
 |    (Deployed on Stacks)   |
 +------------------------+
              |
              v
 +------------------------+
 |     Stacks Blockchain     |
 |  (Bitcoin settlement layer)|
 +------------------------+
              |
              v
 +------------------------+
 |     Bitcoin Blockchain     |
 +------------------------+
```

---

## 🔩 Contract Architecture

### Constants

* **Contract Ownership**: Immutable `contract-owner` (set to deployer)
* **Platform Fee**: Configured at `2.5%` (represented as `u25 / 1000`)
* **Error Codes**: Used for consistent and meaningful failure handling (e.g., `err-not-brand-owner`, `err-auction-ended`)

### State Variables

* `platform-fee`: Fee taken by the contract owner on each transaction.
* `product-counter`: Autoincrementing product ID for tracking listings.

### Data Maps

| Map        | Description                                  |
| ---------- | -------------------------------------------- |
| `Brands`   | Registered merchant brands                   |
| `Products` | All product listings (direct + auction)      |
| `Auctions` | Auction metadata and state                   |
| `Reviews`  | Buyer reviews, indexed by product & reviewer |

---

## 🔁 Functional Overview

### ✅ Brand Management

* `register-brand`: Allows any user to register a brand.
* `verify-brand`: Contract owner can verify brands for trust signaling.

### 📋 Product Listings

* `list-product`: Direct sale product listing (price, name, description).
* `purchase-product`: Buyer purchases directly with STX → BTC settlement.

### ⏱️ Auctions

* `create-auction`: List product for auction with min-price & duration.
* `place-bid`: Submit a bid higher than previous with STX held in escrow.
* `end-auction`: Finalizes auction, transferring STX to seller minus fee.

### 🌟 Review System

* `add-review`: Buyer adds rating (1–5) and comment post-purchase.

---

## 🔍 Read-Only Functions

| Function      | Purpose                                    |
| ------------- | ------------------------------------------ |
| `get-product` | Fetch product metadata by ID               |
| `get-brand`   | View brand info (name, verification, etc.) |
| `get-auction` | View auction state (highest bid, end time) |
| `get-review`  | Fetch review by product and reviewer       |

---

## 🔄 Data Flow Summary

### Direct Sale

```plaintext
1. Seller → list-product → Products[product-id]
2. Buyer → purchase-product → STX transferred
    - Fee → contract-owner
    - Remainder → seller (brand)
    - Product marked unavailable
```

### Auction

```plaintext
1. Seller → create-auction → Products & Auctions entries created
2. Bidders → place-bid:
    - Old highest bid refunded
    - New bid escrowed
3. Seller (or anyone) → end-auction:
    - Winning bid distributed:
        - Fee → contract-owner
        - Remainder → seller
    - Product marked unavailable
    - Auction marked inactive
```

---

## 🛡️ Security Considerations

* **Escrow Logic**: Ensures highest bid is always returned to the previous bidder to avoid STX loss.
* **Permissioned Actions**: Only contract-owner can verify brands.
* **Balance Checks**: Validates STX balance before all transfers.
* **Input Sanitization**: Prevents abuse with whitespace/empty values.

---

## 🔧 Future Extensions (Ideas)

* NFT integration for unique items
* On-chain brand reputation scoring
* Marketplace governance (DAO)
* Dispute resolution via smart contract arbitration
* Multi-currency support (via SIP-010 tokens)

---

## 🛠 Deployment

* **Stacks Chain Compatibility**: Requires Stacks 2.1 or later.
* **Recommended Deployment**: Via Clarinet, Hiro Wallet, or contract deploy CLI.
* **Contract Initialization**: Deployer becomes `contract-owner` automatically.

---

## 📜 License

[MIT License](LICENSE)
