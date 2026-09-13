//
//  ServiceProtocols.swift
//  Paste
//
//  Protocol interfaces for the five macOS service singletons.
//  Abstracting behind protocols enables dependency injection and unit testing
//  without touching any production code paths.
//

import Foundation
import AppKit

// MARK: - ClipboardServiceProtocol

protocol ClipboardServiceProtocol: AnyObject {
    // Create
    func saveItem(_ content: ClipboardContent)
    // Read
    func fetchAllItems() -> [ClipboardItemModel]
    func fetchItemWithFullData(id: UUID) -> ClipboardItemModel?
    func searchItems(keyword: String, type: ClipboardItemType?) -> [ClipboardItemModel]
    func filterByApp(_ bundleId: String) -> [ClipboardItemModel]
    // Update
    func togglePin(id: UUID)
    func updateTags(id: UUID, tags: [String])
    func updatePlainText(id: UUID, newText: String)
    // Pinboard
    func isInAnyPinboard(_ item: ClipboardItemModel) -> Bool
    func isInPinboard(_ item: ClipboardItemModel, index: Int) -> Bool
    func setPinboard(id: UUID, index: Int, enabled: Bool)
    func moveToPinboard(id: UUID, index: Int)
    // Delete
    func deleteItem(id: UUID)
    func deleteAllItems()
    func deleteAllItems(ofType type: ClipboardItemType)
    func restoreItem(_ model: ClipboardItemModel)
    // Paste / Copy
    func pasteItem(_ item: ClipboardItemModel, simulatePaste: Bool, plainTextOnly: Bool)
    func copyItem(_ item: ClipboardItemModel, plainTextOnly: Bool)
    func copyPlainTextToClipboard(_ string: String)
}

// MARK: - ClipboardMonitorProtocol

protocol ClipboardMonitorProtocol: AnyObject {
    var isMonitoringActive: Bool { get }
    var selfWriteHash: String? { get }
    func startMonitoring()
    func stopMonitoring()
    func markSelfWrite(hash: String)
}

// MARK: - PasteboardHelperProtocol

protocol PasteboardHelperProtocol: AnyObject {
    var changeCount: Int { get }
    func readContent() -> ClipboardContent?
    func readPlainText() -> String?
    func readRTFData() -> Data?
    func readImageData() -> Data?
    func readFilePaths() -> [String]?
    func getSourceApplication() -> String?
    func writeText(_ text: String, rtfData: Data?)
    func writeImage(_ imageData: Data)
    func writeFilePaths(_ paths: [String])
    func writeItem(_ item: ClipboardItemModel, plainTextOnly: Bool)
    @discardableResult func simulatePaste() -> Bool
}

// MARK: - HotKeyManagerProtocol

protocol HotKeyManagerProtocol: AnyObject {
    func registerAll(handlers: [HotKeyManager.HotKeyAction: () -> Void])
    func setHandler(action: HotKeyManager.HotKeyAction, handler: @escaping () -> Void)
    func updateHotKey(action: HotKeyManager.HotKeyAction, enabled: Bool, keyCode: UInt32, modifiers: UInt32)
    func unregisterAll()
    func unregister(action: HotKeyManager.HotKeyAction)
    func currentHotKeyDisplayString(action: HotKeyManager.HotKeyAction) -> String
    func displayString(keyCode: UInt32, modifiers: UInt32) -> String
}

// MARK: - PasteStackServiceProtocol

protocol PasteStackServiceProtocol: AnyObject {
    func fetchEntries() -> [PasteStackService.Entry]
    func push(itemId: UUID)
    func remove(entryId: UUID)
    func removeTopEntry(for itemId: UUID)
    func clear()
}

// MARK: - Protocol conformances

extension ClipboardService:  ClipboardServiceProtocol  {}
extension ClipboardMonitor:  ClipboardMonitorProtocol  {}
extension PasteboardHelper:  PasteboardHelperProtocol  {}
extension HotKeyManager:     HotKeyManagerProtocol     {}
extension PasteStackService: PasteStackServiceProtocol {}

// MARK: - Local MCP server (Paste parity: MCP & AI Tools)

import Network
import CoreData

/// One AI tool that has connected to the local MCP server.
struct MCPClientRecord: Codable {
    var name: String
    var lastUsed: Date

