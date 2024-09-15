import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_rearch/flutter_rearch.dart';
import 'package:rearch/rearch.dart';

void main() {
  runApp(const RearchBootstrapper(child: BaseWidget()));
}

class BaseWidget extends RearchConsumer {
  const BaseWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetHandle use) {
    final (data, setter) = use.state('youpi');
    final (initial, otherSetter) = use.state(8);
    return MaterialApp(
        home: Scaffold(
            body: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextFormField(
            controller: TextEditingController(),
          ),
          Text(data),
          ElevatedButton(
            onPressed: () =>
                data == 'youpi' ? setter('othervalue') : setter('youpi'),
            child: const Text('click'),
          ),
          ElevatedButton(
            onPressed: () => otherSetter(initial + 1),
            child: const Text('clock'),
          ),
          Consumer(
            key: ValueKey('1'),
            data: initial,
          ),
          if (data != 'youpi')
            Consomer(
              key: ValueKey('2'),
            ),
          // Consomer(
          //   key: ValueKey('3'),
          // ),
        ],
      ),
    )));
  }
}

class Consumer extends RearchConsumer {
  final int? data;
  const Consumer({super.key, this.data});

  @override
  Widget build(BuildContext context, WidgetHandle use) {
    final count = use(getSome);
    final (internalCount, setCount) = use(use.inject(scopedCount, data ?? 0));
    final (some, setter) = use.retreive(scopedCount);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(internalCount.toString()),
        Text(some.toString()),
        switch (count) {
          AsyncData<int>(:final data) => Text(data.toString()),
          AsyncLoading<int>() => const CircularProgressIndicator(),
          AsyncError<int>() => const Icon(Icons.error),
        },
        ElevatedButton(onPressed: setCount, child: const Text('inc')),
      ],
    );
  }
}

class SomeClass {}

final someClass = SomeClass();

final Expando<Map<Function, Function>> _expando =
    Expando<Map<Function, Function>>();

extension Scoped on WidgetHandle {
  Capsule<T> inject<T, E>(
      T Function(CapsuleHandle use, E) capsuleFactory, E arg) {
    final capsule = memo(() => (use) => capsuleFactory(use, arg), [arg]);
    effect(() {
      (_expando[this] ??= {})[capsuleFactory] = capsule;
      return () => _expando[this]?.remove(capsuleFactory);
    }, [capsule]);
    return capsule;
  }

  T retreive<T, E>(T Function(CapsuleHandle use, E) capsuleFactory) =>
      this(_expando[this]![capsuleFactory]! as Capsule<T>);
}

class Consomer extends RearchConsumer {
  const Consomer({super.key});

  @override
  Widget build(BuildContext context, WidgetHandle use) {
    final count = use(getSome);
    return switch (count) {
      AsyncData<int>(:final data) => Text(data.toString()),
      AsyncLoading<int>() => const CircularProgressIndicator(
          color: Colors.red,
        ),
      AsyncError<int>() => const Icon(Icons.error),
    };
  }
}

(int, void Function()) scopedCount(CapsuleHandle use, int startingCount) {
  final (count, setCount) = use.state(startingCount);
  return (count, () => setCount(count + 1));
}

int countCapsule(CapsuleHandle use) => 0;

Future<int> deleyadedFuture(CapsuleHandle use) {
  final (count, setState) = use.state(0);
  Future.delayed(const Duration(seconds: 4), () => setState(count + 1));
  return Future.delayed(const Duration(seconds: 2), () => count)
      .then((delayed) => delayed + 1);
}

AsyncValue<int> getSome(CapsuleHandle use) {
  final delayed = use(deleyadedFuture);
  return use.future(delayed);
}
