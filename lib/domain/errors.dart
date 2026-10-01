/// Failures a repository can raise, in the vocabulary the UI needs.
///
/// Widgets never see a drift exception, a socket error or a stack trace: the
/// repository maps whatever the storage layer did into one of these, and each
/// one carries a message that is safe to show to a person.
sealed class AppException implements Exception {
  const AppException(this.message);

  /// Indonesian, user facing, no technical detail.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The input cannot be stored: a missing title, a zero amount, a deadline in
/// the past when the field forbids it, a transfer to the same account.
class ValidationException extends AppException {
  const ValidationException(super.message, {this.field});

  /// Optional field key so a form can highlight the input that failed.
  final String? field;
}

/// The row does not exist, or was deleted while the screen was open.
class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

/// The change would break a relationship, for example deleting an account that
/// still has transactions.
class ConflictException extends AppException {
  const ConflictException(super.message);
}

/// The database refused the write. Always actionable, never swallowed.
class StorageException extends AppException {
  const StorageException(super.message);
}
