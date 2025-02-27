import Foundation

@main struct Build {}

#if canImport(PackagePlugin)
import PackagePlugin

extension Build: CommandPlugin {
    func performCommand(context _: PluginContext, arguments: [String]) throws {
        try Build.performCommand(arguments: arguments)
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension Build: XcodeCommandPlugin {
    func performCommand(context _: XcodePluginContext, arguments: [String]) throws {
        try Build.performCommand(arguments: arguments)
    }
}
#endif

#else
extension Build {
    static func main() throws {
        try performCommand(arguments: Array(CommandLine.arguments.dropFirst()))
    }
}
#endif

extension Build {
    static var ffmpegConfiguers = [String]()
    static var isDebug = false

    static func performCommand(arguments: [String]) throws {
        print(arguments)
        if arguments.contains("h") || arguments.contains("-h") || arguments.contains("--help") {
            printHelp()
            return
        }
        if Utility.shell("which brew") == nil {
            print("""
            You need to run the script first
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            """)
            return
        }
        if Utility.shell("which pkg-config") == nil {
            Utility.shell("brew install pkg-config")
        }
        let path = URL.currentDirectory + ".Script"
        if !FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        }
        FileManager.default.changeCurrentDirectoryPath(path.path)
        var librarys = [Library]()
        for argument in arguments {
            if argument == "notRecompile" {
                BaseBuild.notRecompile = true
            } else if argument == "gitCloneAll" {
                BaseBuild.gitCloneAll = true
            } else if argument == "disableGPL" {
                BaseBuild.disableGPL = true
            } else if argument == "enable-debug" {
                isDebug = true
            } else if argument.hasPrefix("platforms=") {
                let values = String(argument.suffix(argument.count - "platforms=".count))
                let platforms = values.split(separator: ",").compactMap {
                    PlatformType(rawValue: String($0))
                }
                if !platforms.isEmpty {
                    BaseBuild.platforms = platforms
                }
            } else if argument.hasPrefix("enable-") {
                let value = String(argument.suffix(argument.count - "enable-".count))
                if let library = Library(rawValue: value) {
                    librarys.append(library)
                } else {
                    print("argument \(argument) wrong")
                    return
                }
            } else if argument.hasPrefix("--"), argument != "--disable-sandbox", argument != "--allow-writing-to-directory" {
                Build.ffmpegConfiguers.append(argument)
            }
        }
        if isDebug {
            Build.ffmpegConfiguers.append("--enable-debug")
            Build.ffmpegConfiguers.append("--enable-debug=3")
            Build.ffmpegConfiguers.append("--disable-stripping")
        } else {
            Build.ffmpegConfiguers.append("--disable-debug")
            Build.ffmpegConfiguers.append("--enable-stripping")
        }

        if librarys.isEmpty {
            librarys.append(contentsOf: [.libshaderc, .vulkan, .lcms2, .libdav1d, .libplacebo, .gmp, .nettle, .gnutls, .libsrt, .libfreetype, .libfribidi, .libharfbuzz, .libfontconfig, .libass, .libzvbi, .libbluray, .libopus, .libx264, .libx265, .FFmpeg, .libmpv])
        }
        if BaseBuild.disableGPL {
            librarys.removeAll {
                $0.isGPL
            }
        } else {
            Build.ffmpegConfiguers.append("--enable-gpl")
        }
        for library in librarys {
            try library.build.buildALL()
        }
    }

    static func printHelp() {
        print("""
        Usage: swift package BuildFFmpeg [OPTION]...
        Default Build: swift package --disable-sandbox BuildFFmpeg enable-libshaderc enable-vulkan enable-lcms2 enable-libdav1d enable-libplacebo enable-gmp enable-nettle enable-gnutls  enable-libsrt enable-libfreetype enable-libfribidi enable-libharfbuzz enable-libfontconfig enable-libass enable-libbluray enable-libzvbi enable-libopus enable-libx264 enable-libx265 enable-FFmpeg enable-libmpv

        Options:
            h, -h, --help       display this help and exit
            notRecompile        If there is a library, then there is no need to recompile
            gitCloneAll         git clone not add --depth 1
            enable-debug,       build ffmpeg with debug information
            platforms=xros      deployment platform: macos,ios,isimulator,tvos,tvsimulator,xros,xrsimulator,maccatalyst,watchos,watchsimulator
            --xx                add ffmpeg Configuers

        Libraries:
            enable-libshaderc   build with libshaderc
            enable-vulkan       depend enable-libshaderc
            enable-libdav1d     build with libdav1d
            enable-libplacebo   depend enable-libshaderc enable-vulkan enable-lcms2 enable-libdav1d
            enable-nettle       depend enable-gmp
            enable-gnutls       depend enable-gmp enable-nettle
            enable-libsmbclient depend enable-gmp enable-nettle enable-gnutls enbale-readline
            enable-libsrt       depend enable-openssl or enable-gnutls
            enable-libfreetype  build with libfreetype
            enable-libharfbuzz  depend enable-libfreetype
            enable-libfontconfig depend enable-libfreetype
            enable-libass       depend enable-libfreetype enable-libfribidi enable-libharfbuzz enable-libfontconfig
            enable-libbluray    depend enable-libfreetype enable-libfontconfig
            enable-libzvbi      build with libzvbi
            enable-FFmpeg       build with FFmpeg
            enable-libmpv       depend enable-libass enable-FFmpeg
            enable-openssl      build with openssl [no]
        """)
    }
}

enum Library: String, CaseIterable {
    case libglslang, libshaderc, vulkan, lcms2, libdovi, libdav1d, libplacebo, libfreetype, libharfbuzz, libfribidi, libass, gmp, readline, nettle, gnutls, libsmbclient, libsrt, libzvbi, libfontconfig, libbluray, libopus, libx264, libx265, FFmpeg, libmpv, openssl, libtls, boringssl, libpng, libupnp, libnfs, libsmb2, libarchive
    var version: String {
        switch self {
        case .FFmpeg:
            return "n7.0.2"
        case .libfreetype:
            return "VER-2-13-3"
        case .libfribidi:
            return "v1.0.16"
        case .libharfbuzz:
            return "10.0.1"
        case .libass:
            return "0.17.3"
        case .libpng:
            return "v1.6.44"
        case .libmpv:
            return "v0.39.0"
        case .openssl:
            return "openssl-3.3.0"
        case .libsrt:
            return "v1.5.3"
        case .libsmbclient:
            return "samba-4.15.13"
        case .gnutls:
            // 3.8.7会有一个编译错误。需要等待3.8.8版本
            return "3.8.6"
        case .nettle:
            return "nettle_3.10_release_20240616"
        case .libdav1d:
            return "1.4.3"
        case .gmp:
            return "6.3.0"
        case .libtls:
            return "OPENBSD_7_3"
        case .libzvbi:
            return "v0.2.42"
        case .boringssl:
            return "master"
        case .libplacebo:
            return "v7.349.0"
        case .vulkan:
            return "v1.2.11"
        case .libshaderc:
            return "v2024.3"
        case .readline:
            return "readline-8.2"
        case .libglslang:
            return "13.1.1"
        case .libdovi:
            return "2.1.0"
        case .lcms2:
            return "lcms2.16"
        case .libupnp:
            return "release-1.14.18"
        case .libnfs:
            return "libnfs-5.0.2"
        case .libbluray:
            return "1.3.4"
        case .libfontconfig:
            return "2.15.0"
        case .libsmb2:
            return "master"
        case .libx265:
            return "3.6"
        case .libx264:
            return "stable"
        case .libarchive:
            return "v3.7.4"
        case .libopus:
            return "v1.5.2"
        }
    }

