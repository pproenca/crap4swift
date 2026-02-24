import SwiftSyntax

class ComplexityVisitor: SyntaxVisitor {
    var complexity: Int = 1

    override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1
        return .visitChildren
    }

    override func visit(_ node: GuardStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1
        return .visitChildren
    }

    override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1
        return .visitChildren
    }

    override func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1
        return .visitChildren
    }

    override func visit(_ node: RepeatStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1
        return .visitChildren
    }

    override func visit(_ node: SwitchCaseSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1
        return .visitChildren
    }

    override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1
        return .visitChildren
    }

    override func visit(_ node: TernaryExprSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1
        return .visitChildren
    }

    override func visit(_ node: UnresolvedTernaryExprSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1
        return .visitChildren
    }

    override func visit(_ node: BinaryOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        let op = node.operator.text
        if op == "??" || op == "&&" || op == "||" {
            complexity += 1
        }
        return .visitChildren
    }
}
