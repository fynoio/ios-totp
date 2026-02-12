# Fyno TOTP SDK – iOS (Swift) Technical Documentation

## Overview

The **Fyno TOTP SDK for iOS** provides secure Time-based One-Time Password (TOTP) generation and tenant management. It supports tenant enrollment, secure secret storage using the iOS Keychain, configurable TOTP parameters, and OTP generation compliant with **RFC 6238**.

**Module Name:** `FynoTOTP`  
**Minimum iOS Version:** iOS 13  
**Target iOS Version:** iOS 16+  
**Language:** Swift

---

## Table of Contents

1. Installation
2. Core Components
3. API Reference
4. Usage Examples
5. Data Models
6. Error Handling
7. Security Considerations

---

## Installation

### CocoaPods

Add the dependency to your `Podfile`:

```ruby
pod 'FynoTOTP'
```

Then run:

```bash
pod install
```

---

## Core Components

### FynoTOTP Class

The main entry point for all SDK operations.

**Responsibilities:**

- SDK initialization
- Tenant registration and revocation
- Secure secret storage using Keychain
- TOTP generation

**Initializer:**

```swift
let fynoTotp = FynoTOTP()
```

---

## API Reference

### initFynoConfig

Initializes the SDK with workspace and user identifiers.

```swift
func initFynoConfig(
    wsid: String,
    distinctId: String,
    completion: @escaping (Result<Void, Error>) -> Void
)
```

---

### registerTenant

Registers a tenant and securely stores the TOTP secret.

```swift
func registerTenant(
    tenantId: String,
    tenantLabel: String,
    totpToken: String,
    completion: @escaping (Result<Void, Error>) -> Void
)
```

---

### setConfig

Sets the TOTP configuration for a tenant.

```swift
func setConfig(
    tenantId: String,
    config: TotpConfig,
    completion: @escaping (Result<Void, Error>) -> Void
)
```

## fetchActiveTenants

Fetches the active tenants.

```swift

func fetchActiveTenants(
    completion: @escaping (Result<[ActiveTenant], Error>) -> Void
)
```


---

### getTotp

Generates and retrieves the current TOTP code.

```swift
func getTotp(
    tenantId: String,
    completion: @escaping (Result<String?, Error>) -> Void
)
```

---

### deleteTenantData

Deletes all tenant data and the stored secret.

```swift
func deleteTenantData(tenantId: String)
```

---

## Data Models

### TotpConfig

```swift
struct TotpConfig: Codable {
    let tenant_name: String
    let digits: Int
    let algorithm: String
    let period: Int
}
```

---

## Error Handling

### FynoError

```swift
enum FynoError: Error {
    case invalidSecret
    case invalidSecretEncoding
    case unsupportedAlgorithm
    case hashingFailed
    case base64DecodeFailed
    case secretDecodeFailed
}
```

---

## Security Considerations

- Secrets stored in iOS Keychain
- RFC 6238 compliant TOTP generation
- HMAC SHA1 / SHA256 / SHA512 support

---

## Changelog

### Version 1.0.0

- Initial iOS TOTP release
