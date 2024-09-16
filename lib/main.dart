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
          const SomeWidget(
            data: 1,
          ),
          if (data != 'youpi')
            const SomeWidget(
              data: 2,
            ),
          const SomeWidget(
            data: 3,
          ),
        ],
      ),
    )));
  }
}

class SomeWidget extends RearchConsumer {
  final int data;
  const SomeWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context, WidgetHandle use) {
    scopeCapsule.override((use) {
      final (count, setCount) = use.state(data);
      return (count, () => setCount(count + 1));
    }, [data]);

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

(int, void Function()) scopeCapsule(CapsuleHandle use) => abstractCapsule;

extension Override<T> on Capsule<T> {
  void override(Capsule<T> newCapsule, [List<Object?>? keys]) =>
      (this, newCapsule);
}

Never get abstractCapsule => throw StateError(
    'An abstract capsule cannot be used if not implemented first'
    "(as its implementation won't exist yet)! "
    'To implement it you need to call .override in a widget build method'
    "and provide the concrete implementation");

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
