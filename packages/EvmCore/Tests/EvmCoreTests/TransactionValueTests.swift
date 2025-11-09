import BigInt
import Foundation
import Testing

@testable import EvmCore

@Suite("TransactionValue Tests")
struct TransactionValueTests {

    // MARK: - Initialization Tests

    @Test("Initialize TransactionValue from Ethers")
    func testInitializeFromEthers() {
        let ethers = Ethers(bigInt: BigInt(5))
        let txValue = TransactionValue(ethers: ethers)

        let resultWei = txValue.toWei()
        let expectedWei = BigInt(5) * BigInt(10).power(18)
        #expect(resultWei.value == expectedWei)
    }

    @Test("Initialize TransactionValue from Wei")
    func testInitializeFromWei() {
        let wei = Wei(bigInt: BigInt(1000))
        let txValue = TransactionValue(wei: wei)

        let resultWei = txValue.toWei()
        #expect(resultWei.value == BigInt(1000))
    }

    // MARK: - Conversion Tests

    @Test("Convert TransactionValue(ethers) to Wei")
    func testConvertEthersToWei() {
        let ethers = Ethers(bigInt: BigInt(2))
        let txValue = TransactionValue(ethers: ethers)

        let wei = txValue.toWei()
        let expected = BigInt(2) * BigInt(10).power(18)
        #expect(wei.value == expected)
    }

    @Test("Convert TransactionValue(wei) to Wei")
    func testConvertWeiToWei() {
        let originalWei = Wei(bigInt: BigInt(5000))
        let txValue = TransactionValue(wei: originalWei)

        let resultWei = txValue.toWei()
        #expect(resultWei.value == BigInt(5000))
    }

    @Test("Convert TransactionValue(ethers) to Ethers")
    func testConvertEthersToEthers() {
        let originalEthers = Ethers(bigInt: BigInt(10))
        let txValue = TransactionValue(ethers: originalEthers)

        let resultEthers = txValue.toEthers()
        #expect(resultEthers.value == BigInt(10))
    }

    @Test("Convert TransactionValue(wei) to Ethers")
    func testConvertWeiToEthers() {
        let wei = Wei(bigInt: BigInt(3) * BigInt(10).power(18))
        let txValue = TransactionValue(wei: wei)

        let ethers = txValue.toEthers()
        #expect(ethers.value == BigInt(3))
    }

    // MARK: - Hex String Tests

    @Test("Convert TransactionValue to hex string from Ethers")
    func testToHexStringFromEthers() {
        let ethers = Ethers(bigInt: BigInt(1))
        let txValue = TransactionValue(ethers: ethers)

        let hexString = txValue.toHexString()
        let expectedWei = BigInt(10).power(18)
        let expectedHex = "0x" + String(expectedWei, radix: 16)
        #expect(hexString == expectedHex)
    }

    @Test("Convert TransactionValue to hex string from Wei")
    func testToHexStringFromWei() {
        let wei = Wei(bigInt: BigInt(1000))
        let txValue = TransactionValue(wei: wei)

        let hexString = txValue.toHexString()
        #expect(hexString == "0x3e8")  // 1000 in hex
    }

    @Test("Convert zero value to hex string")
    func testZeroValueToHexString() {
        let wei = Wei(bigInt: BigInt(0))
        let txValue = TransactionValue(wei: wei)

        let hexString = txValue.toHexString()
        #expect(hexString == "0x0")
    }

    // MARK: - Codable Tests

    @Test("Encode TransactionValue to JSON")
    func testEncodeToJSON() throws {
        let wei = Wei(bigInt: BigInt(1000))
        let txValue = TransactionValue(wei: wei)

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(txValue)
        let jsonString = String(data: jsonData, encoding: .utf8)

        #expect(jsonString == "\"0x3e8\"")
    }

    @Test("Decode TransactionValue from JSON hex string")
    func testDecodeFromJSON() throws {
        let jsonString = "\"0x3e8\""
        let jsonData = jsonString.data(using: .utf8)!

        let decoder = JSONDecoder()
        let txValue = try decoder.decode(TransactionValue.self, from: jsonData)

        let wei = txValue.toWei()
        #expect(wei.value == BigInt(1000))
    }

    @Test("Round-trip encode and decode")
    func testRoundTripEncodeDecode() throws {
        let originalWei = Wei(bigInt: BigInt(12345))
        let originalTxValue = TransactionValue(wei: originalWei)

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(originalTxValue)

        let decoder = JSONDecoder()
        let decodedTxValue = try decoder.decode(TransactionValue.self, from: jsonData)

        #expect(decodedTxValue.toWei().value == originalTxValue.toWei().value)
    }

