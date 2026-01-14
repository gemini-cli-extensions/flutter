// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:release_scripts/src/build_release_command.dart';
import 'package:release_scripts/src/utils.dart';

Future<void> main(List<String> args) async {
  await runScript((context) async {
    if (args.isNotEmpty) {
      throw ExitException(
        'Unexpected arguments: ${args.join(' ')}\nUsage: build_release',
      );
    }

    await BuildReleaseCommand(context).run();
  });
}