    var url: String {
        switch self {
        case .libpng:
            return "https://github.com/glennrp/libpng"
        case .libmpv:
            return "https://github.com/mpv-player/mpv"
        case .libsrt:
            return "https://github.com/Haivision/srt"
        case .libsmbclient:
            return "https://github.com/samba-team/samba"
        case .nettle:
            return "https://git.lysator.liu.se/nettle/nettle"
        case .gmp:
            return "https://github.com/kingslay/GMP"
        case .libdav1d:
            return "https://github.com/videolan/dav1d"
        case .libtls:
            return "https://github.com/libressl/portable"
        case .libzvbi:
            return "https://github.com/zapping-vbi/zvbi"
        case .boringssl:
            return "https://github.com/google/boringssl"
        case .libplacebo:
            return "https://github.com/haasn/libplacebo"
        case .vulkan:
            return "https://github.com/KhronosGroup/MoltenVK"
        case .libshaderc:
            return "https://github.com/google/shaderc"
        case .readline:
            return "https://git.savannah.gnu.org/git/readline.git"
        case .libglslang:
            return "https://github.com/KhronosGroup/glslang"
        case .libdovi:
            return "https://github.com/quietvoid/dovi_tool"
        case .lcms2:
            return "https://github.com/mm2/Little-CMS"
        case .libupnp:
            return "https://github.com/pupnp/pupnp"
        case .libnfs:
            return "https://github.com/sahlberg/libnfs"
        case .libbluray:
            return "https://code.videolan.org/videolan/libbluray"
        case .libfontconfig:
            return "https://gitlab.freedesktop.org/fontconfig/fontconfig"
        case .libsmb2:
            return "https://github.com/sahlberg/libsmb2"
        case .libx264:
            return "https://code.videolan.org/videolan/x264"
        case .libx265:
            return "https://bitbucket.org/multicoreware/x265_git/src/master/"
        case .libopus:
            return "https://github.com/xiph/opus"
        default:
            var value = rawValue
            if self != .libass, self != .libarchive, value.hasPrefix("lib") {
                value = String(value.dropFirst(3))
            }
            return "https://github.com/\(value)/\(value)"
        }
    }

    var isGPL: Bool {
        switch self {
        case .readline, .libsmbclient, .libx264, .libx265:
            return true
        default:
            return false
        }
    }

    var isFFmpegDependentLibrary: Bool {
        switch self {
        case .openssl, .readline, .nettle, .libmpv, .boringssl, .libpng, .libupnp, .libnfs, .libsmb2, .libarchive:
            return false
        default:
            if BaseBuild.disableGPL {
                return !isGPL
            }
            return true
        }
    }

