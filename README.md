plink
=====

plink is a persistence link layer with minimal addition to your existing code.

Preparation
-----------

### Adapters

To use plink, you need to instantiate a database adapter and pass it to the
global `REPO` object. plink is shipped with a postgres adapter, which can be
instantiated as follows:

```dart
REPO.adapter =
  new PostgresAdapter("postgres://<username>:<password>@<host>:<port>/<database>");
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

To use all this functionality with ease, you should first instantiate a `ModelRepository`.
This object will then take care of all operations targeting your models. To do so, proceed
as follows:

```dart
var repo = new ModelRepository.global(adapter);
```

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

To find models by specific criteria, call the `where(Type type, Map<String, dynamic> condition)`
method on the `REPO` object. This will return a future with the desired models. Currently,
conditions can only be exact values (a map with field name and exact value). This is planned
to be improved.


Pull requests are highly appreciated!
