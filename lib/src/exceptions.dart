part of plink;


class UnsupportedTypeError extends UnsupportedError {
  UnsupportedTypeError(Type type)
      : super($(type).name + " is not a supported type");
}