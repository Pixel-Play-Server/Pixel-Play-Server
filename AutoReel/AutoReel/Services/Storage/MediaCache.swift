import Foundation

enum MediaCache {
    private static var baseDirectory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AutoReel", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func projectDirectory(id: String) -> URL {
        let dir = baseDirectory.appendingPathComponent(id, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func write(data: Data, projectID: String, filename: String) throws -> URL {
        let url = projectDirectory(id: projectID).appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func write(text: String, projectID: String, filename: String) throws -> URL {
        try write(data: Data(text.utf8), projectID: projectID, filename: filename)
    }

    static func clearProject(id: String) {
        let dir = projectDirectory(id: id)
        try? FileManager.default.removeItem(at: dir)
    }
}
