//
//  File.swift
//  
//
//  Created by kintan on 8/11/24.
//

import ffmpeg
import Foundation

var arguments = Array(CommandLine.arguments.dropFirst())
arguments.insert("ffmpeg", at: 0)
var argv = arguments.map {
    UnsafeMutablePointer(mutating: ($0 as NSString).utf8String)
}
ffmpeg_execute(Int32(arguments.count), &argv)
