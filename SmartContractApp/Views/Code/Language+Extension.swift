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
}
