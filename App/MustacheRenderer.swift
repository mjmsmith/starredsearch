// Copied from https://github.com/qutheory/vapor-zewo-mustache.

import Foundation
import Vapor
import Mustache

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

public class MustacheRenderer: Vapor.RenderDriver {
    static let currentName = "__current"

    public var includes: [String: String]
    public init(files: [String: String] = [:]) {
        includes = [:]

        for (name, file) in files {
            do {
                let bytes = try readBytesFromFile(path: file)

                var signedData = bytes.map { byte in
                    return Int8(byte)
                }

                signedData.append(0)
                includes[name] = String(validatingUTF8: signedData)
            } catch {
                Log.warning("Could not open file \(file). Error: \(error)")        
            }
        }
    }

    public func render(template: String, context: [String: Any]) throws -> String {
        var templates = includes
        templates[MustacheRenderer.currentName] = template
        let repository = TemplateRepository(templates: templates)

        let renderer = try repository.template(named: MustacheRenderer.currentName)

        let result = try renderer.render(box: context.mustacheBox)
        return result
    }

    enum Error: ErrorProtocol {
        case CouldNotOpenFile
        case Unreadable
    }

    func readBytesFromFile(path: String) throws -> [UInt8] {
        let fd = open(path, O_RDONLY);

        if fd < 0 {
            throw Error.CouldNotOpenFile
        }
        defer {
            close(fd)
        }

        var info = stat()
        let ret = withUnsafeMutablePointer(&info) { infoPointer -> Bool in
            if fstat(fd, infoPointer) < 0 {
                return false
            }
            return true
        }
        
        if !ret {
            throw Error.Unreadable
        }
        
        let length = Int(info.st_size)
        
        let rawData = malloc(length)
        var remaining = Int(info.st_size)
        var total = 0
        while remaining > 0 {
            let advanced = rawData.advanced(by: total)
            
            let amt = read(fd, advanced, remaining)
            if amt < 0 {
                break
            }
            remaining -= amt
            total += amt
        }

        if remaining != 0 {
            throw Error.Unreadable
        }

        //thanks @Danappelxx
        let data = UnsafeMutablePointer<UInt8>(rawData)
        let buffer = UnsafeMutableBufferPointer<UInt8>(start: data, count: length)
        return Array(buffer)
    }

}