    static func loadAll() -> [MCPClientRecord] {
        guard let data = AppSettings.mcpConnectedToolsData else { return [] }
        return (try? JSONDecoder().decode([MCPClientRecord].self, from: data)) ?? []
    }

    static func record(_ name: String) {
        var all = loadAll().filter { $0.name != name }
        all.insert(MCPClientRecord(name: name, lastUsed: Date()), at: 0)
        AppSettings.mcpConnectedToolsData = try? JSONEncoder().encode(all)
        NotificationCenter.default.post(name: AppNotification.mcpClientsChanged, object: nil)
    }
}

/// Minimal streamable-HTTP MCP server bound to loopback, like Paste's
/// MCP & AI Tools integration. Speaks JSON-RPC 2.0: initialize, ping,
/// tools/list and tools/call over POST, 405 on GET.
final class MCPServer {
    static let shared = MCPServer()

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "dev.corismix.copydock.mcp")
    private(set) var actualPort: Int = 0

    var isRunning: Bool { listener != nil }

    var serverURL: String {
        let port = actualPort > 0 ? actualPort : AppSettings.mcpPort
        return "http://127.0.0.1:\(port)/mcp"
    }

    func start() {
        stop()
        let params = NWParameters.tcp
        params.requiredInterfaceType = .loopback
        let requested = NWEndpoint.Port(rawValue: UInt16(clamping: AppSettings.mcpPort)) ?? .any
        do {
            let l = try NWListener(using: params, on: requested)
            l.stateUpdateHandler = { [weak self] state in
                if case .ready = state, let port = l.port?.rawValue {
                    self?.actualPort = Int(port)
                }
            }
            l.newConnectionHandler = { [weak self] conn in self?.receiveLoop(conn, buffer: Data()) }
            l.start(queue: queue)
            listener = l
            NSLog("MCPServer listening on %@", serverURL)
        } catch {
            NSLog("MCPServer failed to start: \(error.localizedDescription)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        actualPort = 0
    }

    // MARK: - HTTP framing

    private func receiveLoop(_ conn: NWConnection, buffer: Data) {
        conn.start(queue: queue)
        var acc = buffer
        func recv() {
            conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, isComplete, _ in
                guard let self else { conn.cancel(); return }
                if let data { acc.append(data) }
                if let response = self.tryRespond(to: acc) {
                    conn.send(content: response, completion: .contentProcessed { _ in conn.cancel() })
                } else if isComplete {
                    conn.cancel()
                } else {
                    recv()
                }
            }
        }
        recv()
    }

    /// Returns a full HTTP response once headers + body are complete, else nil.
    private func tryRespond(to data: Data) -> Data? {
        guard let headerEnd = data.range(of: Data([13, 10, 13, 10])) else { return nil }
        let head = String(decoding: data[..<headerEnd.lowerBound], as: UTF8.self)
        var contentLength = 0
        var method = ""
        for line in head.components(separatedBy: "\r\n") {
            if line.lowercased().hasPrefix("content-length:") {
                contentLength = Int(line.dropFirst(15).trimmingCharacters(in: .whitespaces)) ?? 0
            } else if method.isEmpty {
                method = line.components(separatedBy: " ").first ?? ""
            }
        }
        let bodyStart = headerEnd.upperBound
        guard data.count >= bodyStart + contentLength else { return nil }

        if method == "GET" {
            return httpResponse(status: "405 Method Not Allowed", body: Data())
        }
        guard method == "POST" else {
            return httpResponse(status: "405 Method Not Allowed", body: Data())
        }
        let body = data.subdata(in: bodyStart ..< bodyStart + contentLength)
        guard let rpc = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let rpcMethod = rpc["method"] as? String else {
            return httpResponse(status: "400 Bad Request", body: Data())
        }

        // Pure notifications get no response object.
        if rpcMethod.hasPrefix("notifications/") {
            return httpResponse(status: "202 Accepted", body: Data())
        }
        let id = rpc["id"] ?? NSNull()
        let result = handleRPC(rpcMethod, params: rpc["params"] as? [String: Any], id: id)
        let payload = (try? JSONSerialization.data(withJSONObject: result)) ?? Data()
        return httpResponse(status: "200 OK", body: payload)
    }

    private func httpResponse(status: String, body: Data) -> Data {
        var head = "HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        let d = Data(head.utf8) + body
        head.removeAll()
        return d
    }

    // MARK: - JSON-RPC

    private func handleRPC(_ method: String, params: [String: Any]?, id: Any) -> [String: Any] {
        switch method {
        case "initialize":
            if let clientInfo = params?["clientInfo"] as? [String: Any],
               let name = clientInfo["name"] as? String {
                MCPClientRecord.record(name)
            }
            return envelope(id: id, result: [
                "protocolVersion": "2025-06-18",
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": ["name": "Copydock", "version": "0.1.2"],
            ])
        case "ping":
            return envelope(id: id, result: [String: Any]())
        case "tools/list":
            return envelope(id: id, result: ["tools": toolList()])
        case "tools/call":
            guard let name = params?["name"] as? String else {
                return envelope(id: id, error: -32602, message: "Missing tool name")
            }
            let args = params?["arguments"] as? [String: Any] ?? [:]
            return envelope(id: id, result: callTool(name, args: args))
        default:
            return envelope(id: id, error: -32601, message: "Method not found: \(method)")
        }
    }

    private func envelope(id: Any, result: [String: Any]) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "result": result]
    }

    private func envelope(id: Any, error code: Int, message: String) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]]
    }

    private func toolList() -> [[String: Any]] {
        [
            [
                "name": "search_clipboard",
                "description": "Search clipboard history. Returns matching items with text, type and timestamp.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "Text to search for"],
                        "limit": ["type": "integer", "description": "Max items (default 20)"],
                    ],
                ],
            ],
            [
                "name": "get_latest_clipboard",
                "description": "Get the most recent clipboard items.",
                "inputSchema": [
                    "type": "object",
                    "properties": ["limit": ["type": "integer", "description": "Max items (default 10)"]],
                ],
            ],
            [
                "name": "list_pinboards",
                "description": "List the user's pinboards with names and colors.",
                "inputSchema": ["type": "object", "properties": [String: Any]()],
            ],
        ]
    }

    private func callTool(_ name: String, args: [String: Any]) -> [String: Any] {
        switch name {
        case "search_clipboard", "get_latest_clipboard":
            let query = args["query"] as? String
            let limit = (args["limit"] as? Int) ?? (name == "search_clipboard" ? 20 : 10)
            return textPayload(fetchItems(query: query, limit: limit))
        case "list_pinboards":
            var boards: [[String: Any]] = []
            for i in 0 ..< AppSettings.pinboardCount {
                boards.append(["index": i, "name": AppSettings.pinboardName(at: i)])
            }
            return textPayload(boards)
        default:
            return ["content": [["type": "text", "text": "Unknown tool: \(name)"]], "isError": true]
        }
    }

    private func textPayload(_ value: Any) -> [String: Any] {
        let data = (try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted])) ?? Data()
        let text = String(decoding: data, as: UTF8.self)
        return ["content": [["type": "text", "text": text]]]
    }

    /// Core Data read on a private context; safe to call from the listener queue.
    private func fetchItems(query: String?, limit: Int) -> [[String: Any]] {
        let context = CoreDataStack.shared.newBackgroundContext()
        var rows: [[String: Any]] = []
        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ClipboardItemEntity")
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            request.fetchLimit = max(1, min(limit, 100))
            if let query, !query.isEmpty {
                request.predicate = NSPredicate(format: "plainText CONTAINS[cd] %@", query)
            }
            let results = (try? context.fetch(request)) ?? []
            let formatter = ISO8601DateFormatter()
            for obj in results {
                let typeRaw = (obj.value(forKey: "type") as? Int) ?? 0
                let typeName = ["text", "image", "file"][safe: typeRaw] ?? "text"
                rows.append([
                    "id": (obj.value(forKey: "id") as? UUID)?.uuidString ?? "",
                    "type": typeName,
                    "text": (obj.value(forKey: "plainText") as? String) ?? "",
                    "sourceApp": (obj.value(forKey: "appBundleId") as? String) ?? "",
                    "createdAt": (obj.value(forKey: "createdAt") as? Date).map { formatter.string(from: $0) } ?? "",
                ])
            }
        }
        return rows
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
