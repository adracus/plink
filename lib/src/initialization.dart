part of plink;

var _repo;
var defaultConfiguration = new Configuration();

ModelRepository get REPO {
  if (_repo == null) {
    _initialize();
  }
  return _repo;
}

void _initialize() {
  _repo = new ModelRepository._byConfig(defaultConfiguration);
}