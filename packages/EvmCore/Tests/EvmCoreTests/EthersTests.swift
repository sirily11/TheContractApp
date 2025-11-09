import BigInt
import Foundation
import Testing

@testable import EvmCore

@Suite("Ethers and Wei Tests")
struct EthersTests {

    // MARK: - Ethers Initialization Tests

    @Test("Initialize Ethers with hex value")
    func testInitializeEthersWithHex() {
        let ether1 = Ethers(hex: "0x1")
        #expect(ether1.value == BigInt(1))

        let ether10 = Ethers(hex: "0xa")
        #expect(ether10.value == BigInt(10))

        let ether100 = Ethers(hex: "64")
        #expect(ether100.value == BigInt(100))
    }

    @Test("Initialize Ethers with hex value without 0x prefix")
    func testInitializeEthersWithHexWithoutPrefix() {
        let ether = Ethers(hex: "ff")
        #expect(ether.value == BigInt(255))
    }

    @Test("Initialize Ethers with BigInt")
    func testInitializeEthersWithBigInt() {
        let ether = Ethers(bigInt: BigInt(42))
        #expect(ether.value == BigInt(42))

        let largeEther = Ethers(bigInt: BigInt(1_000_000_000_000_000_000))
        #expect(largeEther.value == BigInt(1_000_000_000_000_000_000))
    }

    @Test("Initialize Ethers from Wei")
    func testInitializeEthersFromWei() {
        // 1 Ether = 10^18 Wei
        let oneEtherInWei = BigInt(10).power(18)
        let wei = Wei(bigInt: oneEtherInWei)
        let ether = Ethers(wei: wei)

        #expect(ether.value == BigInt(1))
    }

    @Test("Initialize Ethers from Wei with fractional value")
    func testInitializeEthersFromWeiWithFractionalValue() {
        // 1.5 Ether = 1.5 * 10^18 Wei
        let onePointFiveEtherInWei = BigInt(10).power(18) * 3 / 2
        let wei = Wei(bigInt: onePointFiveEtherInWei)
        let ether = Ethers(wei: wei)

        // Integer division: 1.5 Ether -> 1 Ether
        #expect(ether.value == BigInt(1))
    }

    // MARK: - Wei Initialization Tests

    @Test("Initialize Wei with hex value")
    func testInitializeWeiWithHex() {
        let wei1 = Wei(hex: "0x1")
        #expect(wei1.value == BigInt(1))

        let wei100 = Wei(hex: "0x64")
        #expect(wei100.value == BigInt(100))

        let largeWei = Wei(hex: "de0b6b3a7640000")  // 1 Ether in Wei
        #expect(largeWei.value == BigInt(10).power(18))
    }

    @Test("Initialize Wei with hex value without 0x prefix")
    func testInitializeWeiWithHexWithoutPrefix() {
        let wei = Wei(hex: "ff")
        #expect(wei.value == BigInt(255))
    }

    @Test("Initialize Wei with BigInt")
    func testInitializeWeiWithBigInt() {
        let wei = Wei(bigInt: BigInt(1000))
        #expect(wei.value == BigInt(1000))

        let largeWei = Wei(bigInt: BigInt(10).power(18))
        #expect(largeWei.value == BigInt(10).power(18))
    }

    // MARK: - Conversion Tests: Ethers to Wei

    @Test("Convert 1 Ether to Wei")
    func testConvertOneEtherToWei() {
        let ether = Ethers(bigInt: BigInt(1))
        let wei = ether.toWei()

        #expect(wei.value == BigInt(10).power(18))
    }

    @Test("Convert 0 Ether to Wei")
    func testConvertZeroEtherToWei() {
        let ether = Ethers(bigInt: BigInt(0))
        let wei = ether.toWei()

        #expect(wei.value == BigInt(0))
    }

    @Test("Convert 100 Ether to Wei")
    func testConvertHundredEtherToWei() {
        let ether = Ethers(bigInt: BigInt(100))
        let wei = ether.toWei()

        let expected = BigInt(100) * BigInt(10).power(18)
        #expect(wei.value == expected)
    }

    @Test("Convert large Ether value to Wei")
    func testConvertLargeEtherToWei() {
        let ether = Ethers(bigInt: BigInt(1_000_000))
        let wei = ether.toWei()

        let expected = BigInt(1_000_000) * BigInt(10).power(18)
        #expect(wei.value == expected)
    }

    // MARK: - Conversion Tests: Wei to Ethers

    @Test("Convert 1 Ether worth of Wei to Ethers")
    func testConvertOneEtherWorthOfWeiToEthers() {
        let wei = Wei(bigInt: BigInt(10).power(18))
        let ether = wei.toEthers()

        #expect(ether.value == BigInt(1))
    }

    @Test("Convert 0 Wei to Ethers")
    func testConvertZeroWeiToEthers() {
        let wei = Wei(bigInt: BigInt(0))
        let ether = wei.toEthers()

        #expect(ether.value == BigInt(0))
    }