    var build: BaseBuild {
        switch self {
        case .FFmpeg:
            return BuildFFMPEG()
        case .libfreetype:
            return BuildFreetype()
        case .libfribidi:
            return BuildFribidi()
        case .libharfbuzz:
            return BuildHarfbuzz()
        case .libass:
            return BuildASS()
        case .libpng:
            return BuildPng()
        case .libmpv:
            return BuildMPV()
        case .openssl:
            return BuildOpenSSL()
        case .libsrt:
            return BuildSRT()
        case .libsmbclient:
            return BuildSmbclient()
        case .gnutls:
            return BuildGnutls()
        case .libdav1d:
            return BuildDav1d()
        case .nettle:
            return BuildNettle()
        case .gmp:
            return BuildGmp()
        case .libtls:
            return BuildLibreSSL()
        case .libzvbi:
            return BuildZvbi()
        case .boringssl:
            return BuildBoringSSL()
        case .libplacebo:
            return BuildPlacebo()
        case .vulkan:
            return BuildVulkan()
        case .libshaderc:
            return BuildShaderc()
        case .libglslang:
            return BuildGlslang()
        case .readline:
            return BuildReadline()
        case .libdovi:
            return BuildDovi()
        case .lcms2:
            return BuildLittleCms()
        case .libupnp:
            return BuildUPnP()
        case .libnfs:
            return BuildNFS()
        case .libfontconfig:
            return BuildFontconfig()
        case .libbluray:
            return BuildBluray()
        case .libsmb2:
            return BuildSMB2()
        case .libx265:
            return BuildX265()
        case .libx264:
            return BuildX264()
        case .libarchive:
            return BuildArchive()
        case .libopus:
            return BuildOpus()
        }
    }
}

class BaseBuild {
    static var platforms = PlatformType.allCases
        .filter {
            ![.watchos, .watchsimulator, .android].contains($0)
        }

    static var notRecompile = false
    static var gitCloneAll = false
    static var disableGPL = false
    let library: Library
    var directoryURL: URL
    init(library: Library) {
        self.library = library
        directoryURL = URL.currentDirectory + "\(library.rawValue)-\(library.version)"
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            var arguments = ["clone", "--recurse-submodules"]
            if !BaseBuild.gitCloneAll {
                arguments.append(contentsOf: ["--depth", "1"])
            }
            arguments.append(contentsOf: ["--branch", library.version, library.url, directoryURL.path])
            try! Utility.launch(path: "/usr/bin/git", arguments: arguments)
        }
        let patch = URL.currentDirectory + "../Plugins/BuildFFmpeg/patch/\(library.rawValue)"
        if FileManager.default.fileExists(atPath: patch.path) {
            // 解决新增的文件，无法删除的问题
            _ = try? Utility.launch(path: "/usr/bin/git", arguments: ["checkout", "."], currentDirectoryURL: directoryURL)
            _ = try? Utility.launch(path: "/usr/bin/git", arguments: ["clean", "-f"], currentDirectoryURL: directoryURL)
            let fileNames = try! FileManager.default.contentsOfDirectory(atPath: patch.path).sorted()
            for fileName in fileNames {
                _ = try? Utility.launch(path: "/usr/bin/git", arguments: ["apply", "\((patch + fileName).path)"], currentDirectoryURL: directoryURL)
            }
        }
    }

    func platforms() -> [PlatformType] {
        BaseBuild.platforms
    }

    func buildALL() throws {
        for platform in platforms() {
            for arch in platform.architectures {
                let prefix = thinDir(platform: platform, arch: arch)
                if FileManager.default.fileExists(atPath: (prefix + "lib").path), BaseBuild.notRecompile {
                    continue
                }
                try? FileManager.default.removeItem(at: prefix)
                let buildURL = scratch(platform: platform, arch: arch)
                try? FileManager.default.removeItem(at: buildURL)
                try? FileManager.default.createDirectory(at: buildURL, withIntermediateDirectories: true, attributes: nil)
                try build(platform: platform, arch: arch, buildURL: buildURL)
            }
        }
        try createXCFramework()
    }

    func build(platform: PlatformType, arch: ArchType, buildURL: URL) throws {
        try? _ = Utility.launch(path: "/usr/bin/make", arguments: ["clean"], currentDirectoryURL: buildURL)
        try? _ = Utility.launch(path: "/usr/bin/make", arguments: ["distclean"], currentDirectoryURL: buildURL)
        let environ = environment(platform: platform, arch: arch)
        if FileManager.default.fileExists(atPath: (directoryURL + "meson.build").path) {
            if Utility.shell("which meson") == nil {
                Utility.shell("brew install meson")
            }
            let meson = Utility.shell("which meson", isOutput: true)!
            let crossFile = createMesonCrossFile(platform: platform, arch: arch)
            try Utility.launch(path: meson, arguments: ["setup", buildURL.path, "--cross-file=\(crossFile.path)"] + arguments(platform: platform, arch: arch), currentDirectoryURL: directoryURL, environment: environ)
            try Utility.launch(path: meson, arguments: ["compile", "--clean"], currentDirectoryURL: buildURL, environment: environ)
            try Utility.launch(path: meson, arguments: ["compile", "--verbose"], currentDirectoryURL: buildURL, environment: environ)
            try Utility.launch(path: meson, arguments: ["install"], currentDirectoryURL: buildURL, environment: environ)
        } else if FileManager.default.fileExists(atPath: (directoryURL + wafPath()).path) {
            let waf = (directoryURL + wafPath()).path
            try Utility.launch(path: waf, arguments: ["configure"] + arguments(platform: platform, arch: arch), currentDirectoryURL: directoryURL, environment: environ)
            var arguments = [String]()
            arguments.append(contentsOf: wafBuildArg())
            try Utility.launch(path: waf, arguments: arguments, currentDirectoryURL: directoryURL, environment: environ)
            arguments = ["install"]
            arguments.append(contentsOf: wafInstallArg())
            try Utility.launch(path: waf, arguments: arguments, currentDirectoryURL: directoryURL, environment: environ)
        } else {
            try configure(buildURL: buildURL, environ: environ, platform: platform, arch: arch)
            try Utility.launch(path: "/usr/bin/make", arguments: ["-j8"], currentDirectoryURL: buildURL, environment: environ)
            try Utility.launch(path: "/usr/bin/make", arguments: ["-j8", "install"], currentDirectoryURL: buildURL, environment: environ)
        }
    }

    func wafPath() -> String {
        "waf"
    }

    func wafBuildArg() -> [String] {
        ["build"]
    }

