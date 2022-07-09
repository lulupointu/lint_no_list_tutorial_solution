// This is the entrypoint of our custom linter
import 'dart:isolate';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

void main(List<String> args, SendPort sendPort) {
  startPlugin(sendPort, _ExampleLinter());
}

// This class is the one that will analyze Dart files and return lints
class _ExampleLinter extends PluginBase {
  @override
  Stream<Lint> getLints(ResolvedUnitResult unit) async* {
    // A basic lint that shows at the top of the file.
    yield Lint(
      code: 'my_custom_lint_code',
      message: 'This is the description of our custom lint',
      // Where your lint will appear within the Dart file.
      // The following code will make appear at the top of the file (offset 0),
      // and be 10 characters long.
      location: unit.lintLocationFromOffset(0, length: 10),
    );
  }
}