    @Test("Convert 10 Ether worth of Wei to Ethers")
    func testConvertTenEtherWorthOfWeiToEthers() {
        let wei = Wei(bigInt: BigInt(10) * BigInt(10).power(18))
        let ether = wei.toEthers()

        #expect(ether.value == BigInt(10))
    }

    @Test("Convert fractional Wei to Ethers")
    func testConvertFractionalWeiToEthers() {
        // 0.5 Ether in Wei
        let halfEtherInWei = BigInt(10).power(18) / 2
        let wei = Wei(bigInt: halfEtherInWei)
        let ether = wei.toEthers()

        // Integer division: 0.5 Ether -> 0 Ether
        #expect(ether.value == BigInt(0))
    }

    @Test("Convert small Wei amount to Ethers")
    func testConvertSmallWeiToEthers() {
        let wei = Wei(bigInt: BigInt(1000))
        let ether = wei.toEthers()

        // Much less than 1 Ether, should be 0
        #expect(ether.value == BigInt(0))
    }

    // MARK: - Round-trip Conversion Tests

    @Test("Round-trip conversion: Ether to Wei to Ether")
    func testRoundTripEtherToWeiToEther() {
        let originalEther = Ethers(bigInt: BigInt(42))
        let wei = originalEther.toWei()
        let convertedEther = wei.toEthers()

        #expect(convertedEther.value == originalEther.value)
    }

    @Test("Round-trip conversion: Wei to Ether to Wei (whole Ether)")
    func testRoundTripWeiToEtherToWeiWholeEther() {
        // Use a whole Ether amount for clean round-trip
        let originalWei = Wei(bigInt: BigInt(5) * BigInt(10).power(18))
        let ether = originalWei.toEthers()
        let convertedWei = ether.toWei()

        #expect(convertedWei.value == originalWei.value)
    }

    @Test("Round-trip conversion loses fractional Wei")
    func testRoundTripLosesFractionalWei() {
        // Wei with fractional Ether part
        let originalWei = Wei(bigInt: BigInt(10).power(18) + 12345)
        let ether = originalWei.toEthers()
        let convertedWei = ether.toWei()

        // The fractional part (12345 Wei) is lost in integer division
        #expect(convertedWei.value != originalWei.value)
        #expect(convertedWei.value == BigInt(10).power(18))
    }

    // MARK: - Edge Cases

    @Test("Initialize with empty hex string")
    func testInitializeWithEmptyHex() {
        let ether = Ethers(hex: "")
        #expect(ether.value == BigInt(0))

        let wei = Wei(hex: "")
        #expect(wei.value == BigInt(0))
    }

    @Test("Initialize with very large hex value")
    func testInitializeWithVeryLargeHex() {
        // Max uint256 value
        let maxUint256 = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
        let ether = Ethers(hex: maxUint256)
        let wei = Wei(hex: maxUint256)

        let expectedValue = BigInt(2).power(256) - 1
        #expect(ether.value == expectedValue)
        #expect(wei.value == expectedValue)
    }

    @Test("Initialize with invalid hex returns zero")
    func testInitializeWithInvalidHex() {
        let ether = Ethers(hex: "0xZZZ")
        #expect(ether.value == BigInt(0))

        let wei = Wei(hex: "invalid")
        #expect(wei.value == BigInt(0))
    }

    // MARK: - Practical Examples

    @Test("Typical transaction value: 0.01 Ether")
    func testTypicalTransactionValue() {
        let ether = Ethers(bigInt: BigInt(1))  // 0.01 would need decimal, using 1 for simplicity
        let wei = ether.toWei()

        #expect(wei.value == BigInt(10).power(18))
    }

    @Test("Gas price conversion")
    func testGasPriceConversion() {
        // Typical gas price: 20 Gwei = 20 * 10^9 Wei
        let gweiInWei = BigInt(20) * BigInt(10).power(9)
        let wei = Wei(bigInt: gweiInWei)
        let ether = wei.toEthers()

        // 20 Gwei is much less than 1 Ether
        #expect(ether.value == BigInt(0))
    }

    @Test("Large balance: 1 million Ether")
    func testLargeBalance() {
        let millionEther = Ethers(bigInt: BigInt(1_000_000))
        let wei = millionEther.toWei()

        let expected = BigInt(1_000_000) * BigInt(10).power(18)
        #expect(wei.value == expected)

        // Convert back
        let etherAgain = wei.toEthers()
        #expect(etherAgain.value == BigInt(1_000_000))
    }

    // MARK: - Hex String Format Tests

    @Test("Hex with uppercase letters")
    func testHexWithUppercaseLetters() {
        let ether = Ethers(hex: "0xABCDEF")
        #expect(ether.value == BigInt(11_259_375))  // 0xABCDEF in decimal
    }

    @Test("Hex with mixed case")
    func testHexWithMixedCase() {
        let wei = Wei(hex: "0xAbCdEf")
        #expect(wei.value == BigInt(11_259_375))
    }

    @Test("Hex with leading zeros")
    func testHexWithLeadingZeros() {
        let ether = Ethers(hex: "0x000000001")
        #expect(ether.value == BigInt(1))
    }
}
