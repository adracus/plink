library plink;

import 'dart:mirrors';
import 'dart:async';
import 'package:u_til/u_til.dart';
import 'package:plink/src/statement/statement.dart';

export 'package:plink/src/statement/statement.dart';

part 'src/adapter.dart';
part 'src/mapper.dart';
part 'src/relation.dart';
part 'src/structure.dart';
part 'src/migration.dart';
part 'src/model.dart';
part 'src/repository.dart';


String str(Object obj) {
  if (obj is Symbol) return $(obj).name;
  return obj.toString();
}