//
//  ScriptFileKind.swift
//  LaunchBrew
//
//  Created by Yuki Suzuki on 9/7/26.
//
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
