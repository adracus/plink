part of plink.test;

@proxy
class MockIndex extends Mock implements SchemaIndex {
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

@proxy
class MockAdapter extends Mock implements DatabaseAdapter {
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}


mapper_test() {
  group("Mapper", () {
    MockIndex index;
    MockAdapter adapter;
    Mapper mapper;
    
    setUp(() {
      index = new MockIndex();
      adapter = new MockAdapter();
    });
    
    group("Primitive", () {
      group("String", () {
        
        setUp(() {
          mapper = new StringMapper(index);
        });
        
        test("save", () {
          var insertCall = callsTo("insert", "plink.StringMapper",
              {"value": "test element"});
          adapter.when(insertCall)
                 .thenReturn(new Future.value(
                    {"id": 1, "value": "test element"}));
          index.when(callsTo("getAdapter"))
                    .thenReturn(new Future.value(adapter));
          
          mapper.save("test element").then(expectAsync((saved) {
            expect(saved.id, equals(1));
            expect(saved.value, equals("test element"));
            index.getLogs(callsTo("getAdapter")).verify(happenedOnce);
            adapter.getLogs(insertCall).verify(happenedOnce);
          }));
        });
        
        test("find", () {
          var insertCall = callsTo("where", "plink.StringMapper",
              {"id": 1});
          adapter.when(insertCall)
                 .thenReturn(new Future.value(
                     {"id": 1, "value": "test element"}));
          index.when(callsTo("getAdapter"))
                    .thenReturn(new Future.value(adapter));
          
          mapper.find(1).then(expectAsync((loaded) {
            expect(loaded, equals("test element"));
            index.getLogs(callsTo("getAdapter")).verify(happenedOnce);
            adapter.getLogs(insertCall).verify(happenedOnce);
          }));
        });
      });
      
      group("Int", () {
        
        setUp(() {
          mapper = new IntMapper(index);
        });
        
        test("save", () {
          var insertCall = callsTo("insert", "plink.IntMapper",
              {"value": 1234});
          adapter.when(insertCall)
                 .thenReturn(new Future.value(
                     {"id": 1, "value": 1234}));
          index.when(callsTo("getAdapter"))
                    .thenReturn(new Future.value(adapter));
          
          mapper.save(1234).then(expectAsync((saved) {
            expect(saved.id, equals(1));
            expect(saved.value, equals(1234));
            index.getLogs(callsTo("getAdapter")).verify(happenedOnce);
            adapter.getLogs(insertCall).verify(happenedOnce);
          }));
        });
        
        test("find", () {
          var insertCall = callsTo("where", "plink.IntMapper",
              {"id": 1});
          adapter.when(insertCall)
                 .thenReturn(new Future.value(
                     {"id": 1, "value": 1234}));
          index.when(callsTo("getAdapter"))
                    .thenReturn(new Future.value(adapter));
          
          mapper.find(1).then(expectAsync((loaded) {
            expect(loaded, equals(1234));
            index.getLogs(callsTo("getAdapter")).verify(happenedOnce);
            adapter.getLogs(insertCall).verify(happenedOnce);
          }));
        });
      });
      
      group("Double", () {
        
        setUp(() {
          mapper = new DoubleMapper(index);
        });
        
        test("save", () {
          var insertCall = callsTo("insert", "plink.DoubleMapper",
              {"value": 1234.234});
          adapter.when(insertCall)
                 .thenReturn(new Future.value(
                     {"id": 1, "value": 1234.234}));
          index.when(callsTo("getAdapter"))
                    .thenReturn(new Future.value(adapter));
          
          mapper.save(1234.234).then(expectAsync((saved) {
            expect(saved.id, equals(1));
            expect(saved.value, equals(1234.234));
            index.getLogs(callsTo("getAdapter")).verify(happenedOnce);
            adapter.getLogs(insertCall).verify(happenedOnce);
          }));
        });
        
        test("find", () {
          adapter.when(callsTo("where", "plink.DoubleMapper",
                               {"id": 1}))
                               .thenReturn(new Future.value(
                                   {"id": 1, "value": 1234.234}));
          index.when(callsTo("getAdapter"))
                    .thenReturn(new Future.value(adapter));
          
          mapper.find(1).then(expectAsync((loaded) {
            expect(loaded, equals(1234.234));
            index.getLogs(callsTo("getAdapter")).verify(happenedOnce);
            adapter.getLogs(callsTo("where", "plink.DoubleMapper",
                {"id": 1})).verify(happenedOnce);
          }));
        });
      });
    });
    
    group("Convert", () {
      group("Symbol", () {
        
        setUp(() {
          mapper = new SymbolMapper(index);
        });
        
        test("save", () {
          var insertCall = callsTo("insert", "plink.StringMapper",
              {"value": "testSymbol"});
          adapter.when(insertCall)
                 .thenReturn(new Future.value(
                     {"id": 1, "value": "testSymbol"}));
          index.when(callsTo("getAdapter"))
                    .thenReturn(new Future.value(adapter));
          
          mapper.save(#testSymbol).then(expectAsync((saved) {
            expect(saved.id, equals(1));
            expect(saved.value, equals(#testSymbol));
            index.getLogs(callsTo("getAdapter")).verify(happenedOnce);
            adapter.getLogs(insertCall).verify(happenedOnce);
          }));
        });
        
        test("find", () {
          var insertCall = callsTo("where", "plink.StringMapper",
              {"id": 1});
          adapter.when(insertCall)
                 .thenReturn(new Future.value(
                     {"id": 1, "value": "testSymbol"}));
          index.when(callsTo("getAdapter"))
                    .thenReturn(new Future.value(adapter));
          
          mapper.find(1).then(expectAsync((loaded) {
            expect(loaded, equals(#testSymbol));
            index.getLogs(callsTo("getAdapter")).verify(happenedOnce);
            adapter.getLogs(insertCall).verify(happenedOnce);
          }));
        });
      });
      
      group("Uri", () {
        var uriString;
        var uri;
        
        setUp(() {
          mapper = new UriMapper(index);
          uriString = "http://www.google.de";
          uri = Uri.parse(uriString);
        });
        
        test("save", () {
          var insertCall = callsTo("insert", "plink.StringMapper",
              {"value": uriString});
          adapter.when(insertCall)
                 .thenReturn(new Future.value(
                     {"id": 1, "value": uriString}));
          index.when(callsTo("getAdapter"))
                    .thenReturn(new Future.value(adapter));
          
          mapper.save(uri).then(expectAsync((saved) {
            expect(saved.id, equals(1));
            expect(saved.value, equals(uri));
            index.getLogs(callsTo("getAdapter")).verify(happenedOnce);
            adapter.getLogs(insertCall).verify(happenedOnce);
          }));
        });
        
        test("find", () {
          var insertCall = callsTo("where", "plink.StringMapper",
              {"id": 1});
          adapter.when(insertCall)
                 .thenReturn(new Future.value(
                     {"id": 1, "value": uriString}));
          index.when(callsTo("getAdapter"))
                    .thenReturn(new Future.value(adapter));
          
          mapper.find(1).then(expectAsync((loaded) {
            expect(loaded, equals(uri));
            index.getLogs(callsTo("getAdapter")).verify(happenedOnce);
            adapter.getLogs(insertCall).verify(happenedOnce);
          }));
        });
      });
    });
    
    group("Collection", () {
      var stringMapper;
      var intMapper;
      
      setUp(() {
        stringMapper = new StringMapper(index);
        intMapper = new IntMapper(index);
        index.when(callsTo("schemaFor", String)).alwaysReturn(stringMapper);
        index.when(callsTo("schemaFor", int)).alwaysReturn(intMapper);
      });
      
      group("List", () {
        
        setUp(() {
          mapper = new ListMapper(index);
        });
        
        group("save", () {
          test("empty", () {
            index.when(callsTo("getAdapter"))
                 .thenReturn(new Future.value(adapter), 2);
            
            var insertCall = callsTo("insert", "plink.ListMapper",
              {"index": 0, "targetTable": "", "targetId": 0});
            adapter.when(insertCall)
                   .thenReturn(new Future.value({
              "index": 0, "targetTable": "", "targetId": 0, "id": 1
            }));
            
            mapper.save([]).then(expectAsync((saved) {
              expect(saved.id, equals(1));
              expect(saved.value.length, equals(0));
              adapter.getLogs(insertCall).verify(happenedOnce);
              index.getLogs(callsTo("getAdapter")).verify(happenedExactly(2));
            }));
          });
          
          test("non-deep", () {
            index.when(callsTo("getAdapter"))
                 .alwaysReturn(new Future.value(adapter));
            var firstInsertCall = callsTo("insert", "plink.IntMapper",
                {"value": 1});
            var secondInsertCall = callsTo("insert", "plink.IntMapper",
                {"value": 2});
            var thirdInsertCall = callsTo("insert", "plink.IntMapper",
                {"value": 3});
            var fourthInsertCall = callsTo("insert", "plink.StringMapper",
                {"value": "test"});
            var firstListInsert = callsTo("insert", "plink.ListMapper",
                {"index": 0,
                 "targetTable": "plink.IntMapper",
                 "targetId": 1});
            var secondListInsert = callsTo("insert", "plink.ListMapper",
                {"id": 1, "index": 1,
                 "targetTable": "plink.IntMapper",
                 "targetId": 2});
            var thirdListInsert = callsTo("insert", "plink.ListMapper",
                {"id": 1, "index": 2,
                 "targetTable": "plink.IntMapper",
                 "targetId": 3});
            var fourthListInsert = callsTo("insert", "plink.ListMapper",
                {"id": 1, "index": 3,
                 "targetTable": "plink.StringMapper",
                 "targetId": 1});
            adapter.when(firstInsertCall)
                        .thenReturn(new Future.value({
                                      "id": 1, "value": 1}));
            adapter.when(secondInsertCall)
                        .thenReturn(new Future.value({
                                      "id": 2, "value": 2}));
            adapter.when(thirdInsertCall)
                        .thenReturn(new Future.value({
                                      "id": 3, "value": 3}));
            adapter.when(fourthInsertCall)
                        .thenReturn(new Future.value({
                                      "id": 1, "value": "test"}));
            adapter.when(firstListInsert)
                        .thenReturn(new Future.value(({
                          "index": 0,    "targetTable": "plink.IntMapper",
                          "targetId": 1, "id": 1
                        })));
            adapter.when(secondListInsert)
                        .thenReturn(new Future.value(({
                          "index": 1,    "targetTable": "plink.IntMapper",
                          "targetId": 2, "id": 1
                        })));
            adapter.when(thirdListInsert)
                        .thenReturn(new Future.value(({
                          "index": 2,    "targetTable": "plink.IntMapper",
                          "targetId": 3, "id": 1
                        })));
            adapter.when(fourthListInsert)
                        .thenReturn(new Future.value(({
                          "index": 3,    "targetTable": "plink.StringMapper",
                          "targetId": 1, "id": 1
                        })));
            
            mapper.save([1, 2, 3, "test"]).then(expectAsync((saved) {
              expect(saved.value.length, equals(4));
              expect(saved.value[0], equals(1));
              expect(saved.value[1], equals(2));
              expect(saved.value[2], equals(3));
              expect(saved.value[3], equals("test"));
              expect(saved.id, equals(1));
              adapter.getLogs(firstInsertCall).verify(happenedOnce);
              adapter.getLogs(secondInsertCall).verify(happenedOnce);
              adapter.getLogs(thirdInsertCall).verify(happenedOnce);
              adapter.getLogs(fourthInsertCall).verify(happenedOnce);
              adapter.getLogs(firstListInsert).verify(happenedOnce);
              adapter.getLogs(secondListInsert).verify(happenedOnce);
              adapter.getLogs(thirdListInsert).verify(happenedOnce);
              adapter.getLogs(fourthListInsert).verify(happenedOnce);
              index.getLogs(callsTo("getAdapter")).verify(happenedAtLeastOnce);
            }));
          });
        });
      });
    });
  });
}