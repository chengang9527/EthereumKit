/// Wallet handles all the logic necessary for storing keys
public final class Wallet {
    
    /// Network which this wallet is connecting to
    /// Basiclly Mainnet or Ropsten
    private let network: Network
    
    /// Private key which this wallet mainly use.
    /// This is either provided by user or generated from HD wallet.
    /// for HD wallet, path is m/44'/coin_type'/0'/0
    private let privateKey: PrivateKey
    
    /// Represents a flag whether to print a debug log.
    private let debugPrints: Bool
    
    public init(seed: Data, network: Network, debugPrints: Bool) throws {
        self.network = network
        self.debugPrints = debugPrints
        
        // m/44'/coin_type'/0'/external
        let externalPrivateKey = try HDPrivateKey(seed: seed, network: network)
            .derived(at: 44, hardens: true)
            .derived(at: network.coinType, hardens: true)
            .derived(at: 0, hardens: true)
            .derived(at: 0) // 0 for external
        
        privateKey = try externalPrivateKey
            .derived(at: 0)
            .privateKey()
        
        if debugPrints {
            printDebugInformation()
        }
    }
    
    public init(network: Network, privateKey: String, debugPrints: Bool) {
        self.network = network
        self.privateKey = PrivateKey(raw: Data(hex: privateKey))
        self.debugPrints = debugPrints
        
        if debugPrints {
            printDebugInformation()
        }
    }
    
    // MARK: - Public Methods
    
    /// Generates address from main private key.
    ///
    /// - Returns: Address in string format
    public func generateAddress() -> String {
        return privateKey.publicKey.generateAddress()
    }
    
    /// Reveal private key of this wallet in string format
    /// Be careful when calling this method.
    ///
    /// - Returns: Private key in string format
    public func dumpPrivateKey() -> String {
        return privateKey.raw.toHexString()
    }
    
    /// Sign signs rlp encoding hash of specified raw transaction
    ///
    /// - Parameter rawTransaction: raw transaction to hash
    /// - Returns: signiture in hex format
    /// - Throws: EthereumKitError.failedToEncode when failed to encode
    public func sign(rawTransaction: RawTransaction) throws -> String {
        let signer = EIP155Signer(chainID: network.chainID)
        let rawData = try signer.sign(rawTransaction, privateKey: privateKey)
        let hash = rawData.toHexString().addHexPrefix()
        if debugPrints {
            print(
                """
                \nSigning \(rawTransaction)
                Raw tx hash is \(hash) \n
                """
            )
        }
        return hash
    }
    
    /// Sign calculates an Ethereum ECDSA signature for: keccack256("\x19Ethereum Signed Message:\n" + len(message) + message))
    /// See also: https://github.com/ethereum/go-ethereum/wiki/Management-APIs#personal_sign
    ///
    /// - Parameter hex: message in hex format to sign
    /// - Returns: signiture in hex format
    /// - Throws: EthereumKitError.failedToEncode when failed to encode
    public func sign(hex: String) throws -> String {
        let prefix = "\u{19}Ethereum Signed Message:\n"
        
        let messageData = Data(hex: hex.stripHexPrefix())
        
        guard let prefixData = (prefix + String(messageData.count)).data(using: .ascii) else {
            throw EthereumKitError.cryptoError(.failedToEncode(prefix + String(messageData.count)))
        }
        
        let hash = Crypto.hashSHA3_256(prefixData + messageData)
        var signiture = try privateKey.sign(hash: hash)
        
        // Note, the produced signature conforms to the secp256k1 curve R, S and V values,
        // where the V value will be 27 or 28 for legacy reasons.
        signiture[64] += 27
        
        let signedHash = signiture.toHexString().addHexPrefix()
        if debugPrints {
            print(
                """
                \nSigning \(hex)
                Message hash is \(signedHash) \n
                """
            )
        }
        return signedHash
    }
    
    /// Sign calculates an Ethereum ECDSA signature for: keccack256("\x19Ethereum Signed Message:\n" + len(message) + message))
    /// See also: https://github.com/ethereum/go-ethereum/wiki/Management-APIs#personal_sign
    ///
    /// - Parameter hex: message to sign
    /// - Returns: signiture in hex format
    /// - Throws: EthereumKitError.failedToEncode when failed to encode
    public func sign(message: String) throws -> String {
        return try sign(hex: message.toHexString())
    }
    
    // MARK: - Private method
    
    private func printDebugInformation() {
        print(
            """
            \nUsing \(network) network
            PrivateKey is \(dumpPrivateKey())
            PublicKey is \(privateKey.publicKey.raw.toHexString())
            Address is \(generateAddress()) \n
            """
        )
    }
}
