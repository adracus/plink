plink
=====
[![Build Status](https://drone.io/github.com/Adracus/plink/status.png)](https://drone.io/github.com/Adracus/plink/latest)

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
It supports `int`, `double`, `DateTime` and `String` as so called _PRIMITIVES_. It is also possible
to define `List`s of those primitive types.

The other class of supported field types are other models and Lists of other models (Maps and
Sets are currently planned as well as the support of superclass types [e.g Car as superclass
and Sportscar and Van as subclass] but not implemented). Example:

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

To persist such a Name object, instantiate it and then call the `save()` method. This returns
a Future which completes with the saved instance. Save also saves nested models.

### Deleting

Deletion of model instances works the same way and only differs by returning a Future which
completes with null. Deleting can happen in two different ways: Recursive and non-recursive:
For example, if you've got a Class with a list of other models and you delete non-recursive,
instances in those list are not deleted. If you delete recursive, they are also deleted.
If you use PRIMITIVE lists, the values are always deleted.

### Finding by id

To find a model by its id, you have to call the `find(Type type, int id)` method on the global
`ModelRepository` `REPO` object (`type` should be the type of the desired object, in the previously
mentioned case it would be `Name`). This returns a future with the desired model.

### Finding by specific criteria

To find models by specific criteria, call the `where(Type type, Map<String, dynamic> condition)`
method on the `REPO` object. This will return a future with the desired models. Currently,
conditions can only be exact values (a map with field name and exact value). This is planned
to be improved.


Pull requests are highly appreciated!
