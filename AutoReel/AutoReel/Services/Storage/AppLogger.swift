import Foundation
import UIKit

enum AppLogger {
    private static let queue = DispatchQueue(label: "com.autoreel.logger", qos: .utility)
    private static let maxLogBytes = 2_000_000

    static var logsDirectoryURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = documents.appendingPathComponent("AutoReel/logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static var mainLogURL: URL {
        logsDirectoryURL.appendingPathComponent("app.log")
    }

    static var filesAppPathHint: String {
        "Archivos → En mi iPhone → AutoReel → AutoReel/logs/app.log"
    }

    static func install() {
        rotateIfNeeded()
        log("=== AutoReel iniciando ===", level: "START")
        logStartupContext()
        installExceptionHandler()
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            log("App en segundo plano", level: "LIFECYCLE")
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            log("App terminando", level: "LIFECYCLE")
        }
    }

    static func log(
        _ message: String,
        level: String = "INFO",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        let timestamp = isoFormatter.string(from: Date())
        let entry = "[\(timestamp)] [\(level)] [\(fileName):\(line) \(function)] \(message)\n"
        queue.async {
            appendSync(entry)
        }
    }

    static func error(
        _ message: String,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var text = message
        if let error {
            text += " | \(error.localizedDescription)"
        }
        log(text, level: "ERROR", file: file, function: function, line: line)
    }

    static func clearLogs() {
        queue.sync {
            let directory = logsDirectoryURL
            guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
                return
            }
            for file in files where file.pathExtension == "log" {
                try? FileManager.default.removeItem(at: file)
            }
            appendSync("[\(isoFormatter.string(from: Date()))] [INFO] Logs borrados por el usuario\n")
        }
    }

    static func recentLogText(maxCharacters: Int = 12_000) -> String {
        queue.sync {
            guard let data = try? Data(contentsOf: mainLogURL),
                  let text = String(data: data, encoding: .utf8) else {
                return "Sin logs todavía."
            }
            if text.count <= maxCharacters { return text }
            return "…(truncado)\n" + String(text.suffix(maxCharacters))
        }
    }

    // MARK: - Private

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func logStartupContext() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let device = UIDevice.current
        log("Versión \(version) (\(build)) | iOS \(device.systemVersion) | \(device.model)")
        log("Ruta logs: \(mainLogURL.path)")
        log("Acceso Files: \(filesAppPathHint)")

        #if canImport(ffmpegkit)
        log("FFmpegKit: módulo disponible en compilación")
        #else
        log("FFmpegKit: NO disponible en compilación", level: "WARN")
        #endif

        if let frameworksPath = Bundle.main.privateFrameworksPath {
            let contents = (try? FileManager.default.contentsOfDirectory(atPath: frameworksPath)) ?? []
            log("Frameworks embebidos (\(contents.count)): \(contents.sorted().joined(separator: ", "))")
        } else {
            log("Sin carpeta Frameworks en el bundle", level: "WARN")
        }
    }

    private static func installExceptionHandler() {
        NSSetUncaughtExceptionHandler(AppLoggerUncaughtExceptionHandler)
    }

    private static func rotateIfNeeded() {
        queue.sync {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: mainLogURL.path),
                  let size = attributes[.size] as? Int,
                  size > maxLogBytes else {
                return
            }
            let backup = logsDirectoryURL.appendingPathComponent("app.old.log")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: mainLogURL, to: backup)
            appendSync("[\(isoFormatter.string(from: Date()))] [INFO] Log rotado (app.old.log)\n")
        }
    }

    fileprivate static func appendSync(_ text: String) {
        let url = mainLogURL
        if FileManager.default.fileExists(atPath: url.path) {
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            try? handle.seekToEnd()
            if let data = text.data(using: .utf8) {
                try? handle.write(contentsOf: data)
            }
        } else {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

private func AppLoggerUncaughtExceptionHandler(_ exception: NSException) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let report = """
    [\(timestamp)] [FATAL]
    UNCAUGHT EXCEPTION: \(exception.name.rawValue)
    Reason: \(exception.reason ?? "desconocida")
    Stack:
    \(exception.callStackSymbols.joined(separator: "\n"))
    """
    AppLogger.appendSync(report + "\n")
}
