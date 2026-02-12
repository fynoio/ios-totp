import Foundation
import CryptoKit
import CommonCrypto

@available(iOS 13.0, *)
public class FynoTOTP {
    private let keyStorage: KeyStorage
    private let dbHelper: DatabaseHelper
    private let STATUS_ACTIVE = 1
    private let STATUS_INACTIVE = 0
    
    public init() {
        self.dbHelper = try! DatabaseHelper()
        self.keyStorage = KeyStorage()
    }
    
    // MARK: - Init Fyno config
    
    public func initFynoConfig(wsid: String, distinctId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let uuid = self.getDeviceUuid()
                try self.dbHelper.initFynoConfig(wsid: wsid, distinctId: distinctId, uuid: uuid)
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    private func getDeviceUuid() -> String {
        if let uuid = dbHelper.getDeviceUuid() {
            return uuid
        } else {
            let newUUID = UUID().uuidString
            // store it (initFynoConfig expects to be called to persist) — not storing here directly
            return newUUID
        }
    }
    
    
    // MARK: - Tenant register & config
    
    public func registerTenant(tenantId: String, tenantLabel: String, totpToken: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.dbHelper.registerTenant(tenantId: tenantId, tenantLabel: tenantLabel)
                try self.setKeySync(tenantId: tenantId, totpToken: totpToken, status: self.STATUS_ACTIVE)
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    public func setConfig(tenantId: String, config: TotpConfig, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(config)
                let json = String(data: data, encoding: .utf8) ?? "{}"
                try self.dbHelper.setConfig(tenantId: tenantId, configJson: json)
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    public func deleteTenantData(tenantId: String) {
        // Delete DB rows
        dbHelper.deleteTenant(tenantId: tenantId)
        
        // Delete Keychain secret
        keyStorage.deleteSecret(alias: tenantId)
    }
    
    // MARK: - Key Storage (synchronous internal helper)
    
    private func setKeySync(tenantId: String, totpToken: String, status: Int) throws {
        let alias = tenantId // KeyStorage builds full alias
        guard let secretData = totpToken.data(using: .utf8) else { throw FynoError.invalidSecret }
        try keyStorage.storeSecret(alias: alias, secret: secretData)
        // store alias in DB so DB still references where to find the secret
        try dbHelper.setKey(tenantId: tenantId, secretAlias: "fyno_totp_secret_\(alias)", iv: nil, status: status)
    }
    
    // MARK: - Get TOTP
    
    public func getTotp(tenantId: String, completion: @escaping (Result<String?, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let totpData = try self.dbHelper.getTotpData(tenantId: tenantId) else {
                    DispatchQueue.main.async { completion(.success(nil)) }
                    return
                }
                if totpData.status != self.STATUS_ACTIVE {
                    DispatchQueue.main.async { completion(.success(nil)) }
                    return
                }
                // alias stored in DB includes fyno_totp_secret_ prefix (we saved like that)
                // we need the tenant id part to pass to KeyStorage which will add prefix again -> KeyStorage uses fyno_totp_secret_<alias>
                // To avoid double prefixing, our DB stored alias equals actual key in Keychain, so we strip prefix when calling retrieveSecret.
                let storedAlias = totpData.encryptedSecretAlias // e.g. "fyno_totp_secret_tenantId"
                let aliasToUse: String
                if storedAlias.hasPrefix("fyno_totp_secret_") {
                    aliasToUse = String(storedAlias.dropFirst("fyno_totp_secret_".count))
                } else {
                    aliasToUse = storedAlias
                }
                let secretData = try self.keyStorage.retrieveSecret(alias: aliasToUse)
                guard let secretString = String(data: secretData, encoding: .utf8) else {
                    throw FynoError.invalidSecretEncoding
                }
                
                let config = totpData.config
                
                let otp = try self.generateTOTP(secret: Array(secretString.utf8),
                                                digits: config.digits,
                                                algorithm: config.algorithm,
                                                period: config.period)
                DispatchQueue.main.async { completion(.success(otp)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    // MARK: - TOTP generation
    
    /// secret bytes, digits, algorithm: "SHA1", "SHA256", "SHA512", period (seconds)
    private func generateTOTP(secret: [UInt8], digits: Int, algorithm: String, period: Int) throws -> String {
        let time = UInt64(Date().timeIntervalSince1970)
        let counter = time / UInt64(period)
        var counterBe = counter.bigEndian
        let counterData = withUnsafeBytes(of: &counterBe) { Data($0) } // 8 bytes BE
        
        let hash: [UInt8]
        switch algorithm.uppercased() {
        case "SHA1":
            hash = hmacSHA1(key: secret, message: [UInt8](counterData))
        case "SHA256":
            hash = hmacCryptoKitSHA256(key: secret, message: [UInt8](counterData))
        case "SHA512":
            hash = hmacCryptoKitSHA512(key: secret, message: [UInt8](counterData))
        default:
            throw FynoError.unsupportedAlgorithm
        }
        
        // dynamic truncation
        guard let offset = hash.last.map({ Int($0 & 0x0f) }) else { throw FynoError.hashingFailed }
        let slice = Array(hash[offset..<(offset+4)])
        var truncated: UInt32 = 0
        truncated |= UInt32(slice[0]) << 24
        truncated |= UInt32(slice[1]) << 16
        truncated |= UInt32(slice[2]) << 8
        truncated |= UInt32(slice[3])
        truncated = truncated & 0x7fffffff
        let mod = UInt32(pow(10.0, Double(digits)))
        let otp = Int(truncated % mod)
        return String(format: "%0\(digits)d", otp)
    }
    
    // MARK: - HMAC helpers
    
    private func hmacSHA1(key: [UInt8], message: [UInt8]) -> [UInt8] {
        var mac = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        key.withUnsafeBytes { keyBuf in
            message.withUnsafeBytes { msgBuf in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1),
                       keyBuf.baseAddress, key.count,
                       msgBuf.baseAddress, message.count,
                       &mac)
            }
        }
        return mac
    }
    
    private func hmacCryptoKitSHA256(key: [UInt8], message: [UInt8]) -> [UInt8] {
        let k = SymmetricKey(data: Data(key))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(message), using: k)
        return Array(mac)
    }
    
    private func hmacCryptoKitSHA512(key: [UInt8], message: [UInt8]) -> [UInt8] {
        let k = SymmetricKey(data: Data(key))
        let mac = HMAC<SHA512>.authenticationCode(for: Data(message), using: k)
        return Array(mac)
    }
    
    // MARK: - Fetch Active Tenants
    public func fetchActiveTenants(completion: @escaping (Result<[ActiveTenant], Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let tenants = self.dbHelper.getActiveTenants()
            DispatchQueue.main.async {
                completion(.success(tenants))
            }
        }
    }
}

public enum FynoError: Error {
    case invalidSecret
    case invalidSecretEncoding
    case unsupportedAlgorithm
    case hashingFailed
    case base64DecodeFailed
    case secretDecodeFailed
}
