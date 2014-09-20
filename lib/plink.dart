library plink;

import 'dart:mirrors';
import 'dart:async';
import 'package:u_til/u_til.dart';

part 'model_repository.dart';
part 'database_adapter.dart';

const Object ignore = const Object();

_shouldBeIgnored(ClassMirror mirror) =>
    mirror.metadata.any((elem) => elem.reflectee == ignore);

@ignore
class Model {
  int id;
  DateTime created_at;
  DateTime updated_at;
  
  Future<Model> save() => REPO.save(this);
  Future delete() {
    if (id == null)
      return new Future.error("Cannot delete non persistent model");
    return REPO.delete(this.runtimeType, id);
  }
}