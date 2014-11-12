plink
=====

plink is a persistence link layer with minimal addition to your existing code.

Preparation
-----------

### Adapters

To use plink, you need to instantiate a database adapter. This adapter should then
be passed to a `ModelRepository` object, which takes care of the most important
things for you. An example:

```dart
var adapter = new PostgresAdapter(
  "postgres://<username>:<password>@<host>:<port>/<database>");
  
var repo = new ModelRepository.global(adapter);
```

### Subclassing

If you want to be able to persist your class, it's as easy as that:

```dart
class Name extends Model {
  String firstName;
  String lastName;
  
  Name();
}
```

Each subclass __needs__ a default constructor for plink to instantiate a default instance.
If you don't want to use the default constructor as plinks default constructor, you can also
define a named constructor and annotate `defaultConstructor` for plink to use:

```dart
class Name extends Model {
  String firstName;
  String lastName;
  
  Name(this.firstName, this.lastName);
  
  @defaultConstructor
  Name.def();
}
```

By extending from Model, your class automatically inherits the properties `id`, `created_at` and
`updated_at`, which then are automatically set by the so called `ModelRepository` when needed.
If you now wonder: _"Which field types does plink support?"_ - The answer is quite satisfactory:
It supports (nearly) **all** types of Dart: Maps, Lists, other Objects, ints, Strings and so on.


```dart
class Person {
  DateTime birthDate;
  Name name;
  
  Person(this.name, this.birthDate);
  
  @defaultConstructor
  Person.def();
}
```

Functionality
-------------

### Saving

To persist such a Name object, instantiate it and then call the `ModelRepository.save()`
method. This returns a Future which completes with the saved instance.
Save also saves nested models.

### Deleting

Deletion of model instances works the same way and only differs by returning a Future which
completes with null. To delete, call the `ModelRepository.delete` function with your model.

### Finding by id

To find a model by its id, you have to call the `find(Type type, int id)` method on the
`ModelRepository` object (`type` should be the type of the desired object, in the previously
mentioned case it would be `Name`). This returns a future with the desired model.

### Finding by specific criteria

A list of model instances can be fetched by using the `ModelRepository.where` method.
This method takes a type and a so called `WhereStatement`. These statements can be
created with ease, an example would be:

```dart
repo.where(TestClass, c("name").eq("Test"))
```

Currently supported matchers here are equals, not equals, greater than, less than,
greater than or equals and less than or equals.


Pull requests are highly appreciated!
