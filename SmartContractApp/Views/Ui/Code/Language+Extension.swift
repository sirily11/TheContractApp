//
//  Language+Extension.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/7/25.
//

import LanguageSupport

extension LanguageConfiguration {
    static func json() -> LanguageConfiguration {
        LanguageConfiguration(
            name: "JSON",
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            stringRegex: /"(?:[^"\\]|\\.)*"/,
            characterRegex: nil,
            numberRegex: /-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/,
            singleLineComment: nil,
            nestedComment: nil,
            identifierRegex: nil,
            operatorRegex: nil,
            reservedIdentifiers: ["true", "false", "null"],
            reservedOperators: []
        )
    }

    static func solidity() -> LanguageConfiguration {
        LanguageConfiguration(
            name: "Solidity",
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            stringRegex: /"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'/,
            characterRegex: nil,
            numberRegex: /0x[0-9a-fA-F]+|(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/,
            singleLineComment: "//",
            nestedComment: (open: "/*", close: "*/"),
            identifierRegex: /[a-zA-Z_$][a-zA-Z0-9_$]*/,
            operatorRegex: /[+\-*\/%=!<>&|^~?:]+/,
            reservedIdentifiers: [
                // Types
                "address", "bool", "string", "bytes", "byte",
                "int", "int8", "int16", "int24", "int32", "int40", "int48", "int56", "int64",
                "int72", "int80", "int88", "int96", "int104", "int112", "int120", "int128",
                "int136", "int144", "int152", "int160", "int168", "int176", "int184", "int192",
                "int200", "int208", "int216", "int224", "int232", "int240", "int248", "int256",
                "uint", "uint8", "uint16", "uint24", "uint32", "uint40", "uint48", "uint56", "uint64",
                "uint72", "uint80", "uint88", "uint96", "uint104", "uint112", "uint120", "uint128",
                "uint136", "uint144", "uint152", "uint160", "uint168", "uint176", "uint184", "uint192",
                "uint200", "uint208", "uint216", "uint224", "uint232", "uint240", "uint248", "uint256",
                "bytes1", "bytes2", "bytes3", "bytes4", "bytes5", "bytes6", "bytes7", "bytes8",
                "bytes9", "bytes10", "bytes11", "bytes12", "bytes13", "bytes14", "bytes15", "bytes16",
                "bytes17", "bytes18", "bytes19", "bytes20", "bytes21", "bytes22", "bytes23", "bytes24",
                "bytes25", "bytes26", "bytes27", "bytes28", "bytes29", "bytes30", "bytes31", "bytes32",
                "fixed", "ufixed",
                // Keywords
                "abstract", "after", "alias", "apply", "auto", "case", "catch", "copyof", "default",
                "define", "final", "immutable", "implements", "in", "inline", "let", "macro", "match",
                "mutable", "null", "of", "override", "partial", "promise", "reference", "relocatable",
                "sealed", "sizeof", "static", "supports", "switch", "try", "typedef", "typeof", "unchecked",
                // Control flow
                "if", "else", "while", "do", "for", "break", "continue", "return", "throw", "revert", "require", "assert",
                // Declarations
                "contract", "library", "interface", "function", "modifier", "constructor", "fallback", "receive",
                "struct", "enum", "event", "error", "using", "is",
                // Visibility
                "public", "private", "internal", "external",
                // State mutability
                "pure", "view", "payable", "constant",
                // Storage
                "memory", "storage", "calldata",
                // Other
                "pragma", "import", "as", "from", "mapping", "indexed", "anonymous",
                "virtual", "new", "delete", "emit", "assembly",
                // Literals
                "true", "false", "wei", "gwei", "ether", "seconds", "minutes", "hours", "days", "weeks"
            ],
            reservedOperators: [
                "+", "-", "*", "/", "%", "**",
                "==", "!=", "<", ">", "<=", ">=",
                "&&", "||", "!",
                "&", "|", "^", "~", "<<", ">>",
                "=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<<=", ">>=",
                "++", "--",
                "?", ":",
                "=>", "."
            ]
        )
    }
}
