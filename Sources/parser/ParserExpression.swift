/*
   Copyright 2016 Ryuichi Saito, LLC

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

import source
import ast

extension Parser {
    /*
    - [_] expression → try-operator/opt/ prefix-expression binary-expressions/opt/
    */
    func parseExpression() throws -> Expression {
        return try _parseAndUnwrapParsingResult {
            self._parseExpression(self.currentToken, tokens: self.reversedTokens.map { $0.0 })
        }
    }

    func _parseExpression(head: Token?, tokens: [Token]) -> ParsingResult<Expression> {
        var remainingTokens = tokens
        var remainingHeadToken: Token? = head

        if let token = remainingHeadToken, case let .Punctuator(punctuatorType) = token where punctuatorType == .Amp {
            remainingHeadToken = remainingTokens.popLast()
            guard let identifier = readIdentifier(includeContextualKeywords: true, forToken: remainingHeadToken) else {
                return ParsingResult<Expression>.makeNoResult()
            }
            remainingTokens = skipWhitespacesForTokens(remainingTokens)
            remainingHeadToken = remainingTokens.popLast()
            let inOutExpr = InOutExpression(identifier: identifier)
            return ParsingResult<Expression>.makeResult(inOutExpr, tokens.count - remainingTokens.count)
        }

        var prefixOperator: String? = nil
        if let token = remainingHeadToken, case let .Operator(operatorString) = token {
            remainingHeadToken = remainingTokens.popLast()
            prefixOperator = operatorString
        }
        let parsePostfixExpressionResult = _parsePostfixExpression(remainingHeadToken, tokens: remainingTokens)
        if parsePostfixExpressionResult.hasResult {
            if let prefixOperator = prefixOperator {
                let prefixOperatorExpr = PrefixOperatorExpression(
                    prefixOperator: prefixOperator, postfixExpression: parsePostfixExpressionResult.result)
                return ParsingResult<Expression>.makeResult(prefixOperatorExpr, tokens.count - remainingTokens.count)
            }
            else {
                return ParsingResult<Expression>.wrap(parsePostfixExpressionResult)
            }
        }

        return ParsingResult<Expression>.makeNoResult()
    }

    /*
    - [x] expression-list → expression | expression `,` expression-list
    */
    func parseExpressionList() throws -> [Expression] {
        return try _parseAndUnwrapParsingResult {
            self._parseExpressionList(self.currentToken, tokens: self.reversedTokens.map { $0.0 })
        }
    }

    func _parseExpressionList(head: Token?, tokens: [Token]) -> ParsingResult<[Expression]> {
        var remainingTokens = tokens
        var remainingHeadToken: Token? = head

        let firstExpressionResult = _parseExpression(remainingHeadToken, tokens: remainingTokens)
        guard firstExpressionResult.hasResult else {
            return ParsingResult<[Expression]>.makeNoResult()
        }
        for _ in 0..<firstExpressionResult.advancedBy {
            remainingHeadToken = remainingTokens.popLast()
        }

        var expressions = [Expression]()
        expressions.append(firstExpressionResult.result)

        while let token = remainingHeadToken, case let .Punctuator(type) = token where type == .Comma {
            remainingTokens = skipWhitespacesForTokens(remainingTokens)
            remainingHeadToken = remainingTokens.popLast()

            let expressionResult = _parseExpression(remainingHeadToken, tokens: remainingTokens)
            guard expressionResult.hasResult else {
                return ParsingResult<[Expression]>.makeNoResult() // TODO: error handling
            }
            expressions.append(expressionResult.result)

            for _ in 0..<expressionResult.advancedBy {
                remainingHeadToken = remainingTokens.popLast()
            }
        }

        return ParsingResult<[Expression]>.makeResult(expressions, tokens.count - remainingTokens.count)
    }
}
