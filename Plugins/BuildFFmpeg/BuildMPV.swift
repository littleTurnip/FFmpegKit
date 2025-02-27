//
//  BuildMPV.swift
//
//
//  Created by kintan on 12/26/23.
//

import Foundation

class BuildMPV: BaseBuild {
    init() {
        super.init(library: .libmpv)
    }

    override func flagsDependencelibrarys() -> [Library] {
        [.gmp, .libsmbclient]
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        var array = [
            "-Dlibmpv=true",
            "-Dgl=enabled",
            "-Dplain-gl=enabled",
            "-Diconv=enabled",
            "-Dvulkan=enabled",
        ]
        if BaseBuild.disableGPL {
            array.append("-Dgpl=false")
        }
        if !(platform == .macos && arch.executable) {
            array.append("-Dcplayer=false")
        }
        if platform == .macos {
            array.append("-Dswift-flags=-sdk \(platform.isysroot) -target \(platform.deploymentTarget(arch: arch))")
            array.append("-Dcocoa=enabled")
            array.append("-Dcoreaudio=enabled")
            array.append("-Dgl-cocoa=enabled")
            array.append("-Dvideotoolbox-gl=enabled")
        } else {
            array.append("-Dvideotoolbox-gl=disabled")
            array.append("-Dswift-build=disabled")
            array.append("-Daudiounit=enabled")
            array.append("-Davfoundation=disabled")
            if platform == .maccatalyst {
                array.append("-Dcocoa=disabled")
                array.append("-Dcoreaudio=disabled")
            } else if platform == .xros || platform == .xrsimulator {
                array.append("-Dios-gl=disabled")
            } else {
                array.append("-Dios-gl=enabled")
            }
        }
        return array
    }

    override func createFrameworkInclude(framework: String, platform: PlatformType, frameworkDir: URL) throws {
        try super.createFrameworkInclude(framework: framework, platform: platform, frameworkDir: frameworkDir)
        if platform == .macos {
            for arch in platform.architectures where arch.executable {
                let name = "mpv"
                let prefix = thinDir(platform: platform, arch: arch)
                let item = URL(fileURLWithPath: "/usr/local/bin/\(name)")
                try? FileManager.default.removeItem(at: item)
                try FileManager.default.copyItem(at: prefix + "bin" + name, to: item)
            }
        }
    }
}
