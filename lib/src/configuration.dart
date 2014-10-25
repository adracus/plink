part of plink;

var defaultConfiguration = new Configuration();


class Configuration {
  final AutoMigrator migrator;
  
  Configuration({this.migrator: const AutoMigrator(3)});
}