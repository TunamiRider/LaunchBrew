//
//  ScriptFileKind.swift
//  ScriptJet
//
//  Created by Yuki Suzuki on 9/7/26.
//

//import Foundation
//import UniformTypeIdentifiers
//
//enum ScriptFileKind {
//    case shellScript
//    case unixExecutable
//    case notExecutable
//}

//func scriptFileKind(for url: URL) throws -> ScriptFileKind {
//    let values = try url.resourceValues(
//        forKeys: [
//            .isRegularFileKey,
//            .isExecutableKey,
//            .contentTypeKey
//        ]
//    )
//
//    guard values.isRegularFile == true else {
//        return .notExecutable
//    }
//
//    // Best semantic answer when Finder/macOS recognizes it as a shell script.
//    if values.contentType?.conforms(to: .shellScript) == true {
//        return .shellScript
//    }
//
//    // Helpful fallback for common script extensions that may lack Finder metadata.
//    let shellExtensions: Set<String> = [
//        "sh", "bash", "zsh", "fish", "command", "ksh"
//    ]
//
//    if shellExtensions.contains(url.pathExtension.lowercased()) {
//        return .shellScript
//    }
//
//    // A native binary, or another executable such as a Python/Ruby script
//    // that is marked executable.
//    if values.isExecutable == true {
//        return .unixExecutable
//    }
//
//    return .notExecutable
//}


import Foundation
import UniformTypeIdentifiers

enum ScriptFileKind {
    case shellScript(interpreter: String)
    case unixExecutable
    case unsupported
}

func classifyFile(at url: URL) throws -> ScriptFileKind {
    let values = try url.resourceValues(
        forKeys: [
            .isRegularFileKey,
            .isExecutableKey,
            .contentTypeKey
        ]
    )

    guard values.isRegularFile == true else {
        return .unsupported
    }

    let shellExtensions: Set<String> = [
        "sh", "bash", "zsh", "fish", "ksh", "command"
    ]

    let isShellScript =
        values.contentType?.conforms(to: .shellScript) == true ||
        shellExtensions.contains(url.pathExtension.lowercased())

    if isShellScript {
        return .shellScript(interpreter: "/bin/zsh")
    }

    if values.isExecutable == true {
        return .unixExecutable
    }

    return .unsupported
}
