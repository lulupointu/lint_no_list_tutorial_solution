// This is the entrypoint of our custom linter
import 'dart:isolate';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:source_gen/source_gen.dart';

void main(List<String> args, SendPort sendPort) {
  startPlugin(sendPort, _ExampleLinter());
}

// This class is the one that will analyze Dart files and return lints
class _ExampleLinter extends PluginBase {
  @override
  Stream<Lint> getLints(ResolvedUnitResult unit) async* {
    final variableDeclarations = <VariableDeclaration>[];
    unit.unit.visitChildren(
      RecursiveVariableDeclarationVisitor(
        onVisitVariableDeclaration: variableDeclarations.add,
      ),
    );

    final typeChecker = TypeChecker.fromRuntime(List);
    final variableDeclarationsOfLists = variableDeclarations.where(
      (variableDeclaration) {
        final type = variableDeclaration.declaredElement?.type;
        return type != null && typeChecker.isExactlyType(type);
      },
    ).toList();

    for (final variableDeclaration in variableDeclarationsOfLists) {
      final declaredElement = variableDeclaration.declaredElement;
      if (declaredElement == null) {
        return;
      }
      final startLintOffset = declaredElement.nameOffset;
      final lintLength = declaredElement.nameLength;
      yield Lint(
        code: 'use_immutable_lists',
        message: 'Don\'t work with Lists directly, use IList instead',
        severity: LintSeverity.error,
        location: unit.lintLocationFromOffset(
          startLintOffset,
          length: lintLength,
        ),
        getAnalysisErrorFixes: (lint) async* {
          // [unit] is the [ResolvedUnitResult] given by custom_lints
          final changeBuilder = ChangeBuilder(session: unit.session);

          await changeBuilder.addDartFileEdit(
            unit.libraryElement.source.fullName, // Path to the current file
            (fileEditBuilder) {
              final expression = variableDeclaration.initializer;
              if (expression != null) {
                final startOffset = expression.offset;
                final endOffset = startOffset + expression.length;
                fileEditBuilder
                  // Add "IList(" at the start of the expression
                  ..addSimpleInsertion(startOffset, 'IList(')
                  // Add ")" at the end of the expression
                  ..addSimpleInsertion(endOffset, ')');
              }
            },
          );

          final expression = variableDeclaration.initializer;
          final sourceChange = changeBuilder.sourceChange;
          sourceChange.message = "Replace expression with IList($expression)";

          yield AnalysisErrorFixes(
            lint.asAnalysisError(),
            fixes: [
              PrioritizedSourceChange(
                0,
                sourceChange,
              ),
            ],
          );
        },
      );
    }
  }
}

class RecursiveVariableDeclarationVisitor extends RecursiveAstVisitor<void> {
  RecursiveVariableDeclarationVisitor({
    required this.onVisitVariableDeclaration,
  });

  void Function(VariableDeclaration node) onVisitVariableDeclaration;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    onVisitVariableDeclaration(node);
    super.visitVariableDeclaration(node);
  }
}
