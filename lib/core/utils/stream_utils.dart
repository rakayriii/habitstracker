import 'dart:async';

/// Combines two streams into one that re-emits whenever either side changes,
/// keeping the latest value of the other.
///
/// Used where an aggregate spans more than one table, for example a finance
/// summary that depends on both accounts and transactions. Written by hand so
/// the app does not grow a dependency for a six line operator.
Stream<R> combineLatest2<A, B, R>(
  Stream<A> first,
  Stream<B> second,
  R Function(A a, B b) combine,
) {
  late StreamController<R> controller;
  StreamSubscription<A>? firstSub;
  StreamSubscription<B>? secondSub;
  A? latestFirst;
  B? latestSecond;
  var hasFirst = false;
  var hasSecond = false;

  void emit() {
    if (!hasFirst || !hasSecond || controller.isClosed) return;
    controller.add(combine(latestFirst as A, latestSecond as B));
  }

  controller = StreamController<R>(
    onListen: () {
      firstSub = first.listen(
        (value) {
          latestFirst = value;
          hasFirst = true;
          emit();
        },
        onError: controller.addError,
        onDone: controller.close,
      );
      secondSub = second.listen(
        (value) {
          latestSecond = value;
          hasSecond = true;
          emit();
        },
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await firstSub?.cancel();
      await secondSub?.cancel();
    },
  );

  return controller.stream;
}

/// Three stream version, used by the project aggregate, which spans projects,
/// tags and tasks.
Stream<R> combineLatest3<A, B, C, R>(
  Stream<A> first,
  Stream<B> second,
  Stream<C> third,
  R Function(A a, B b, C c) combine,
) {
  return combineLatest2(
    combineLatest2(first, second, (a, b) => (a, b)),
    third,
    (pair, c) => combine(pair.$1, pair.$2, c),
  );
}
