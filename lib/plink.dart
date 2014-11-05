library plink;

import 'dart:mirrors';
import 'dart:async';
import 'package:u_til/u_til.dart';

part 'src/adapter.dart';
part 'src/mapper.dart';
part 'src/relation.dart';
part 'src/structure.dart';
part 'src/migration.dart';
part 'src/model.dart';


String str(Object obj) {
  if (obj is Symbol) return $(obj).name;
  return obj.toString();
}