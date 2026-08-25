extension ObjectCastExtension on Object {
  T cast<T>() => this as T;
  T? castOrNull<T>() => this is! T ? null : cast<T>();
}