    func wafInstallArg() -> [String] {
        []
    }

    func configure(buildURL: URL, environ: [String: String], platform: PlatformType, arch: ArchType) throws {
        let makeLists = directoryURL + "CMakeLists.txt"
        if FileManager.default.fileExists(atPath: makeLists.path) {
            if Utility.shell("which cmake") == nil {
                Utility.shell("brew install cmake")
            }
            let cmake = Utility.shell("which cmake", isOutput: true)!
            let thinDirPath = thinDir(platform: platform, arch: arch).path
            var arguments = [
                makeLists.path,
                "-DCMAKE_VERBOSE_MAKEFILE=0",
                "-DCMAKE_BUILD_TYPE=\(Build.isDebug ? "Debug" : "Release")",
                "-DCMAKE_OSX_SYSROOT=\(platform.sdk.lowercased())",
                "-DCMAKE_OSX_ARCHITECTURES=\(arch.rawValue)",
                "-DCMAKE_INSTALL_PREFIX=\(thinDirPath)",
                "-DCMAKE_SYSTEM_PROCESSOR=\(arch.targetCpu)",
                "-DBUILD_SHARED_LIBS=0",
                "-DENABLE_SHARED=0",
            ]
            arguments.append(contentsOf: self.arguments(platform: platform, arch: arch))
            try Utility.launch(path: cmake, arguments: arguments, currentDirectoryURL: buildURL, environment: environ)
        } else {
            let configure = directoryURL + "configure"
            if !FileManager.default.fileExists(atPath: configure.path) {
                var bootstrap = directoryURL + "bootstrap"
                if !FileManager.default.fileExists(atPath: bootstrap.path) {
                    bootstrap = directoryURL + ".bootstrap"
                }
                if FileManager.default.fileExists(atPath: bootstrap.path) {
                    try Utility.launch(executableURL: bootstrap, arguments: [], currentDirectoryURL: directoryURL, environment: environ)
                } else {
                    let autogen = directoryURL + "autogen.sh"
                    if FileManager.default.fileExists(atPath: autogen.path) {
                        var environ = environ
                        environ["NOCONFIGURE"] = "1"
                        try Utility.launch(executableURL: autogen, arguments: [], currentDirectoryURL: directoryURL, environment: environ)
                    }
                }
            }
            try Utility.launch(executableURL: configure, arguments: arguments(platform: platform, arch: arch), currentDirectoryURL: buildURL, environment: environ)
        }
    }

    func environment(platform: PlatformType, arch: ArchType) -> [String: String] {
        let cFlags = cFlags(platform: platform, arch: arch).joined(separator: " ")
        let ldFlags = ldFlags(platform: platform, arch: arch).joined(separator: " ")
        let pkgConfigPath = platform.pkgConfigPath(arch: arch)
        let pkgConfigPathDefault = Utility.shell("pkg-config --variable pc_path pkg-config", isOutput: true)!
        let path = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:"
        return [
            "LC_CTYPE": "C",
            "CC": platform.cc,
            "CXX": platform.cc + "++",
            // "SDKROOT": platform.sdk.lowercased(),
            "CURRENT_ARCH": arch.rawValue,
            "CFLAGS": cFlags,
            // makefile can't use CPPFLAGS
//            "CPPFLAGS": cFlags,
            // 这个要加，不然cmake在编译maccatalyst 会有问题
            "CXXFLAGS": cFlags,
            "LDFLAGS": ldFlags,
//            "PKG_CONFIG_PATH": pkgConfigPath,
            "PKG_CONFIG_LIBDIR": pkgConfigPath + pkgConfigPathDefault,
            "PATH": path,
        ]
    }

    func cFlags(platform: PlatformType, arch: ArchType) -> [String] {
        var cFlags = platform.cFlags(arch: arch)
        let librarys = flagsDependencelibrarys()
        for library in librarys {
            let path = thinDir(library: library, platform: platform, arch: arch)
            if FileManager.default.fileExists(atPath: path.path) {
                if library == .libsmbclient {
                    cFlags.append("-I\(path.path)/include/samba-4.0")
                } else {
                    cFlags.append("-I\(path.path)/include")
                }
            }
        }
        return cFlags
    }

    func ldFlags(platform: PlatformType, arch: ArchType) -> [String] {
        var ldFlags = platform.ldFlags(arch: arch)
        let librarys = flagsDependencelibrarys()
        for library in librarys {
            let path = thinDir(library: library, platform: platform, arch: arch)
            if FileManager.default.fileExists(atPath: path.path) {
                var libname = library.rawValue
                if libname.hasPrefix("lib") {
                    libname = String(libname.dropFirst(3))
                }
                ldFlags.append("-L\(path.path)/lib")
                ldFlags.append("-l\(libname)")
                if library == .nettle {
                    ldFlags.append("-lhogweed")
                } else if library == .gnutls {
                    ldFlags.append(contentsOf: ["-framework", "Security", "-framework", "CoreFoundation"])
                } else if library == .libsmbclient {
                    ldFlags.append(contentsOf: ["-lresolv", "-lpthread", "-lz", "-liconv"])
                }
            }
        }
        return ldFlags
    }

    func flagsDependencelibrarys() -> [Library] {
        []
    }

    func arguments(platform _: PlatformType, arch _: ArchType) -> [String] { [] }

    func frameworks() throws -> [String] {
        [library.rawValue]
    }

