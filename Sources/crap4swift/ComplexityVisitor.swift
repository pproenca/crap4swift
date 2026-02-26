import SwiftSyntax

class ComplexityVisitor: SyntaxVisitor {
    var complexity: Int = 1
    private let decisionOperators: Set<String> = ["??", "&&", "||"]

    private func incrementComplexity() -> SyntaxVisitorContinueKind {
        complexity += 1
        return .visitChildren
    }

    override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind {
        incrementComplexity()
    }

    override func visit(_ node: GuardStmtSyntax) -> SyntaxVisitorContinueKind {
        incrementComplexity()
    }

    override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
        incrementComplexity()
    }

    override func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind {
        incrementComplexity()
    }

    override func visit(_ node: RepeatStmtSyntax) -> SyntaxVisitorContinueKind {
        incrementComplexity()
    }

    override func visit(_ node: SwitchCaseSyntax) -> SyntaxVisitorContinueKind {
        incrementComplexity()
    }

    override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind {
        incrementComplexity()
    }

    override func visit(_ node: TernaryExprSyntax) -> SyntaxVisitorContinueKind {
        incrementComplexity()
    }

    override func visit(_ node: UnresolvedTernaryExprSyntax) -> SyntaxVisitorContinueKind {
        incrementComplexity()
    }

    override func visit(_ node: BinaryOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        if decisionOperators.contains(node.operator.text) {
            return incrementComplexity()
        }
        return .visitChildren
    }
}
