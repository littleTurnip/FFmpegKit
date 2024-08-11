//
//  File.swift
//  
//
//  Created by kintan on 8/11/24.
//

import Foundation
import ffprobe

var arguments = Array(CommandLine.arguments.dropFirst())
arguments.insert("ffprobe", at: 0)
var argv = arguments.map {
    UnsafeMutablePointer(mutating: ($0 as NSString).utf8String)
}
ffprobe_execute(Int32(arguments.count), &argv)

