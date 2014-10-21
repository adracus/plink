part of plink;

class Configuration {
  bool autoMigrate;
  DatabaseAdapter adapter;
  int levenshteinThreshold;
  
  Configuration({this.autoMigrate: true,
                 this.adapter,
                 this.levenshteinThreshold: 3});
}