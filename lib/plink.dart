library plink;

import 'dart:mirrors';
import 'dart:async' show Future, Completer;
import 'dart:math' show min, max;
import 'package:u_til/u_til.dart';
import 'package:logging/logging.dart';

part 'src/reflection_util.dart';
part 'src/model_repository.dart';
part 'src/schema.dart';
part 'src/database_adapter.dart';
part 'src/exceptions.dart';
part 'src/model.dart';
part 'src/migrate.dart';
part 'src/configuration.dart';
part 'src/phonetic.dart';

final Logger log = new Logger("plink");