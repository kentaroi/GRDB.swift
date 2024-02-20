open class RollbackManager: TransactionObserver {
    public static let shared: RollbackManager = RollbackManager()

    public struct Change {
        public struct Operations: OptionSet,
                                  CustomStringConvertible,
                                  CustomDebugStringConvertible {
            public let rawValue: Int

            public static let insert = Operations(rawValue: 1 << 0)
            public static let delete = Operations(rawValue: 1 << 1)
            public static let update = Operations(rawValue: 1 << 2)
            public static let all: Operations = [.insert, .delete, .update]

            static let labels: [(Self, String)] = [
                (.insert, "insert"),
                (.delete, "delete"),
                (.update, "update")
            ]

            public init(rawValue: Int) {
                self.rawValue = rawValue
            }

            public var description: String {
                return "[" + labels + "]"
            }

            public var debugDescription: String {
                return "RollbackManager.Change.Operations(" + labels + ")"
            }

            private var labels: String {
                return Self.labels
                    .filter { contains($0.0) }.map { $0.1 }
                    .joined(separator: ", ")
            }
        }

        public var record: Record
        public var referenceRow: Row?
        public var operations: Operations

        public init(_ record: Record, operations: Operations) {
            self.record = record
            referenceRow = record.referenceRow
            self.operations = operations
        }
    }

    open var changes: [ObjectIdentifier: Change] = [:]

    private init() { }

    open func add(_ record: Record, operation: Change.Operations) {
        let identifier = ObjectIdentifier(record)
        if var change = changes[identifier] {
            change.operations = change.operations.union(operation)
            changes[identifier] = change
        } else {
            changes[identifier] = Change(record, operations: operation)
        }
    }

    // MARK: - TransactionObserver

    open func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool { false }
    open func databaseDidChange(with event: DatabaseEvent) { }

    open func databaseDidCommit(_ db: Database) {
        changes.removeAll()
    }

    open func databaseDidRollback(_ db: Database) {
        for change in changes.values {
            change.record.referenceRow = change.referenceRow
            change.record.didRollback(operations: change.operations)
        }
        changes.removeAll()
    }
}
