extension ObjectExtensions on Object {
  T? unwrapOrNull<T>() {
    if (this is T) {
      return this as T;
    }
    return null;
  }
}