    @Test("Decode from hex with 0x prefix")
    func testDecodeFromHexWithPrefix() throws {
        let jsonString = "\"0xde0b6b3a7640000\""  // 1 Ether in Wei
        let jsonData = jsonString.data(using: .utf8)!

        let decoder = JSONDecoder()
        let txValue = try decoder.decode(TransactionValue.self, from: jsonData)

        let wei = txValue.toWei()
        #expect(wei.value == BigInt(10).power(18))
    }

    @Test("Decode from hex without 0x prefix")
    func testDecodeFromHexWithoutPrefix() throws {
        let jsonString = "\"de0b6b3a7640000\""  // 1 Ether in Wei (no prefix)
        let jsonData = jsonString.data(using: .utf8)!

        let decoder = JSONDecoder()
        let txValue = try decoder.decode(TransactionValue.self, from: jsonData)

        let wei = txValue.toWei()
        #expect(wei.value == BigInt(10).power(18))
    }

    // MARK: - Equatable Tests

    @Test("TransactionValue equality - same wei value")
    func testEqualitySameWei() {
        let txValue1 = TransactionValue(wei: Wei(bigInt: BigInt(1000)))
        let txValue2 = TransactionValue(wei: Wei(bigInt: BigInt(1000)))

        #expect(txValue1 == txValue2)
    }

    @Test("TransactionValue equality - ethers vs wei same value")
    func testEqualityEthersVsWei() {
        let ethers = Ethers(bigInt: BigInt(1))
        let wei = Wei(bigInt: BigInt(10).power(18))

        let txValue1 = TransactionValue(ethers: ethers)
        let txValue2 = TransactionValue(wei: wei)

        #expect(txValue1 == txValue2)
    }

    @Test("TransactionValue inequality - different values")
    func testInequality() {
        let txValue1 = TransactionValue(wei: Wei(bigInt: BigInt(1000)))
        let txValue2 = TransactionValue(wei: Wei(bigInt: BigInt(2000)))

        #expect(txValue1 != txValue2)
    }

    // MARK: - Practical Usage Tests

    @Test("Create transaction value for 0.01 ETH payment")
    func testPointZeroOneEthPayment() {
        // 0.01 ETH = 10^16 Wei
        let paymentWei = BigInt(10).power(16)
        let txValue = TransactionValue(wei: Wei(bigInt: paymentWei))

        let hexString = txValue.toHexString()
        #expect(hexString == "0x" + String(paymentWei, radix: 16))
    }

    @Test("Create transaction value for 1 ETH payment using Ethers")
    func testOneEthPaymentFromEthers() {
        let txValue = TransactionValue(ethers: Ethers(bigInt: BigInt(1)))

        let wei = txValue.toWei()
        #expect(wei.value == BigInt(10).power(18))
    }

    @Test("Create transaction value for 100 Gwei gas value")
    func testGasValueInGwei() {
        // 100 Gwei = 100 * 10^9 Wei
        let gweiInWei = BigInt(100) * BigInt(10).power(9)
        let txValue = TransactionValue(wei: Wei(bigInt: gweiInWei))

        let resultWei = txValue.toWei()
        #expect(resultWei.value == gweiInWei)
    }

    @Test("Large transaction value")
    func testLargeTransactionValue() {
        // 1000 ETH
        let largeEthers = Ethers(bigInt: BigInt(1000))
        let txValue = TransactionValue(ethers: largeEthers)

        let wei = txValue.toWei()
        let expectedWei = BigInt(1000) * BigInt(10).power(18)
        #expect(wei.value == expectedWei)

        let hexString = txValue.toHexString()
        #expect(hexString == "0x" + String(expectedWei, radix: 16))
    }

    @Test("Zero transaction value")
    func testZeroTransactionValue() {
        let txValue = TransactionValue(wei: Wei(bigInt: BigInt(0)))

        #expect(txValue.toWei().value == BigInt(0))
        #expect(txValue.toEthers().value == BigInt(0))
        #expect(txValue.toHexString() == "0x0")
    }

    // MARK: - Edge Cases

    @Test("Very large transaction value (max uint256)")
    func testMaxUint256Value() {
        let maxValue = BigInt(2).power(256) - 1
        let txValue = TransactionValue(wei: Wei(bigInt: maxValue))

        let resultWei = txValue.toWei()
        #expect(resultWei.value == maxValue)
    }

    @Test("Fractional ether conversion loses precision")
    func testFractionalEtherLosesPrecision() {
        // 1.5 ETH in Wei
        let weiValue = BigInt(10).power(18) * 3 / 2
        let txValue = TransactionValue(wei: Wei(bigInt: weiValue))

        let ethers = txValue.toEthers()
        // Should be 1 ETH due to integer division
        #expect(ethers.value == BigInt(1))
    }
}
