part of plink;

class Configuration {
  final AutoMigrator migrator;
  
  Configuration({this.migrator: const AutoMigrator(3)});
}