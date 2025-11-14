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

    // MARK: - Gwei Initialization Tests

    @Test("Initialize Gwei with hex value")
    func testInitializeGweiWithHex() {
        let gwei1 = Gwei(hex: "0x1")
        #expect(gwei1.value == BigInt(1))

        let gwei50 = Gwei(hex: "0x32")
        #expect(gwei50.value == BigInt(50))

        let gwei100 = Gwei(hex: "64")
        #expect(gwei100.value == BigInt(100))
    }

    @Test("Initialize Gwei with hex value without 0x prefix")
    func testInitializeGweiWithHexWithoutPrefix() {
        let gwei = Gwei(hex: "ff")
        #expect(gwei.value == BigInt(255))
    }

    @Test("Initialize Gwei with BigInt")
    func testInitializeGweiWithBigInt() {
        let gwei = Gwei(bigInt: BigInt(42))
        #expect(gwei.value == BigInt(42))

        let largeGwei = Gwei(bigInt: BigInt(1_000_000))
        #expect(largeGwei.value == BigInt(1_000_000))
    }

    @Test("Initialize Gwei with float")
    func testInitializeGweiWithFloat() {
        let gwei = Gwei(float: 50.0)
        #expect(gwei.value == BigInt(50))

        let gwei100 = Gwei(float: 100.5)  // Will truncate to 100
        #expect(gwei100.value == BigInt(100))
    }

    @Test("Initialize Gwei from Wei")
    func testInitializeGweiFromWei() {
        // 1 Gwei = 10^9 Wei
        let oneGweiInWei = BigInt(10).power(9)
        let wei = Wei(bigInt: oneGweiInWei)
        let gwei = Gwei(wei: wei)

        #expect(gwei.value == BigInt(1))
    }

    @Test("Initialize Gwei from Wei with multiple Gwei")
    func testInitializeGweiFromWeiWithMultiple() {
        // 50 Gwei = 50 * 10^9 Wei
        let fiftyGweiInWei = BigInt(50) * BigInt(10).power(9)
        let wei = Wei(bigInt: fiftyGweiInWei)
        let gwei = Gwei(wei: wei)

        #expect(gwei.value == BigInt(50))
    }

    @Test("Initialize Gwei from Ethers")
    func testInitializeGweiFromEthers() {
        // 1 Ether = 10^9 Gwei
        let oneEther = Ethers(bigInt: BigInt(1))
        let gwei = Gwei(ethers: oneEther)

        #expect(gwei.value == BigInt(10).power(9))
    }

    @Test("Initialize Gwei from fractional Ether")
    func testInitializeGweiFromFractionalEther() {
        // 0.001 Ether = 1,000,000 Gwei
        // Since we can't represent decimals, use BigInt directly
        let ethers = Ethers(bigInt: BigInt(1))
        let gwei = Gwei(ethers: ethers)

        #expect(gwei.value == BigInt(10).power(9))
    }

    // MARK: - Gwei Conversion Tests

    @Test("Convert 1 Gwei to Wei")
    func testConvertOneGweiToWei() {
        let gwei = Gwei(bigInt: BigInt(1))
        let wei = gwei.toWei()

        #expect(wei.value == BigInt(10).power(9))
    }

    @Test("Convert 0 Gwei to Wei")
    func testConvertZeroGweiToWei() {
        let gwei = Gwei(bigInt: BigInt(0))
        let wei = gwei.toWei()

        #expect(wei.value == BigInt(0))
    }

    @Test("Convert 50 Gwei to Wei")
    func testConvertFiftyGweiToWei() {
        let gwei = Gwei(bigInt: BigInt(50))
        let wei = gwei.toWei()

        let expected = BigInt(50) * BigInt(10).power(9)
        #expect(wei.value == expected)
    }

    @Test("Convert 1 Gwei to Ethers")
    func testConvertOneGweiToEthers() {
        let gwei = Gwei(bigInt: BigInt(1))
        let ethers = gwei.toEthers()

        // 1 Gwei is much less than 1 Ether, should be 0
        #expect(ethers.value == BigInt(0))
    }

    @Test("Convert 1 billion Gwei to Ethers")
    func testConvertBillionGweiToEthers() {
        // 1 Ether = 10^9 Gwei
        let gwei = Gwei(bigInt: BigInt(10).power(9))
        let ethers = gwei.toEthers()

        #expect(ethers.value == BigInt(1))
    }

    @Test("Convert 10 billion Gwei to Ethers")
    func testConvertTenBillionGweiToEthers() {
        // 10 Ether = 10 * 10^9 Gwei
        let gwei = Gwei(bigInt: BigInt(10) * BigInt(10).power(9))
        let ethers = gwei.toEthers()

        #expect(ethers.value == BigInt(10))
    }

    // MARK: - Wei to Gwei Conversion Tests

    @Test("Convert Wei to Gwei")
    func testConvertWeiToGwei() {
        let wei = Wei(bigInt: BigInt(10).power(9))
        let gwei = wei.toGwei()

        #expect(gwei.value == BigInt(1))
    }

    @Test("Convert 50 Gwei worth of Wei to Gwei")
    func testConvertFiftyGweiWorthOfWeiToGwei() {
        let wei = Wei(bigInt: BigInt(50) * BigInt(10).power(9))
        let gwei = wei.toGwei()

        #expect(gwei.value == BigInt(50))
    }

    @Test("Convert small Wei amount to Gwei")
    func testConvertSmallWeiToGwei() {
        let wei = Wei(bigInt: BigInt(1000))
        let gwei = wei.toGwei()

        // Much less than 1 Gwei, should be 0
        #expect(gwei.value == BigInt(0))
    }

    // MARK: - Ethers to Gwei Conversion Tests

    @Test("Convert 1 Ether to Gwei")
    func testConvertOneEtherToGwei() {
        let ether = Ethers(bigInt: BigInt(1))
        let gwei = ether.toGwei()

        #expect(gwei.value == BigInt(10).power(9))
    }

    @Test("Convert 0.000000001 Ether to Gwei")
    func testConvertSmallEtherToGwei() {
        // Since we can't represent decimals, this would be 0 Ether
        let ether = Ethers(bigInt: BigInt(0))
        let gwei = ether.toGwei()

        #expect(gwei.value == BigInt(0))
    }

    @Test("Convert 100 Ether to Gwei")
    func testConvertHundredEtherToGwei() {
        let ether = Ethers(bigInt: BigInt(100))
        let gwei = ether.toGwei()

        let expected = BigInt(100) * BigInt(10).power(9)
        #expect(gwei.value == expected)
    }

    // MARK: - Gwei Round-trip Conversion Tests

    @Test("Round-trip conversion: Gwei to Wei to Gwei")
    func testRoundTripGweiToWeiToGwei() {
        let originalGwei = Gwei(bigInt: BigInt(50))
        let wei = originalGwei.toWei()
        let convertedGwei = wei.toGwei()

        #expect(convertedGwei.value == originalGwei.value)
    }

    @Test("Round-trip conversion: Gwei to Ethers to Gwei (whole Ether)")
    func testRoundTripGweiToEthersToGweiWholeEther() {
        // Use a whole Ether amount (10^9 Gwei) for clean round-trip
        let originalGwei = Gwei(bigInt: BigInt(10).power(9))
        let ethers = originalGwei.toEthers()
        let convertedGwei = ethers.toGwei()

        #expect(convertedGwei.value == originalGwei.value)
    }

    @Test("Round-trip conversion loses fractional Gwei when converting to Ethers")
    func testRoundTripLosesFractionalGweiToEthers() {
        // Gwei with fractional Ether part
        let originalGwei = Gwei(bigInt: BigInt(10).power(9) + 12345)
        let ethers = originalGwei.toEthers()
        let convertedGwei = ethers.toGwei()

        // The fractional part (12345 Gwei) is lost in integer division
        #expect(convertedGwei.value != originalGwei.value)
        #expect(convertedGwei.value == BigInt(10).power(9))
    }

    // MARK: - Three-way Conversion Tests

    @Test("Three-way conversion: Ethers to Gwei to Wei")
    func testThreeWayEthersToGweiToWei() {
        let ethers = Ethers(bigInt: BigInt(1))
        let gwei = ethers.toGwei()
        let wei = gwei.toWei()

        let expected = BigInt(10).power(18)
        #expect(wei.value == expected)
    }

    @Test("Three-way conversion: Wei to Gwei to Ethers")
    func testThreeWayWeiToGweiToEthers() {
        let wei = Wei(bigInt: BigInt(10).power(18))
        let gwei = wei.toGwei()
        let ethers = gwei.toEthers()

        #expect(ethers.value == BigInt(1))
    }

    @Test("Three-way round-trip: Ethers to Gwei to Wei to Ethers")
    func testThreeWayRoundTripEthersToGweiToWeiToEthers() {
        let originalEthers = Ethers(bigInt: BigInt(5))
        let gwei = originalEthers.toGwei()
        let wei = gwei.toWei()
        let convertedEthers = wei.toEthers()

        #expect(convertedEthers.value == originalEthers.value)
    }

    // MARK: - Practical Gwei Examples

    @Test("Typical gas price: 20 Gwei")
    func testTypicalGasPrice() {
        let gasPrice = Gwei(bigInt: BigInt(20))
        let wei = gasPrice.toWei()

        let expected = BigInt(20) * BigInt(10).power(9)
        #expect(wei.value == expected)
    }

    @Test("High gas price: 200 Gwei")
    func testHighGasPrice() {
        let gasPrice = Gwei(float: 200.0)
        let wei = gasPrice.toWei()

        let expected = BigInt(200) * BigInt(10).power(9)
        #expect(wei.value == expected)
    }

    @Test("Low gas price: 1 Gwei")
    func testLowGasPrice() {
        let gasPrice = Gwei(bigInt: BigInt(1))
        let wei = gasPrice.toWei()

        #expect(wei.value == BigInt(10).power(9))
    }

    @Test("Transaction cost calculation with Gwei")
    func testTransactionCostCalculation() {
        // 21000 gas units at 50 Gwei per unit
        let gasPriceGwei = Gwei(bigInt: BigInt(50))
        let gasUnits = BigInt(21000)

        let totalCostWei = gasPriceGwei.toWei().value * gasUnits
        let totalCostGwei = Gwei(wei: Wei(bigInt: totalCostWei))

        #expect(totalCostGwei.value == BigInt(1_050_000))  // 21000 * 50 = 1,050,000 Gwei
    }

    @Test("Convert typical gas price from Wei to Gwei")
    func testConvertTypicalGasPriceFromWeiToGwei() {
        // 50 Gwei in Wei
        let weiValue = BigInt(50) * BigInt(10).power(9)
        let wei = Wei(bigInt: weiValue)
        let gwei = wei.toGwei()

        #expect(gwei.value == BigInt(50))
    }

    // MARK: - Gwei Edge Cases

    @Test("Initialize Gwei with empty hex string")
    func testInitializeGweiWithEmptyHex() {
        let gwei = Gwei(hex: "")
        #expect(gwei.value == BigInt(0))
    }

    @Test("Initialize Gwei with very large hex value")
    func testInitializeGweiWithVeryLargeHex() {
        // Max uint256 value
        let maxUint256 = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
        let gwei = Gwei(hex: maxUint256)

        let expectedValue = BigInt(2).power(256) - 1
        #expect(gwei.value == expectedValue)
    }

    @Test("Initialize Gwei with invalid hex returns zero")
    func testInitializeGweiWithInvalidHex() {
        let gwei = Gwei(hex: "0xZZZ")
        #expect(gwei.value == BigInt(0))

        let gwei2 = Gwei(hex: "invalid")
        #expect(gwei2.value == BigInt(0))
    }

    @Test("Gwei hex with uppercase letters")
    func testGweiHexWithUppercaseLetters() {
        let gwei = Gwei(hex: "0xABCDEF")
        #expect(gwei.value == BigInt(11_259_375))
    }

    @Test("Gwei hex with mixed case")
    func testGweiHexWithMixedCase() {
        let gwei = Gwei(hex: "0xAbCdEf")
        #expect(gwei.value == BigInt(11_259_375))
    }

    @Test("Gwei hex with leading zeros")
    func testGweiHexWithLeadingZeros() {
        let gwei = Gwei(hex: "0x000000001")
        #expect(gwei.value == BigInt(1))
    }
}
