import AppKit
import UniformTypeIdentifiers

struct DiskEntry {
    let name: String
    let fileType: String
    let dataType: String
    let granules: String
}

final class Decb {
    let repoURL: URL
    let executableURL: URL

    init(repoURL: URL) {
        self.repoURL = repoURL
        self.executableURL = repoURL.appendingPathComponent("decb")
    }

    @discardableResult
    func run(_ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = args
        process.currentDirectoryURL = repoURL

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        let out = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw NSError(domain: "DiskUtility.Decb", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: (err.isEmpty ? out : err).trimmingCharacters(in: .whitespacesAndNewlines)
            ])
        }
        return out
    }
}

final class DiskDropView: NSView {
    weak var controller: AppController?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return controller?.canAcceptDrop(sender) == true ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return controller?.acceptDrop(sender) ?? false
    }
}

final class HexTextView: NSTextView {
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        menu.addItem(.separator())
        let copyColumn = NSMenuItem(title: "Copy This Column", action: #selector(copyColumnValues), keyEquivalent: "")
        copyColumn.target = self
        menu.addItem(copyColumn)
        return menu
    }

    @objc func copyColumnValues() {
        let result = selectedTextOrAll()
        guard !result.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result, forType: .string)
    }

    private func selectedTextOrAll() -> String {
        let range = selectedRange()
        if range.length > 0, let swiftRange = Range(range, in: string) {
            return String(string[swiftRange])
        }
        return string
    }
}

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

final class HexEditorWindowController: NSWindowController {
    private let hexTextView: HexTextView
    private let asciiTextView: HexTextView

