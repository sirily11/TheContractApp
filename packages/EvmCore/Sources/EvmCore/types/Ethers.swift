import BigInt
import Foundation

public struct Ethers: Equatable, Hashable, Codable {
    public let value: BigInt

    private static let weiPerEther = BigInt(10).power(18)
    private static let gweiPerEther = BigInt(10).power(9)

    /**
    * @param value - The value to convert to Ethers
    * @returns The Ethers value. For example 1 ether is 0x1
    */
    public init(hex value: String) {
        let cleanHex = value.hasPrefix("0x") ? String(value.dropFirst(2)) : value
        self.value = BigInt(cleanHex, radix: 16) ?? 0
    }

    public init(bigInt value: BigInt) {
        self.value = value
    }

    public init(float value: Double) {
        self.value = BigInt(value)
    }

    public init(wei value: Wei) {
        self.value = value.value / Ethers.weiPerEther
    }

    public init(gwei value: Gwei) {
        self.value = value.value / Ethers.gweiPerEther
    }

    public func toWei() -> Wei {
        return Wei(bigInt: value * Ethers.weiPerEther)
    }

    public func toGwei() -> Gwei {
        return Gwei(bigInt: value * Ethers.gweiPerEther)
    }
}

public struct Wei: Equatable, Hashable, Codable {
    public let value: BigInt

    private static let weiPerEther = BigInt(10).power(18)
    private static let weiPerGwei = BigInt(10).power(9)

    public init(hex value: String) {
        let cleanHex = value.hasPrefix("0x") ? String(value.dropFirst(2)) : value
        self.value = BigInt(cleanHex, radix: 16) ?? 0
    }

    public init(bigInt value: BigInt) {
        self.value = value
    }

    public func toEthers() -> Ethers {
        return Ethers(bigInt: value / Wei.weiPerEther)
    }

    public func toGwei() -> Gwei {
        return Gwei(bigInt: value / Wei.weiPerGwei)
    }
}

public struct Gwei: Equatable, Hashable, Codable {
    public let value: BigInt

    private static let weiPerGwei = BigInt(10).power(9)
    private static let gweiPerEther = BigInt(10).power(9)

    /**
     * Initialize from a hex string value
     * @param value - The hex value (with or without 0x prefix)
     */
    public init(hex value: String) {
        let cleanHex = value.hasPrefix("0x") ? String(value.dropFirst(2)) : value
        self.value = BigInt(cleanHex, radix: 16) ?? 0
    }

    public init(bigInt value: BigInt) {
        self.value = value
    }

    public init(float value: Double) {
        self.value = BigInt(value)
    }

    public init(wei value: Wei) {
        self.value = value.value / Gwei.weiPerGwei
    }

    public init(ethers value: Ethers) {
        self.value = value.value * Gwei.gweiPerEther
    }

    public func toWei() -> Wei {
        return Wei(bigInt: value * Gwei.weiPerGwei)
    }

    public func toEthers() -> Ethers {
        return Ethers(bigInt: value / Gwei.gweiPerEther)
    }
}

public struct GasLimit: Equatable, Hashable, Codable {
    public let value: BigInt

    /**
     * Initialize from a hex string value
     * @param value - The hex value (with or without 0x prefix)
     */
    public init(hex value: String) {
        let cleanHex = value.hasPrefix("0x") ? String(value.dropFirst(2)) : value
        self.value = BigInt(cleanHex, radix: 16) ?? 0
    }

    public init(bigInt value: BigInt) {
        self.value = value
    }

    public init(int value: Int) {
        self.value = BigInt(value)
    }

    public init(uint value: UInt) {
        self.value = BigInt(value)
    }

    /// Convert to hex string with 0x prefix
    public func toHex() -> String {
        return "0x" + String(value, radix: 16)
    }
}


