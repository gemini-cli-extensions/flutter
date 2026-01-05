// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:release_scripts/src/bump_version_command.dart';
import 'package:release_scripts/src/utils.dart';

Future<void> main(List<String> args) async {
  await runScript((context) async {
    if (args.isEmpty) {
      throw ExitException('Usage: bump_version <new_version>');
    }
    await BumpVersionCommand(context, args[0]).run();
  });
}