    init(entryName: String, data: Data) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        let root = NSView(frame: window.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 820, height: 620))
        root.autoresizingMask = [.width, .height]

        let buttonBar = NSStackView(frame: NSRect(x: 12, y: root.bounds.height - 42, width: root.bounds.width - 24, height: 30))
        buttonBar.orientation = .horizontal
        buttonBar.spacing = 8
        buttonBar.alignment = .centerY
        buttonBar.autoresizingMask = [.width, .minYMargin]

        let copyHexButton = NSButton(title: "Copy Hex", target: nil, action: #selector(HexTextView.copyColumnValues))
        copyHexButton.bezelStyle = .rounded
        let copyAsciiButton = NSButton(title: "Copy ASCII", target: nil, action: #selector(HexTextView.copyColumnValues))
        copyAsciiButton.bezelStyle = .rounded
        buttonBar.addArrangedSubview(copyHexButton)
        buttonBar.addArrangedSubview(copyAsciiButton)

        let header = NSView(frame: NSRect(x: 12, y: root.bounds.height - 70, width: 690, height: 20))
        header.autoresizingMask = [.minYMargin]
        header.addSubview(HexEditorWindowController.headerLabel("Address", x: 8, width: 75))
        header.addSubview(HexEditorWindowController.headerLabel("Hex", x: 104, width: 385))
        header.addSubview(HexEditorWindowController.headerLabel("ASCII", x: 512, width: 160))

        let scroll = NSScrollView(frame: NSRect(x: 12, y: 12, width: root.bounds.width - 24, height: root.bounds.height - 88))
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = false
        scroll.borderType = .bezelBorder

        let columns = HexEditorWindowController.hexColumns(data)
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let lineHeight = ceil(NSLayoutManager().defaultLineHeight(for: font))
        let rowCount = max(1, columns.addresses.count, columns.hex.count, columns.ascii.count)
        let textHeight = CGFloat(rowCount) * lineHeight
        let documentHeight = textHeight + 8
        let document = FlippedView(frame: NSRect(x: 0, y: 0, width: 690, height: documentHeight))
        document.wantsLayer = true
        document.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        let addressTextView = HexEditorWindowController.columnTextView(
            frame: NSRect(x: 8, y: 4, width: 75, height: textHeight),
            text: columns.addresses.joined(separator: "\n"),
            font: font
        )
        hexTextView = HexEditorWindowController.columnTextView(
            frame: NSRect(x: 104, y: 4, width: 385, height: textHeight),
            text: columns.hex.joined(separator: "\n"),
            font: font
        )
        asciiTextView = HexEditorWindowController.columnTextView(
            frame: NSRect(x: 512, y: 4, width: 160, height: textHeight),
            text: columns.ascii.joined(separator: "\n"),
            font: font
        )

        document.addSubview(addressTextView)
        document.addSubview(HexEditorWindowController.separator(x: 92, height: documentHeight))
        document.addSubview(hexTextView)
        document.addSubview(HexEditorWindowController.separator(x: 500, height: documentHeight))
        document.addSubview(asciiTextView)

        scroll.documentView = document
        copyHexButton.target = hexTextView
        copyAsciiButton.target = asciiTextView
        root.addSubview(buttonBar)
        root.addSubview(header)
        root.addSubview(scroll)
        window.title = "HexEdit - \(entryName)"
        window.contentView = root
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func headerLabel(_ text: String, x: CGFloat, width: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.frame = NSRect(x: x, y: 0, width: width, height: 18)
        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private static func separator(x: CGFloat, height: CGFloat) -> NSBox {
        let box = NSBox(frame: NSRect(x: x, y: 0, width: 1, height: height))
        box.boxType = .separator
        return box
    }

    private static func columnTextView(frame: NSRect, text: String, font: NSFont) -> HexTextView {
        let view = HexTextView(frame: frame)
        view.isEditable = false
        view.isSelectable = true
        view.isVerticallyResizable = false
        view.isHorizontallyResizable = false
        view.autoresizingMask = []
        view.drawsBackground = false
        view.font = font
        view.textColor = .labelColor
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.containerSize = NSSize(width: frame.width, height: frame.height)
        view.textContainer?.widthTracksTextView = true
        view.layoutManager?.usesFontLeading = true
        view.string = text
        return view
    }

    private static func hexColumns(_ data: Data) -> (addresses: [String], hex: [String], ascii: [String]) {
        var addresses: [String] = []
        var hexLines: [String] = []
        var asciiLines: [String] = []
        let bytes = Array(data)
        var offset = 0
        while offset < bytes.count {
            let end = min(offset + 16, bytes.count)
            let row = bytes[offset..<end]
            let hex = row.map { String(format: "%02X", $0) }.joined(separator: " ")
            let ascii = row.map { byte -> Character in
                if byte >= 32 && byte < 127 {
                    return Character(UnicodeScalar(byte))
                }
                return "."
            }
            addresses.append(String(format: "%08X", offset))
            hexLines.append(hex)
            asciiLines.append(String(ascii))
            offset += 16
        }
        if addresses.isEmpty {
            addresses.append("00000000")
        }
        return (addresses, hexLines, asciiLines)
    }
}

final class AppController: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private var window: NSWindow!
    private var tableView: NSTableView!
    private var statusLabel: NSTextField!
    private var pathLabel: NSTextField!
    private var openButton: NSButton!
    private var refreshButton: NSButton!
    private var importButton: NSButton!
    private var exportButton: NSButton!
    private var hexEditButton: NSButton!
    private var deleteButton: NSButton!

    private let repoURL = AppController.findRepoURL()
    private lazy var decb = Decb(repoURL: repoURL)
    private var diskURL: URL?
    private var pendingDiskURL: URL?
    private var entries: [DiskEntry] = []
    private var hexWindows: [HexEditorWindowController] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildUI()
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        openDiskImage(URL(fileURLWithPath: filename))
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first {
            openDiskImage(url)
        }
    }

    static func findRepoURL() -> URL {
        let fm = FileManager.default
        var candidates: [URL] = []
        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL)
        }
        if let executable = Bundle.main.executableURL {
            var url = executable.deletingLastPathComponent()
            for _ in 0..<8 {
                candidates.append(url)
                url.deleteLastPathComponent()
            }
        }
        candidates.append(URL(fileURLWithPath: fm.currentDirectoryPath))
        for candidate in candidates {
            if fm.isExecutableFile(atPath: candidate.appendingPathComponent("decb").path) {
                return candidate
            }
        }
        return URL(fileURLWithPath: fm.currentDirectoryPath)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    private func buildUI() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CoCo DSK Utility"
        window.center()

        let root = DiskDropView()
        root.controller = self
        root.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = root

        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.spacing = 8
        toolbar.alignment = .centerY
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        openButton = button("Open DSK", action: #selector(openDisk))
        refreshButton = button("Refresh", action: #selector(refreshDisk))
        importButton = button("Add Files", action: #selector(importFiles))
        exportButton = button("Export", action: #selector(exportSelected))
        hexEditButton = button("HexEdit", action: #selector(hexEditSelected))
        deleteButton = button("Delete", action: #selector(deleteSelected))
        toolbar.addArrangedSubview(openButton)
        toolbar.addArrangedSubview(refreshButton)
        toolbar.addArrangedSubview(importButton)
        toolbar.addArrangedSubview(exportButton)
        toolbar.addArrangedSubview(hexEditButton)
        toolbar.addArrangedSubview(deleteButton)

        pathLabel = NSTextField(labelWithString: "No disk image open")
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.translatesAutoresizingMaskIntoConstraints = false

        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = true
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.menu = makeContextMenu()
        tableView.registerForDraggedTypes([.fileURL])
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
        addColumn("name", "Name", 280)
        addColumn("type", "Type", 120)
        addColumn("data", "Data", 120)
        addColumn("granules", "Granules", 90)

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        statusLabel = NSTextField(labelWithString: "Open a .DSK image, then drag files into this window to copy them onto the disk.")
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(toolbar)
        root.addSubview(pathLabel)
        root.addSubview(scroll)
        root.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            toolbar.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            toolbar.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -12),

            pathLabel.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 10),
            pathLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            pathLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),

            scroll.topAnchor.constraint(equalTo: pathLabel.bottomAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            scroll.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -10),

            statusLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            statusLabel.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12)
        ])

        updateButtons()
        window.makeKeyAndOrderFront(nil)
        if let pendingDiskURL {
            self.pendingDiskURL = nil
            openDiskImage(pendingDiskURL)
        }
    }

    private func button(_ title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        return b
    }

    private func addColumn(_ id: String, _ title: String, _ width: CGFloat) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
        column.title = title
        column.width = width
        tableView.addTableColumn(column)
    }

    private func updateButtons() {
        let hasDisk = diskURL != nil
        refreshButton.isEnabled = hasDisk
        importButton.isEnabled = hasDisk
        exportButton.isEnabled = hasDisk && tableView.selectedRowIndexes.count > 0
        hexEditButton.isEnabled = hasDisk && tableView.selectedRowIndexes.count == 1
        deleteButton.isEnabled = hasDisk && tableView.selectedRowIndexes.count > 0
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(menuItem("HexEdit", #selector(hexEditSelected)))
        menu.addItem(.separator())

        let typeMenu = NSMenu()
        typeMenu.addItem(menuItem("BASIC Program", #selector(setTypeBasicProgram)))
        typeMenu.addItem(menuItem("BASIC Data", #selector(setTypeBasicData)))
        typeMenu.addItem(menuItem("Machine Language", #selector(setTypeMachineLanguage)))
        typeMenu.addItem(menuItem("Text", #selector(setTypeText)))
        let typeItem = NSMenuItem(title: "Set Type", action: nil, keyEquivalent: "")
        typeItem.submenu = typeMenu
        menu.addItem(typeItem)

        let dataMenu = NSMenu()
        dataMenu.addItem(menuItem("Binary", #selector(setDataBinary)))
        dataMenu.addItem(menuItem("ASCII", #selector(setDataAscii)))
        let dataItem = NSMenuItem(title: "Set Data Type", action: nil, keyEquivalent: "")
        dataItem.submenu = dataMenu
        menu.addItem(dataItem)

        menu.addItem(.separator())
        menu.addItem(menuItem("Export", #selector(exportSelected)))
        menu.addItem(menuItem("Delete", #selector(deleteSelected)))
        return menu
    }

    private func menuItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func openDisk() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "dsk") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            openDiskImage(url)
        }
    }

    private func openDiskImage(_ url: URL) {
        diskURL = url
        guard pathLabel != nil else {
            pendingDiskURL = url
            return
        }
        pathLabel.stringValue = url.path
        refreshDisk()
    }

    @objc private func refreshDisk() {
        guard let diskURL else { return }
        do {
            let output = try decb.run(["dir", diskURL.path])
            entries = parseDirectory(output)
            tableView.reloadData()
            statusLabel.stringValue = "\(entries.count) file(s)"
        } catch {
            showError(error)
        }
        updateButtons()
    }

    @objc private func importFiles() {
        guard diskURL != nil else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            addFiles(panel.urls)
        }
    }

    @objc private func exportSelected() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Export"
        if panel.runModal() == .OK, let folder = panel.url {
            exportSelectedEntries(to: folder)
        }
    }

    @objc private func hexEditSelected() {
        guard let entry = focusedEntries().first, focusedEntries().count == 1 else { return }
        do {
            let tempURL = try exportEntryToTemporaryFile(entry)
            let data = try Data(contentsOf: tempURL)
            let controller = HexEditorWindowController(entryName: entry.name, data: data)
            hexWindows.append(controller)
            controller.showWindow(nil)
        } catch {
            showError(error)
        }
    }

    @objc private func setTypeBasicProgram() { setAttributes(["-0"]) }
    @objc private func setTypeBasicData() { setAttributes(["-1"]) }
    @objc private func setTypeMachineLanguage() { setAttributes(["-2"]) }
    @objc private func setTypeText() { setAttributes(["-3"]) }
    @objc private func setDataAscii() { setAttributes(["-a"]) }
    @objc private func setDataBinary() { setAttributes(["-b"]) }

    @objc private func deleteSelected() {
        guard let diskURL else { return }
        let selected = focusedEntries()
        guard !selected.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "Delete \(selected.count) file(s) from disk image?"
        alert.informativeText = selected.map(\.name).joined(separator: ", ")
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            for entry in selected {
                try decb.run(["kill", "\(diskURL.path),\(entry.name)"])
            }
            refreshDisk()
        } catch {
            showError(error)
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = tableColumn?.identifier.rawValue ?? "name"
        let value: String
        switch id {
        case "type": value = entries[row].fileType
        case "data": value = entries[row].dataType
        case "granules": value = entries[row].granules
        default: value = entries[row].name
        }
        let cellID = NSUserInterfaceItemIdentifier("cell-\(id)")
        let text = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTextField ?? NSTextField(labelWithString: "")
        text.identifier = cellID
        text.stringValue = value
        text.lineBreakMode = .byTruncatingMiddle
        return text
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateButtons()
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard let tempURL = try? exportEntryToTemporaryFile(entries[row]) else { return nil }
        return tempURL as NSURL
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        return canAcceptDrop(info) ? .copy : []
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        return acceptDrop(info)
    }

    func canAcceptDrop(_ sender: NSDraggingInfo) -> Bool {
        diskURL != nil && fileURLs(from: sender).contains { !$0.hasDirectoryPath }
    }

    func acceptDrop(_ sender: NSDraggingInfo) -> Bool {
        let files = fileURLs(from: sender).filter { !$0.hasDirectoryPath }
        guard !files.isEmpty else { return false }
        addFiles(files)
        return true
    }

    private func addFiles(_ urls: [URL]) {
        guard let diskURL else { return }
        do {
            for url in urls {
                let target = "\(diskURL.path),\(cocoName(for: url))"
                try decb.run(["copy", "-2", "-b", "-r", url.path, target])
            }
            refreshDisk()
        } catch {
            showError(error)
        }
    }

    private func exportSelectedEntries(to folder: URL) {
        do {
            let entries = focusedEntries()
            for entry in entries {
                try exportEntry(entry, to: folder)
            }
            statusLabel.stringValue = "Exported \(entries.count) file(s) to \(folder.path)"
        } catch {
            showError(error)
        }
    }

    private func setAttributes(_ options: [String]) {
        guard let diskURL else { return }
        let entries = focusedEntries()
        guard !entries.isEmpty else { return }
        do {
            for entry in entries {
                try decb.run(["attr"] + options + ["\(diskURL.path),\(entry.name)"])
            }
            refreshDisk()
        } catch {
            showError(error)
        }
    }

    private func exportEntryToTemporaryFile(_ entry: DiskEntry) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("CoCoDSKUtility-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try exportEntry(entry, to: folder)
        return folder.appendingPathComponent(entry.name)
    }

    private func exportEntry(_ entry: DiskEntry, to folder: URL) throws {
        guard let diskURL else { return }
        let destination = folder.appendingPathComponent(entry.name).path
        try decb.run(["copy", "-b", "-r", "\(diskURL.path),\(entry.name)", destination])
    }

    private func selectedEntries() -> [DiskEntry] {
        tableView.selectedRowIndexes.compactMap { index in
            entries.indices.contains(index) ? entries[index] : nil
        }
    }

    private func focusedEntries() -> [DiskEntry] {
        let clicked = tableView.clickedRow
        if clicked >= 0 && entries.indices.contains(clicked) {
            if !tableView.selectedRowIndexes.contains(clicked) {
                tableView.selectRowIndexes(IndexSet(integer: clicked), byExtendingSelection: false)
            }
        }
        return selectedEntries()
    }

    private func fileURLs(from sender: NSDraggingInfo) -> [URL] {
        let pasteboard = sender.draggingPasteboard
        guard let items = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] else {
            return []
        }
        return items
    }

    private func parseDirectory(_ output: String) -> [DiskEntry] {
        output.split(separator: "\n").compactMap { line in
            let text = String(line).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty, !text.hasPrefix("Directory of:") else { return nil }
            let parts = text.split { $0 == " " || $0 == "\t" }.map(String.init)
            guard parts.count >= 2 else { return nil }
            let name = "\(parts[0]).\(parts[1])"
            let type = parts.count > 2 ? parts[2] : ""
            let data = parts.count > 3 ? parts[3] : ""
            let granules = parts.count > 4 ? parts[4] : ""
            return DiskEntry(name: name, fileType: type, dataType: data, granules: granules)
        }
    }

    private func cocoName(for url: URL) -> String {
        let base = url.deletingPathExtension().lastPathComponent.uppercased()
        let ext = url.pathExtension.uppercased()
        let valid = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        func clean(_ s: String, max: Int) -> String {
            let filtered = String(s.unicodeScalars.map { valid.contains($0) ? Character($0) : "_" })
            return String(filtered.prefix(max))
        }
        let name = clean(base, max: 8)
        let suffix = clean(ext.isEmpty ? "BIN" : ext, max: 3)
        return "\(name).\(suffix)"
    }

    private func showError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
        statusLabel.stringValue = error.localizedDescription
    }
}

let app = NSApplication.shared
let delegate = AppController()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
