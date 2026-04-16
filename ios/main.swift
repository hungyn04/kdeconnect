import Foundation
import UIKit

var trollstore = false
let configDir = "/var/mobile/kdeconnect"
let typePath = "\(configDir)/type"
let namePath = "\(configDir)/name"
let trustedPath = "\(configDir)/trusted"

if CommandLine.argc > 1 {
    print("usage: \(CommandLine.arguments[0]) [--trollstore]")
    exit(1)
}

var devicetype = K_CONNECT_FFI_DEVICE_TYPE_PHONE

func directoryExistsAtPath(_ path: String) -> Bool {
    var isDirectory : ObjCBool = true
    let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
    return exists && isDirectory.boolValue
}

if !directoryExistsAtPath(configDir) {
    try FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)
}

if !FileManager.default.fileExists(atPath: typePath) {
    try "phone".write(toFile: typePath, atomically: true, encoding: .utf8)
}

if !FileManager.default.fileExists(atPath: namePath) {
    try UIDevice.current.name.write(toFile: namePath, atomically: true, encoding: .utf8)
}

if !FileManager.default.fileExists(atPath: trustedPath) {
    try "".write(toFile: trustedPath, atomically: true, encoding: .utf8)
}

var devicetypestr = try String(contentsOfFile: typePath).trimmingCharacters(in: .whitespacesAndNewlines)

switch devicetypestr {
    case "phone":
        devicetype = K_CONNECT_FFI_DEVICE_TYPE_PHONE
        break
    case "tablet":
        devicetype = K_CONNECT_FFI_DEVICE_TYPE_TABLET
        break
    case "tv":
        devicetype = K_CONNECT_FFI_DEVICE_TYPE_TV
        break
    case "desktop":
        devicetype = K_CONNECT_FFI_DEVICE_TYPE_DESKTOP
        break
    case "laptop":
        devicetype = K_CONNECT_FFI_DEVICE_TYPE_LAPTOP
        break
    default:
        print("invalid device type: \(devicetypestr)")
        exit(1)
}

var name = try String(contentsOfFile: namePath).trimmingCharacters(in: .whitespacesAndNewlines)
if name.isEmpty {
    name = UIDevice.current.name
    try name.write(toFile: namePath, atomically: true, encoding: .utf8)
}

// FIXME: We need to move more stuff over to Swift!
objc_main(name, KConnectFfiDeviceType_t(devicetype.rawValue))
