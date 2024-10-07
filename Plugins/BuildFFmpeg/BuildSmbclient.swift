//
//  BuildSmbclient.swift
//
//
//  Created by kintan on 12/26/23.
//

import Foundation

///
/// https://github.com/xbmc/xbmc/blob/8d852242b8fed6fc99132c5428e1c703970f7201/tools/depends/target/samba-gplv3/Makefile
class BuildSmbclient: BaseBuild {
    init() {
        super.init(library: .libsmbclient)
    }

    override func wafPath() -> String {
        "buildtools/bin/waf"
    }

    override func cFlags(platform: PlatformType, arch: ArchType) -> [String] {
        var cFlags = super.cFlags(platform: platform, arch: arch)
        cFlags.append("-Wno-error=implicit-function-declaration")
        return cFlags
    }

    override func environment(platform: PlatformType, arch: ArchType) -> [String: String] {
        var env = super.environment(platform: platform, arch: arch)
        env["PATH"]? += (":" + (URL.currentDirectory + "../Plugins/BuildFFmpeg/\(library.rawValue)/bin").path + ":" + (directoryURL + "buildtools/bin").path)
        env["PYTHONHASHSEED"] = "1"
        env["WAF_MAKE"] = "1"
        return env
    }

    override func wafBuildArg() -> [String] {
        ["--targets=smbclient"]
    }

    override func wafInstallArg() -> [String] {
        ["--targets=smbclient"]
    }

    override func build(platform: PlatformType, arch: ArchType, buildURL: URL) throws {
        try super.build(platform: platform, arch: arch, buildURL: buildURL)
        try FileManager.default.copyItem(at: directoryURL + "bin/default/source3/libsmb/libsmbclient.a", to: thinDir(platform: platform, arch: arch) + "lib/libsmbclient.a")
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        var arg =
            [
                "--without-cluster-support",
                "--disable-rpath",
                "--without-ldap",
                "--without-pam",
                "--enable-fhs",
                "--without-winbind",
                "--without-ads",
                "--disable-avahi",
                "--disable-cups",
                "--without-gettext",
                "--without-ad-dc",
                "--without-acl-support",
                "--without-utmp",
                "--disable-iprint",
                "--nopyc",
                "--nopyo",
                "--disable-python",
                "--disable-symbol-versions",
                "--without-json",
                "--without-libarchive",
                "--without-regedit",
                "--without-lttng",
                "--without-gpgme",
                "--disable-cephfs",
                "--disable-glusterfs",
                "--without-syslog",
                "--without-quotas",
                "--bundled-libraries=ALL",
                "--with-static-modules=!vfs_snapper,ALL",
                "--nonshared-binary=smbtorture,smbd/smbd,client/smbclient",
                "--builtin-libraries=!smbclient,!smbd_base,!smbstatus,ALL",
                "--host=\(platform.host(arch: arch))",
                "--prefix=\(thinDir(platform: platform, arch: arch).path)",
            ]
        arg.append("--cross-compile")
        arg.append("--cross-answers=cross-answers.txt")
        return arg
    }
}

class BuildReadline: BaseBuild {
    init() {
        super.init(library: .readline)
    }

    // readline 只是在编译的时候需要用到。外面不需要用到
    override func frameworks() throws -> [String] {
        []
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        [
            "--enable-static",
            "--disable-shared",
            "--host=\(platform.host(arch: arch))",
            "--prefix=\(thinDir(platform: platform, arch: arch).path)",
        ]
    }
}
