//
//  MachOType.swift
//  ScriptJet
//
//  Created by Yuki Suzuki on 9/8/26.
//

import Foundation

enum MachOType {
    case thin32       // 32-bit Mach-O
    case thin64       // 64-bit Mach-O
    case universalFat // Universal Binary (contains multiple architectures)
    case notMachO     // Not a Mach-O file
}

func detectMachO(at url: URL) -> MachOType {
    // We only need to read the first 4 bytes (UInt32) to verify the magic number
    guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
        return .notMachO
    }
    
    defer {
        try? fileHandle.close()
    }
    
    guard let data = try? fileHandle.read(upToCount: 4), data.count == 4 else {
        return .notMachO
    }
    
    // Convert the 4 bytes into a 32-bit unsigned integer
    let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
    
    switch magic {
    // 64-bit Mach-O (Standard & Byte-Swapped/CIGAM)
    case 0xfeedfacf, 0xcffaedfe:
        return .thin64
        
    // 32-bit Mach-O (Standard & Byte-Swapped/CIGAM)
    case 0xfeedface, 0xcefaedfe:
        return .thin32
        
    // Universal Fat Binary (Standard & Byte-Swapped/CIGAM)
    case 0xcafebabe, 0xbebafeca:
        return .universalFat
        
    default:
        return .notMachO
    }
}