    func createXCFramework() throws {
        let frameworks = try frameworks()
        for framework in frameworks {
            var arguments = ["-create-xcframework"]
            for platform in PlatformType.allCases {
                if let frameworkPath = try createFramework(framework: framework, platform: platform) {
                    if isFramework {
                        arguments.append("-framework")
                        arguments.append(frameworkPath)
                    } else {
                        arguments.append("-library")
                        arguments.append(frameworkPath + "/" + framework + ".a")
                        arguments.append("-headers")
                        arguments.append(frameworkPath + "/Headers")
                    }
                }
            }
            arguments.append("-output")
            let XCFrameworkFile = URL.currentDirectory + ["../Sources", framework + ".xcframework"]
            arguments.append(XCFrameworkFile.path)
            if FileManager.default.fileExists(atPath: XCFrameworkFile.path) {
                try FileManager.default.removeItem(at: XCFrameworkFile)
            }
            try Utility.launch(path: "/usr/bin/xcodebuild", arguments: arguments)
        }
    }

    private func createFramework(framework: String, platform: PlatformType) throws -> String? {
        let frameworkDir = URL.currentDirectory + [library.rawValue, platform.rawValue, "\(framework).framework"]
        if !platforms().contains(platform) {
            if FileManager.default.fileExists(atPath: frameworkDir.path) {
                return frameworkDir.path
            } else {
                return nil
            }
        }
        try? FileManager.default.removeItem(at: frameworkDir)
        try FileManager.default.createDirectory(at: frameworkDir, withIntermediateDirectories: true, attributes: nil)
        try createFrameworkInclude(framework: framework, platform: platform, frameworkDir: frameworkDir)
        try createFrameworkLib(framework: framework, platform: platform, frameworkDir: frameworkDir)
        if !isFramework {
            return frameworkDir.path
        }
        try FileManager.default.createDirectory(at: frameworkDir + "Modules", withIntermediateDirectories: true, attributes: nil)
        var modulemap = """
        framework module \(framework) [system] {
            umbrella "."

        """
        for header in frameworkExcludeHeaders(framework) {
            modulemap += """
                exclude header "\(header).h"

            """
        }
        modulemap += """
            export *
        }
        """
        FileManager.default.createFile(atPath: frameworkDir.path + "/Modules/module.modulemap", contents: modulemap.data(using: .utf8), attributes: nil)
        var infoPath = frameworkDir
        if platform == .macos || platform == .maccatalyst {
            infoPath = infoPath + "Resources"
            try FileManager.default.createDirectory(at: infoPath, withIntermediateDirectories: true, attributes: nil)
        }
        createPlist(path: infoPath + "Info.plist", name: framework, minVersion: platform.minVersion, platform: platform.sdk)
        if platform == .macos || platform == .maccatalyst {
            try createFrameworkVersions(url: frameworkDir)
        }
        return frameworkDir.path
    }

    func createFrameworkInclude(framework: String, platform: PlatformType, frameworkDir: URL) throws {
        if let arch = platform.architectures.first {
            let prefix = thinDir(platform: platform, arch: arch)
            var headerURL: URL = prefix + "include" + framework
            if !FileManager.default.fileExists(atPath: headerURL.path) {
                headerURL = prefix + "include"
            }
            try? FileManager.default.copyItem(at: headerURL, to: frameworkDir + "Headers")
        }
    }

    func createFrameworkLib(framework: String, platform: PlatformType, frameworkDir: URL) throws {
        var arguments = ["-create"]
        for arch in platform.architectures {
            let prefix = thinDir(platform: platform, arch: arch)
            let libname = framework.hasPrefix("lib") || framework.hasPrefix("Lib") ? framework : "lib" + framework
            var libPath = prefix + ["lib", "\(libname).a"]
            if !FileManager.default.fileExists(atPath: libPath.path) {
                libPath = prefix + ["lib", "\(libname).dylib"]
            }
            arguments.append(libPath.path)
        }
        arguments.append("-output")
        var output = (frameworkDir + framework).path
        if !isFramework {
            output += ".a"
        }
        arguments.append(output)
        try Utility.launch(path: "/usr/bin/lipo", arguments: arguments)
    }

