library plink;

import 'dart:mirrors';
import 'dart:async';
import 'package:u_til/u_til.dart';

part 'model_repository.dart';
part 'database_adapter.dart';

const Object IGNORE = const Object();


_shouldBeIgnored(mirror) =>
    mirror.metadata.any((elem) => elem.reflectee == IGNORE);

@IGNORE
class Model {
  @PRIMARY_KEY @AUTO_INCREMENT
  int id;
  DateTime created_at;
  DateTime updated_at;
  
  Future<Model> save() => REPO.save(this);
  Future delete() {
    if (id == null)
      return new Future.error("Cannot delete non persistent model");
    beforeDelete();
    return REPO.delete(this.runtimeType, this.id);
  }
  
  static _isModelClass() => false;
  
  void beforeCreate() => null;
  void beforeUpdate() => null;
  void beforeDelete() => null;
}