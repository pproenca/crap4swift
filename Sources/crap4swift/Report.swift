import Foundation

func formatTable(_ entries: [CrapEntry]) -> String {
    guard !entries.isEmpty else {
        return "No functions found."
    }

    let header = "CRAP Report\n==========="
    let columns = ["Function", "File", "CC", "Cov%", "CRAP"]

    // Calculate column widths
    let nameWidth = max(columns[0].count, entries.map { $0.name.count }.max() ?? 0)
    let fileWidth = max(columns[1].count, entries.map { formatFileLocation($0).count }.max() ?? 0)
    let ccWidth = max(columns[2].count, 4)
    let covWidth = max(columns[3].count, 6)
    let crapWidth = max(columns[4].count, 8)

    let widths = [nameWidth, fileWidth, ccWidth, covWidth, crapWidth]
    let rightAlignedColumns: Set<Int> = [2, 3, 4]
    let totalWidth = widths.reduce(0, +) + (2 * (widths.count - 1))

    var lines: [String] = [header, ""]
    lines.append(makeTableRow(columns, widths: widths, rightAlignedColumns: rightAlignedColumns))
    lines.append(String(repeating: "-", count: totalWidth))

    for entry in entries {
        let fileLoc = formatFileLocation(entry)
        let covStr = String(format: "%.1f%%", entry.coverage)
        let crapStr = String(format: "%.1f", entry.crap)
        lines.append(
            makeTableRow(
                [entry.name, fileLoc, "\(entry.complexity)", covStr, crapStr],
                widths: widths,
                rightAlignedColumns: rightAlignedColumns
            )
        )
    }

    return lines.joined(separator: "\n")
}

func formatJSON(_ entries: [CrapEntry]) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(entries),
          let json = String(data: data, encoding: .utf8) else {
        return "[]"
    }
    return json
}

private func formatFileLocation(_ entry: CrapEntry) -> String {
    "\(entry.file):\(entry.line)"
}

private func makeTableRow(
    _ values: [String],
    widths: [Int],
    rightAlignedColumns: Set<Int>
) -> String {
    values.enumerated()
        .map { index, value in
            let width = widths[index]
            if rightAlignedColumns.contains(index) {
                return padLeft(value, width: width)
            }
            return pad(value, width: width)
        }
        .joined(separator: "  ")
}

private func pad(_ string: String, width: Int) -> String {
    string.padding(toLength: width, withPad: " ", startingAt: 0)
}

private func padLeft(_ string: String, width: Int) -> String {
    if string.count >= width {
        return string
    }
    return String(repeating: " ", count: width - string.count) + string
}
