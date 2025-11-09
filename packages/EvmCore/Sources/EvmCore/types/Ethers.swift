import BigInt
import Foundation

public struct Ethers: Equatable {
    public let value: BigInt

    private static let weiPerEther = BigInt(10).power(18)

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

    public func toWei() -> Wei {
        return Wei(bigInt: value * Ethers.weiPerEther)
    }

    public init(wei value: Wei) {
        self.value = value.value / Ethers.weiPerEther
    }
}

public struct Wei: Equatable {
    public let value: BigInt

    private static let weiPerEther = BigInt(10).power(18)

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
}