    private func createFrameworkVersions(url: URL) throws {
        let version = url + "Versions/A"
        try FileManager.default.createDirectory(at: version, withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createSymbolicLink(atPath: (url + "Versions/Current").path, withDestinationPath: "A")
        try FileManager.default.moveItem(at: url + "Modules", to: version + "Modules")
        try FileManager.default.createSymbolicLink(atPath: (url + "Modules").path, withDestinationPath: "Versions/Current/Modules")
        try FileManager.default.moveItem(at: url + "Headers", to: version + "Headers")
        try FileManager.default.createSymbolicLink(atPath: (url + "Headers").path, withDestinationPath: "Versions/Current/Headers")
        try FileManager.default.moveItem(at: url + "Resources", to: version + "Resources")
        try FileManager.default.createSymbolicLink(atPath: (url + "Resources").path, withDestinationPath: "Versions/Current/Resources")
        let name = String(url.lastPathComponent.split(separator: ".").first ?? "")
        try FileManager.default.moveItem(at: url + name, to: version + name)
        try FileManager.default.createSymbolicLink(atPath: (url + name).path, withDestinationPath: "Versions/Current/\(name)")
    }

    var isFramework: Bool {
        true
    }

    func thinDir(library: Library, platform: PlatformType, arch: ArchType) -> URL {
        URL.currentDirectory + [library.rawValue, platform.rawValue, "thin", arch.rawValue]
    }

    func thinDir(platform: PlatformType, arch: ArchType) -> URL {
        thinDir(library: library, platform: platform, arch: arch)
    }

    func scratch(platform: PlatformType, arch: ArchType) -> URL {
        URL.currentDirectory + [library.rawValue, platform.rawValue, "scratch", arch.rawValue]
    }

    func frameworkExcludeHeaders(_: String) -> [String] {
        []
    }

    private func createPlist(path: URL, name: String, minVersion _: String, platform: String) {
        let identifier = name.replacingOccurrences(of: "_", with: "-")
        let minVersion = "100"
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>en</string>
        <key>CFBundleExecutable</key>
        <string>\(name)</string>
        <key>CFBundleIdentifier</key>
        <string>\(identifier)</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>\(name)</string>
        <key>CFBundlePackageType</key>
        <string>FMWK</string>
        <key>CFBundleShortVersionString</key>
        <string>1.0</string>
        <key>CFBundleVersion</key>
        <string>1</string>
        <key>MinimumOSVersion</key>
        <string>\(minVersion)</string>
        <key>CFBundleSupportedPlatforms</key>
        <array>
        <string>\(platform)</string>
        </array>
        </dict>
        </plist>
        """
        FileManager.default.createFile(atPath: path.path, contents: content.data(using: .utf8), attributes: nil)
    }

    private func createMesonCrossFile(platform: PlatformType, arch: ArchType) -> URL {
        let url = scratch(platform: platform, arch: arch)
        let crossFile = url + "crossFile.meson"
        let prefix = thinDir(platform: platform, arch: arch)
        let cFlags = cFlags(platform: platform, arch: arch).map {
            "'" + $0 + "'"
        }.joined(separator: ", ")
        let ldFlags = ldFlags(platform: platform, arch: arch).map {
            "'" + $0 + "'"
        }.joined(separator: ", ")
        let content = """
        [binaries]
        c = '/usr/bin/clang'
        cpp = '/usr/bin/clang++'
        objc = '/usr/bin/clang'
        objcpp = '/usr/bin/clang++'
        ar = '\(platform.xcrunFind(tool: "ar"))'
        strip = '\(platform.xcrunFind(tool: "strip"))'
        pkgconfig = 'pkg-config'

        [properties]
        has_function_printf = true
        has_function_hfkerhisadf = false

        [host_machine]
        system = 'darwin'
        subsystem = '\(platform.mesonSubSystem)'
        kernel = 'xnu'
        cpu_family = '\(arch.cpuFamily)'
        cpu = '\(arch.targetCpu)'
        endian = 'little'

        [built-in options]
        default_library = 'static'
        buildtype = '\(Build.isDebug ? "debug" : "release")'
        prefix = '\(prefix.path)'
        c_args = [\(cFlags)]
        cpp_args = [\(cFlags)]
        objc_args = [\(cFlags)]
        objcpp_args = [\(cFlags)]
        c_link_args = [\(ldFlags)]
        cpp_link_args = [\(ldFlags)]
        objc_link_args = [\(ldFlags)]
        objcpp_link_args = [\(ldFlags)]
        """
        FileManager.default.createFile(atPath: crossFile.path, contents: content.data(using: .utf8), attributes: nil)
        return crossFile
    }
}

enum PlatformType: String, CaseIterable {
    case macos, ios, isimulator, tvos, tvsimulator, xros, xrsimulator, maccatalyst, watchos, watchsimulator, android
    var minVersion: String {
        switch self {
        case .ios, .isimulator:
            return "13.0"
        case .tvos, .tvsimulator:
            return "13.0"
        case .macos:
            return "11.0"
        case .maccatalyst:
            return "14.0"
        case .watchos, .watchsimulator:
            return "6.0"
        case .xros, .xrsimulator:
            return "1.0"
        case .android:
            return "24"
        }
    }

    var name: String {
        switch self {
        case .ios, .tvos, .macos, .android:
            return rawValue
        case .tvsimulator:
            return "tvossim"
        case .isimulator:
            return "iossim"
        case .maccatalyst:
            return "maccat"
        case .watchos:
            return "watchos"
        case .watchsimulator:
            return "watchossim"
        case .xros:
            return "visionos"
        case .xrsimulator:
            return "visionossim"
        }
    }

    var frameworkName: String {
        switch self {
        case .ios:
            return "ios-arm64"
        case .maccatalyst:
            return "ios-arm64_x86_64-maccatalyst"
        case .isimulator:
            return "ios-arm64_x86_64-simulator"
        case .macos:
            return "macos-arm64_x86_64"
        case .tvos:
            return "tvos-arm64_arm64e"
        case .tvsimulator:
            return "tvos-arm64_x86_64-simulator"
        case .watchos:
            return "watchos-arm64"
        case .watchsimulator:
            return "watchossim"
        case .xros:
            return "xros-arm64"
        case .xrsimulator:
            return "xros-arm64_x86_64-simulator"
        case .android:
            return "android"
        }
    }

    var architectures: [ArchType] {
        switch self {
        case .ios, .xros, .tvos, .watchos, .android:
            return [.arm64]
        case .isimulator, .tvsimulator, .watchsimulator:
            return [.arm64, .x86_64]
        case .xrsimulator:
            return [.arm64]
        case .macos:
            #if arch(x86_64)
            return [.x86_64, .arm64]
            #else
            return [.arm64, .x86_64]
            #endif
        case .maccatalyst:
            return [.arm64, .x86_64]
        }
    }

    var mesonSubSystem: String {
        switch self {
        case .isimulator:
            return "ios-simulator"
        case .tvsimulator:
            return "tvos-simulator"
        case .xrsimulator:
            return "xros-simulator"
        case .watchsimulator:
            return "watchos-simulator"
        default:
            return rawValue
        }
    }

    var cc: String {
        if self == .android {
            return androidToolchainPath + "/bin/aarch64-linux-android\(minVersion)-clang"
        } else {
            return "/usr/bin/clang"
        }
    }

    func host(arch: ArchType) -> String {
        switch self {
        case .macos:
            return "\(arch.targetCpu)-apple-darwin"
        case .ios, .tvos, .watchos, .xros:
            return "\(arch.targetCpu)-\(rawValue)-darwin"
        case .isimulator, .maccatalyst:
            return PlatformType.ios.host(arch: arch)
        case .tvsimulator:
            return PlatformType.tvos.host(arch: arch)
        case .watchsimulator:
            return PlatformType.watchos.host(arch: arch)
        case .xrsimulator:
            return PlatformType.xros.host(arch: arch)
        case .android:
            return "aarch64-linux-android"
        }
    }

    func deploymentTarget(arch: ArchType) -> String {
        switch self {
        case .ios, .tvos, .watchos, .macos, .xros:
            return "\(arch.targetCpu)-apple-\(rawValue)\(minVersion)"
        case .maccatalyst:
            return "\(arch.targetCpu)-apple-ios\(minVersion)-macabi"
        case .isimulator:
            return PlatformType.ios.deploymentTarget(arch: arch) + "-simulator"
        case .tvsimulator:
            return PlatformType.tvos.deploymentTarget(arch: arch) + "-simulator"
        case .watchsimulator:
            return PlatformType.watchos.deploymentTarget(arch: arch) + "-simulator"
        case .xrsimulator:
            return PlatformType.xros.deploymentTarget(arch: arch) + "-simulator"
        case .android:
            return ""
        }
    }

    private var osVersionMin: String {
        switch self {
        case .ios, .tvos, .watchos:
            return "-m\(rawValue)-version-min=\(minVersion)"
        case .macos:
            return "-mmacosx-version-min=\(minVersion)"
        case .isimulator:
            return "-mios-simulator-version-min=\(minVersion)"
        case .tvsimulator:
            return "-mtvos-simulator-version-min=\(minVersion)"
        case .watchsimulator:
            return "-mwatchos-simulator-version-min=\(minVersion)"
        case .maccatalyst, .xros, .xrsimulator, .android:
            return ""
        }
    }

    var sdk: String {
        switch self {
        case .ios:
            return "iPhoneOS"
        case .isimulator:
            return "iPhoneSimulator"
        case .tvos:
            return "AppleTVOS"
        case .tvsimulator:
            return "AppleTVSimulator"
        case .watchos:
            return "WatchOS"
        case .watchsimulator:
            return "WatchSimulator"
        case .xros:
            return "XROS"
        case .xrsimulator:
            return "XRSimulator"
        case .macos, .maccatalyst:
            return "MacOSX"
        case .android:
            return ""
        }
    }

    func ldFlags(arch: ArchType) -> [String] {
        // ldFlags的关键参数要跟cFlags保持一致，不然会在ld的时候不通过。
        if self == .android {
            return [
                //                "-march=armv8-a",
//                    "-L\(toolchainPath)/sysroot/usr/lib/\(host(arch: arch))/\(minVersion)",
//                    "-L\(toolchainPath)/lib",
            ]
        }
        let isysroot = isysroot
        var ldFlags = ["-arch", arch.rawValue, "-isysroot", isysroot, "-target", deploymentTarget(arch: arch)]
        if self == .maccatalyst {
            ldFlags.append("-iframework")
            ldFlags.append("\(isysroot)/System/iOSSupport/System/Library/Frameworks")
        }
        return ldFlags
    }

    func cFlags(arch: ArchType) -> [String] {
        var cflags = ldFlags(arch: arch)
        cflags.append(osVersionMin)
        // 不能同时有强符合和弱符号出现
        cflags.append("-fno-common")
//        if self == .android {
//            cflags.append("-fstrict-aliasing")
//            cflags.append("-DANDROID_NDK")
//            cflags.append("-fPIC")
//            cflags.append("-DANDROID")
//        }
        return cflags
    }

    var isysroot: String {
        if self == .android {
            return androidToolchainPath + "/sysroot"
        }
        return xcrunFind(tool: "--show-sdk-path")
    }

    var androidToolchainPath: String {
        let root = ProcessInfo.processInfo.environment["ANDROID_NDK_HOME"] ?? ""
//        let toolchain = "darwin-arm64"
        let toolchain = "darwin-x86_64"
        let toolchainPath = "\(root)/toolchains/llvm/prebuilt/\(toolchain)"
        return toolchainPath
    }

    func xcrunFind(tool: String) -> String {
        try! Utility.launch(path: "/usr/bin/xcrun", arguments: ["--sdk", sdk.lowercased(), "--find", tool], isOutput: true)
    }

    func pkgConfigPath(arch: ArchType) -> String {
        var pkgConfigPath = ""
        for lib in Library.allCases {
            let path = URL.currentDirectory + [lib.rawValue, rawValue, "thin", arch.rawValue]
            if FileManager.default.fileExists(atPath: path.path) {
                pkgConfigPath += "\(path.path)/lib/pkgconfig:"
            }
        }
        return pkgConfigPath
    }
}

enum ArchType: String, CaseIterable {
    // swiftlint:disable identifier_name
    // arm64e 还没ABI。所以第三方库是无法使用的。
    case arm64, x86_64, arm64e
    // swiftlint:enable identifier_name
    var executable: Bool {
        guard let architecture = Bundle.main.executableArchitectures?.first?.intValue else {
            return false
        }
        // NSBundleExecutableArchitectureARM64
        if architecture == 0x0100_000C, self == .arm64 || self == .arm64e {
            return true
        } else if architecture == NSBundleExecutableArchitectureX86_64, self == .x86_64 {
            return true
        }
        return false
    }

    var cpuFamily: String {
        switch self {
        case .arm64, .arm64e:
            return "aarch64"
        case .x86_64:
            return "x86_64"
        }
    }

    var targetCpu: String {
        switch self {
        case .arm64, .arm64e:
            return "arm64"
        case .x86_64:
            return "x86_64"
        }
    }
}

enum Utility {
    @discardableResult
    static func shell(_ command: String, isOutput: Bool = false, currentDirectoryURL: URL? = nil, environment: [String: String] = [:]) -> String? {
        do {
            return try launch(executableURL: URL(fileURLWithPath: "/bin/zsh"), arguments: ["-c", command], isOutput: isOutput, currentDirectoryURL: currentDirectoryURL, environment: environment)
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }

    @discardableResult
    static func launch(path: String, arguments: [String], isOutput: Bool = false, currentDirectoryURL: URL? = nil, environment: [String: String] = [:]) throws -> String {
        try launch(executableURL: URL(fileURLWithPath: path), arguments: arguments, isOutput: isOutput, currentDirectoryURL: currentDirectoryURL, environment: environment)
    }

    @discardableResult
    static func launch(executableURL: URL, arguments: [String], isOutput: Bool = false, currentDirectoryURL: URL? = nil, environment: [String: String] = [:]) throws -> String {
        #if os(macOS)
        let task = Process()
        var environment = environment
        if environment["PATH"] == nil {
            environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        }
        task.environment = environment
        var standardOutput: FileHandle?
        var log = executableURL.path + " " + arguments.joined(separator: " ") + "\n environment: " + environment.description
        if isOutput {
            let pipe = Pipe()
            task.standardOutput = pipe
            standardOutput = pipe.fileHandleForReading
        } else if var logURL = currentDirectoryURL {
            logURL = logURL.appendingPathExtension("log")
            log += " logFile: \(logURL)"
            if !FileManager.default.fileExists(atPath: logURL.path) {
                FileManager.default.createFile(atPath: logURL.path, contents: nil)
            }
            let standardOutput = try FileHandle(forWritingTo: logURL)
            if #available(macOS 10.15.4, *) {
                try standardOutput.seekToEnd()
            }
            task.standardOutput = standardOutput
        }
        print(log)
        task.arguments = arguments
        task.currentDirectoryURL = currentDirectoryURL
        task.executableURL = executableURL
        try task.run()
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            if isOutput, let standardOutput {
                let data = standardOutput.readDataToEndOfFile()
                let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines) ?? ""
                print(result)
                return result
            } else {
                return ""
            }
        } else {
            throw NSError(domain: "fail", code: Int(task.terminationStatus))
        }
        #else
        return ""
        #endif
    }
}

extension URL {
    static var currentDirectory: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    static func + (left: URL, right: String) -> URL {
        var url = left
        url.appendPathComponent(right)
        return url
    }

    static func + (left: URL, right: [String]) -> URL {
        var url = left
        for item in right {
            url.appendPathComponent(item)
        }
        return url
    }
}

class BuildUPnP: BaseBuild {
    init() {
        super.init(library: .libupnp)
    }
}

class BuildNFS: BaseBuild {
    override var isFramework: Bool {
        false
    }

    init() {
        super.init(library: .libnfs)
    }
}

class BuildSMB2: BaseBuild {
    override var isFramework: Bool {
        false
    }

    init() {
        super.init(library: .libsmb2)
    }
}

class BuildArchive: BaseBuild {
    init() {
        super.init(library: .libarchive)
    }

    override func arguments(platform _: PlatformType, arch _: ArchType) -> [String] {
        var arg = ["-DENABLE_TEST=0"]
        return arg
    }
}

class BuildX265: BaseBuild {
    init() {
        super.init(library: .libx265)
        directoryURL = directoryURL + "source"
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        var arg = ["-DSTATIC_LINK_CRT=1",
                   "-DENABLE_PIC=1",
                   "-DENABLE_CLI=0",
                   "-DHIGH_BIT_DEPTH=1"]
        if platform == .maccatalyst, arch == .x86_64 {
            arg.append(contentsOf: ["-DENABLE_ASSEMBLY=0", "-DCROSS_COMPILE_ARM=0"])
        } else if arch == .x86_64 {
            arg.append(contentsOf: ["-DENABLE_ASSEMBLY=1", "-DCROSS_COMPILE_ARM=0"])
        } else {
            arg.append(contentsOf: ["-DENABLE_ASSEMBLY=0", "-DCROSS_COMPILE_ARM=1"])
        }
        return arg
    }
}

class BuildX264: BaseBuild {
    init() {
        super.init(library: .libx264)
    }

    override func environment(platform: PlatformType, arch: ArchType) -> [String: String] {
        var env = super.environment(platform: platform, arch: arch)
        if arch == .x86_64 {
            env["AS"] = "nasm"
        }
        return env
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        var arg = ["--enable-static",
                   "--enable-pic",
                   "--host=\(platform.host(arch: arch))",
                   "--prefix=\(thinDir(platform: platform, arch: arch).path)",
                   "--sysroot=\(platform.isysroot)",
                   "--disable-cli"]
        if arch == .x86_64 {
            arg.append("--disable-asm")
        }
        return arg
    }
}

class BuildOpus: BaseBuild {
    init() {
        super.init(library: .libopus)
        let autogen = directoryURL + "autogen.sh"
        if FileManager.default.fileExists(atPath: autogen.path) {
            try? Utility.launch(executableURL: autogen, arguments: [], currentDirectoryURL: directoryURL, environment: [:])
        }
    }
}
