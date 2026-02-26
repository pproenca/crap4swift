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
        appendFunction(name: makeFunctionName(node), forNode: Syntax(node))
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.body != nil else { return .visitChildren }
        appendFunction(name: makeInitName(node), forNode: Syntax(node))
        return .visitChildren
    }

    override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.body != nil else { return .visitChildren }
        appendFunction(name: "deinit", forNode: Syntax(node))
        return .visitChildren
    }

    override func visit(_ node: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.body != nil else { return .visitChildren }
        let accessorKind = node.accessorSpecifier.text
        let parentName = findParentName(of: Syntax(node))
        appendFunction(name: "\(parentName).\(accessorKind)", forNode: Syntax(node))
        return .visitChildren
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        // Only extract as a single function if it has an implicit getter (code block body)
        // Explicit accessor blocks are handled by AccessorDeclSyntax visits
        if case .getter = node.accessorBlock?.accessors {
            appendFunction(name: makeSubscriptName(node), forNode: Syntax(node))
        }
        return .visitChildren
    }

    // MARK: - Name Generation

    private func makeFunctionName(_ node: FunctionDeclSyntax) -> String {
        let baseName = node.name.text
        return "\(baseName)\(makeParameterClauseString(node.signature.parameterClause.parameters))"
    }

    private func makeInitName(_ node: InitializerDeclSyntax) -> String {
        let optMark = node.optionalMark?.text ?? ""
        return "init\(optMark)\(makeParameterClauseString(node.signature.parameterClause.parameters))"
    }

    private func makeSubscriptName(_ node: SubscriptDeclSyntax) -> String {
        return "subscript\(makeParameterClauseString(node.parameterClause.parameters))"
    }

    private func makeParameterClauseString(_ params: FunctionParameterListSyntax) -> String {
        guard !params.isEmpty else { return "()" }
        let labels = params.map { "\($0.firstName.text):" }
        return "(\(labels.joined()))"
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

    private func appendFunction(name: String, forNode node: Syntax) {
        let startLine = converter.location(for: node.positionAfterSkippingLeadingTrivia).line
        let endLine = converter.location(for: node.endPositionBeforeTrailingTrivia).line
        functions.append(FunctionInfo(name: name, startLine: startLine, endLine: endLine, node: node))
    }
}
