//
//  CSVConverter.swift
//  KobunPark
//

import Foundation

nonisolated enum CSVOutputFormat: String, CaseIterable, Identifiable, Sendable {
    case markdown
    case html
    case xml

    var id: String { rawValue }
}

nonisolated struct CSVTable: Equatable, Sendable {
    let headers: [String]
    let rows: [[String]]
}

nonisolated enum CSVConversionError: Error, Equatable, Sendable {
    case emptyInput
    case unclosedQuotedField(row: Int, column: Int)
    case quoteInUnquotedField(row: Int, column: Int)
    case unexpectedCharacterAfterQuote(row: Int, column: Int)
    case inconsistentColumnCount(row: Int, expected: Int, actual: Int)
}

nonisolated struct CSVParser: Sendable {
    func parse(_ input: String) throws -> CSVTable {
        guard !input.isEmpty else {
            throw CSVConversionError.emptyInput
        }

        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var index = input.startIndex
        var isQuoted = false
        var justClosedQuote = false
        var endedWithRecordSeparator = false

        func location() -> (row: Int, column: Int) {
            (records.count + 1, record.count + 1)
        }

        while index < input.endIndex {
            let character = input[index]
            let nextIndex = input.index(after: index)

            if isQuoted {
                if character == "\"" {
                    if nextIndex < input.endIndex, input[nextIndex] == "\"" {
                        field.append("\"")
                        index = input.index(after: nextIndex)
                    } else {
                        isQuoted = false
                        justClosedQuote = true
                        index = nextIndex
                    }
                } else {
                    field.append(character)
                    index = nextIndex
                }
                endedWithRecordSeparator = false
                continue
            }

            if justClosedQuote {
                if character == "," {
                    record.append(field)
                    field = ""
                    justClosedQuote = false
                    index = nextIndex
                    endedWithRecordSeparator = false
                    continue
                }
                if character.isNewline {
                    record.append(field)
                    records.append(record)
                    record = []
                    field = ""
                    justClosedQuote = false
                    index = nextIndex
                    endedWithRecordSeparator = true
                    continue
                }
                let currentLocation = location()
                throw CSVConversionError.unexpectedCharacterAfterQuote(
                    row: currentLocation.row,
                    column: currentLocation.column
                )
            }

            if character == "," {
                record.append(field)
                field = ""
                index = nextIndex
                endedWithRecordSeparator = false
            } else if character.isNewline {
                record.append(field)
                records.append(record)
                record = []
                field = ""
                index = nextIndex
                endedWithRecordSeparator = true
            } else if character == "\"" {
                guard field.isEmpty else {
                    let currentLocation = location()
                    throw CSVConversionError.quoteInUnquotedField(
                        row: currentLocation.row,
                        column: currentLocation.column
                    )
                }
                isQuoted = true
                index = nextIndex
                endedWithRecordSeparator = false
            } else {
                field.append(character)
                index = nextIndex
                endedWithRecordSeparator = false
            }
        }

        if isQuoted {
            let currentLocation = location()
            throw CSVConversionError.unclosedQuotedField(
                row: currentLocation.row,
                column: currentLocation.column
            )
        }

        if !endedWithRecordSeparator {
            record.append(field)
            records.append(record)
        }

        guard let headers = records.first else {
            throw CSVConversionError.emptyInput
        }
        let rows = Array(records.dropFirst())
        for (offset, row) in rows.enumerated() where row.count != headers.count {
            throw CSVConversionError.inconsistentColumnCount(
                row: offset + 2,
                expected: headers.count,
                actual: row.count
            )
        }
        return CSVTable(headers: headers, rows: rows)
    }
}

nonisolated struct CSVConverter: Sendable {
    func convert(_ input: String, to format: CSVOutputFormat) throws -> String {
        let table = try CSVParser().parse(input)
        switch format {
        case .markdown:
            return markdown(from: table)
        case .html:
            return html(from: table)
        case .xml:
            return xml(from: table)
        }
    }

    private func markdown(from table: CSVTable) -> String {
        let header = markdownRow(table.headers)
        let separator = markdownRow(Array(repeating: "---", count: table.headers.count))
        return ([header, separator] + table.rows.map(markdownRow)).joined(separator: "\n")
    }

    private func markdownRow(_ fields: [String]) -> String {
        "| " + fields.map(markdownCell).joined(separator: " | ") + " |"
    }

    private func markdownCell(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\r\n", with: "<br>")
            .replacingOccurrences(of: "\r", with: "<br>")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    private func html(from table: CSVTable) -> String {
        let headers = table.headers
            .map { "      <th>\(MarkupEscaper.escape($0))</th>" }
            .joined(separator: "\n")
        let rows = table.rows.map { row in
            let cells = row
                .map { "      <td>\(MarkupEscaper.escape($0))</td>" }
                .joined(separator: "\n")
            return "    <tr>\n\(cells)\n    </tr>"
        }.joined(separator: "\n")

        return """
        <table>
          <thead>
            <tr>
        \(headers)
            </tr>
          </thead>
          <tbody>
        \(rows)
          </tbody>
        </table>
        """
    }

    private func xml(from table: CSVTable) -> String {
        let headers = table.headers.enumerated().map { index, header in
            "    <header index=\"\(index + 1)\">\(MarkupEscaper.escape(header))</header>"
        }.joined(separator: "\n")
        let rows = table.rows.enumerated().map { rowIndex, row in
            let cells = row.enumerated().map { columnIndex, value in
                let name = MarkupEscaper.escape(table.headers[columnIndex], attribute: true)
                return "      <cell column=\"\(columnIndex + 1)\" name=\"\(name)\">\(MarkupEscaper.escape(value))</cell>"
            }.joined(separator: "\n")
            return "    <row index=\"\(rowIndex + 1)\">\n\(cells)\n    </row>"
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <csv>
          <headers>
        \(headers)
          </headers>
          <rows>
        \(rows)
          </rows>
        </csv>
        """
    }
}

nonisolated enum MarkupEscaper {
    static func escape(_ input: String, attribute: Bool = false) -> String {
        var result = input
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        if attribute {
            result = result
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "'", with: "&apos;")
        }
        return result
    }
}
