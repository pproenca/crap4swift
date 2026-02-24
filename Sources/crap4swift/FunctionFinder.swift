import SwiftSyntax

struct FunctionInfo {
    let name: String
    let startLine: Int
    let endLine: Int
    let node: Syntax
}

class FunctionFinder: SyntaxVisitor {
    let converter: SourceLocationConverter
    var functions: [FunctionInfo] = []

    init(converter: SourceLocationConverter) {
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.body != nil else { return .visitChildren }
        let name = makeFunctionName(node)
        let start = converter.location(for: node.positionAfterSkippingLeadingTrivia).line
        let end = converter.location(for: node.endPositionBeforeTrailingTrivia).line
        functions.append(FunctionInfo(name: name, startLine: start, endLine: end, node: Syntax(node)))
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.body != nil else { return .visitChildren }
        let name = makeInitName(node)
        let start = converter.location(for: node.positionAfterSkippingLeadingTrivia).line
        let end = converter.location(for: node.endPositionBeforeTrailingTrivia).line
        functions.append(FunctionInfo(name: name, startLine: start, endLine: end, node: Syntax(node)))
        return .visitChildren
    }

    override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.body != nil else { return .visitChildren }
        let start = converter.location(for: node.positionAfterSkippingLeadingTrivia).line
        let end = converter.location(for: node.endPositionBeforeTrailingTrivia).line
        functions.append(FunctionInfo(name: "deinit", startLine: start, endLine: end, node: Syntax(node)))
        return .visitChildren
    }

    override func visit(_ node: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.body != nil else { return .visitChildren }
        let accessorKind = node.accessorSpecifier.text
        let parentName = findParentName(of: Syntax(node))
        let name = "\(parentName).\(accessorKind)"
        let start = converter.location(for: node.positionAfterSkippingLeadingTrivia).line
        let end = converter.location(for: node.endPositionBeforeTrailingTrivia).line
        functions.append(FunctionInfo(name: name, startLine: start, endLine: end, node: Syntax(node)))
        return .visitChildren
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        // Only extract as a single function if it has an implicit getter (code block body)
        // Explicit accessor blocks are handled by AccessorDeclSyntax visits
        if case .getter = node.accessorBlock?.accessors {
            let name = makeSubscriptName(node)
            let start = converter.location(for: node.positionAfterSkippingLeadingTrivia).line
            let end = converter.location(for: node.endPositionBeforeTrailingTrivia).line
            functions.append(FunctionInfo(name: name, startLine: start, endLine: end, node: Syntax(node)))
        }
        return .visitChildren
    }

    // MARK: - Name Generation

    private func makeFunctionName(_ node: FunctionDeclSyntax) -> String {
        let baseName = node.name.text
        let params = node.signature.parameterClause.parameters
        if params.isEmpty {
            return "\(baseName)()"
        }
        let labels = params.map { "\($0.firstName.text):" }
        return "\(baseName)(\(labels.joined()))"
    }

    private func makeInitName(_ node: InitializerDeclSyntax) -> String {
        let optMark = node.optionalMark?.text ?? ""
        let params = node.signature.parameterClause.parameters
        if params.isEmpty {
            return "init\(optMark)()"
        }
        let labels = params.map { "\($0.firstName.text):" }
        return "init\(optMark)(\(labels.joined()))"
    }

    private func makeSubscriptName(_ node: SubscriptDeclSyntax) -> String {
        let params = node.parameterClause.parameters
        if params.isEmpty {
            return "subscript()"
        }
        let labels = params.map { "\($0.firstName.text):" }
        return "subscript(\(labels.joined()))"
    }

    private func findParentName(of node: Syntax) -> String {
        var current: Syntax? = node
        while let parent = current?.parent {
            if let binding = parent.as(PatternBindingSyntax.self),
               let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                return pattern.identifier.text
            }
            if let sub = parent.as(SubscriptDeclSyntax.self) {
                return makeSubscriptName(sub)
            }
            current = parent
        }
        return "<unknown>"
    }
}
