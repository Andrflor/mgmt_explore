import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rearch/flutter_rearch.dart';

void main() {
  // runApp(const App());
  // runApp(const MaterialApp(home: ExerciceView()));
  runApp(const MaterialApp(home: SimpleWidget()));
}

class App extends FlowWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final (value, setter) = $state('youpi');
    final (initial, otherSetter) = $(countIncrementor);
    final countPlusOne = $(countPlusOneCapsule);
    return MaterialApp(
        home: Scaffold(
            body: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextFormField(
            controller: TextEditingController(),
          ),
          Text(value),
          ElevatedButton(
            onPressed: () =>
                value == 'youpi' ? setter('othervalue') : setter('youpi'),
            child: const Text('click'),
          ),
          Text(initial.toString()),
          Text(countPlusOne.toString()),
          ElevatedButton(
            onPressed: otherSetter,
            child: const Text('clock'),
          ),
          const SomeWidget(
            key: ValueKey(1),
            data: 1,
          ),
          if (value != 'youpi')
            const SomeWidget(
              key: ValueKey(2),
              data: 2,
            ),
          const SomeWidget(
            key: ValueKey(3),
            data: 3,
          ),
          const InnerWidget(),
          // Expanded(
          //     child: ListView.builder(
          //         itemBuilder: (context, index) => SomeWidget(data: index)))
        ],
      ),
    )));
  }
}

class SimpleWidget extends FlowWidget {
  const SimpleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final result = $(getSome);
    print(result);

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      switch (result) {
        AsyncLoading<int>() => const CircularProgressIndicator(),
        AsyncError<int>() => Text('Error'),
        AsyncSuccess<int>(:final data) => Text('Success $data'),
      }
    ]);
  }
}

final Map<Function(), _CapsuleFlow> _flows = {};
_NodeFlow? _currentFlow;

T $register<T>(T Function() Function() effect, [VoidCallback? onDispose]) {
  assert(
      _currentFlow != null,
      throw StateError(
          'Only use side effects inside a capsule or a HookWidget build'));
  return _currentFlow!.register(effect, onDispose);
}

T $<T>(T Function() capsule) {
  assert(_currentFlow != null,
      throw StateError('Only use \$ inside a capsule or a HookWidget build'));
  return ((_flows[capsule] ??= _CapsuleFlow(capsule))
        ..dependencies.add(_currentFlow!))
      .data;
}

class _EffectFlow<T> extends _NodeFlow<T> {
  final _NodeFlow dependency;
  T? data;

  _EffectFlow(T Function() Function() effect, this.dependency,
      [VoidCallback? onDispose])
      : super._(onDispose) {
    capsule = effect();
  }

  void call() {
    final oldFlow = _currentFlow;
    _currentFlow = this;
    try {
      data = capsule();
    } finally {
      _currentFlow = oldFlow;
    }
  }

  @override
  void rebuild() {
    sideEffectIndex = 0;
    final oldData = data;
    this();
    if (oldData != data) {
      dependency.rebuild();
    }
  }
}

class _CapsuleFlow<T> extends _NodeFlow<T> {
  final Set<_NodeFlow> dependencies = {};

  _CapsuleFlow(super.capsule, [super.onDispose]) {
    this();
  }

  T? data;

  void call() {
    final oldFlow = _currentFlow;
    _currentFlow = this;
    try {
      data = capsule();
    } finally {
      _currentFlow = oldFlow;
    }
  }

  @override
  void rebuild() {
    sideEffectIndex = 0;
    final oldData = data;
    this();
    if (oldData != data) {
      for (final capsuleFlow in dependencies) {
        capsuleFlow.rebuild();
      }
    }
  }
}

class _TopFlow extends _NodeFlow<void> {
  _TopFlow(super.capsule);

  @override
  void rebuild() {
    sideEffectIndex = 0;
    capsule();
  }
}

(int, void Function(int)) $count(int value) => $state(value);

TextEditingController $textEditingController(
    {String? initialText, Object? deps = ()}) {
  final controller =
      $cache(() => TextEditingController(text: initialText), deps);
  $dispose(controller);
  return controller;
}

void Function() _voidEffect() => () {};
void $onDispose(VoidCallback? cleanup) => $register(_voidEffect, cleanup);
void $dispose<T>(T value) => $onDispose(() => (value as dynamic).dispose());

void $once(VoidCallback callback) => $register(() {
      callback();
      return _voidEffect();
    });

void $listen<T extends Listenable>(T listenable, VoidCallback listener) {
  $register(() {
    listenable.addListener(listener);
    return () {};
  }, () => listenable.removeListener(listener));
}

T? $previous<T>(T current) {
  final (value, setter) = $state<T?>(null);
  setter(current);
  return value;
}

void $effect(Function()? Function() effect, [Object? key]) {
  final previousKey = $previous(key);
  final (value, setter) = $state<Function()?>(null);
  if (previousKey != key || previousKey == null) {
    value?.call();
    final newValue = effect();
    setter(newValue);
  }
}

T $cache<T>(T Function() memo, [Object? key]) {
  final previousKey = $previous(key);
  final (value, setter) = $state<T?>(null);
  if (value == null || previousKey != key) {
    final value = memo();
    setter(value);
    return value;
  }
  return value;
}

void Function() $rebuild() => _currentFlow?.rebuild ?? () {};

(T Function(), void Function(T)) $stateGetter<T>(T initial) => $register(() {
      final rebuild = $rebuild();
      T data = initial;
      void setData(T e) {
        if (data != e) {
          data = e;
          rebuild();
        }
      }

      T getData() {
        return data;
      }

      return () => (getData, setData);
    });

(T, void Function(T)) $state<T>(T initial) => $register(() {
      final rebuild = $rebuild();
      T data = initial;
      void setData(T e) {
        if (data != e) {
          data = e;
          rebuild();
        }
      }

      return () => (data, setData);
    });

abstract class _NodeFlow<T> {
  int sideEffectIndex = 0;
  final VoidCallback? onDispose;
  late final T Function() capsule;
  final List<_EffectFlow> effects = [];
  _NodeFlow(this.capsule, [this.onDispose]);

  _NodeFlow._(this.onDispose);

  T register(T Function() Function() effect, [VoidCallback? onDispose]) {
    if (effects.length == sideEffectIndex) {
      effects.add(_EffectFlow(effect, this, onDispose));
    }
    return (effects[sideEffectIndex++]..call()).data as T;
  }

  @mustCallSuper
  void dispose() {
    onDispose?.call();
    for (final effect in effects) {
      effect.dispose();
    }
    effects.clear();
  }

  void rebuild();
}

abstract class FlowWidget extends StatelessWidget {
  const FlowWidget({super.key});

  @override
  StatelessElement createElement() => FlowElement(this);
}

class FlowElement extends StatelessElement {
  FlowElement(super.widget);
  late final _flow = _TopFlow(markNeedsBuild);

  @override
  Widget build() {
    final oldFlow = _currentFlow;
    _currentFlow = _flow;
    try {
      return super.build();
    } finally {
      _currentFlow = oldFlow;
    }
  }

  @override
  void unmount() {
    _flow.dispose();
    super.unmount();
  }
}

class InnerWidget extends FlowWidget {
  const InnerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final (initial, otherSetter) = $(countDecrementor);
    final countPlusOne = $(countPlusOneCapsule);
    final result = $(getSome);

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(initial.toString()),
      Text(countPlusOne.toString()),
      ElevatedButton(onPressed: () => otherSetter(), child: Text('decrement')),
      switch (result) {
        AsyncLoading<int>() => const CircularProgressIndicator(),
        AsyncError<int>() => Text('Error'),
        AsyncSuccess<int>(:final data) => Text('Success $data'),
      }
    ]);
  }
}

class SomeWidget extends HookWidget {
  final int data;
  const SomeWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    scopeCapsule.override((use) {
      final (count, setCount) = use.state(data);
      return (count, () => setCount(count + 1));
    }, [data]);
    use.automaticKeepAlive();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(data.toString()),
        const SomeOtherWidget(),
      ],
    );
  }
}

int sharedInt() => empty;
Never get empty => throw '';

class SomeOtherWidget extends HookWidget {
  const SomeOtherWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final (count, setCount) = use(scopeCapsule);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count.toString()),
        ElevatedButton(onPressed: setCount, child: const Text('Inner'))
      ],
    );
  }
}

(int, void Function()) scopeCapsule(CapsuleHandle use) => abstractCapsule;

Future<int> deleyadedFuture() => deleyadedFutureFactory(1)();
Future<int> Function() deleyadedFutureFactory(int ratio) => () {
      final (count, setState) = $(counterCapsule);
      Future.delayed(Duration(seconds: 4 * ratio), () => setState(count + 1));
      return Future.delayed(Duration(seconds: 2 * ratio), () => count)
          .then((delayed) => delayed + 1);
    };

AsyncState<int> getSome() {
  final delayed = $(deleyadedFuture);
  print(delayed.hashCode);
  return $future(delayed);
}

sealed class AsyncState<T> extends Equatable {
  const AsyncState();
}

class AsyncLoading<T> extends AsyncState<T> {
  const AsyncLoading();

  @override
  List<Object?> get props => [];
}

class AsyncError<T> extends AsyncState<T> {
  final Object error;
  const AsyncError(this.error);

  @override
  List<Object?> get props => [error];
}

class AsyncSuccess<T> extends AsyncState<T> {
  final T data;
  const AsyncSuccess(this.data);

  @override
  List<Object?> get props => [data];
}

AsyncState<T> $future2<T>(Future<T> future) {
  final (getter, setter) = $stateGetter<AsyncState<T>>(const AsyncLoading());
  $effect(() {
    // setter(const AsyncLoading());
    final subscription = future.asStream().listen(
        (e) => setter(AsyncSuccess(e)),
        onError: (e) => setter(AsyncError(e)));
    return subscription.cancel;
  }, future);
  // print((getter(), future.hashCode));
  return getter();
}

AsyncState<T> $future<T>(Future<T> future) => $register(() {
      AsyncState<T> asyncState = const AsyncLoading();
      StreamSubscription<T>? subscription;
      Future<T>? current;
      return () {
        final rebuild = $rebuild();
        if (future != current) {
          if (current != null) {
            current = future;
            asyncState = const AsyncLoading();
            rebuild();
          } else {
            current = future;
          }
          subscription?.cancel();
          subscription = future.asStream().listen((e) {
            asyncState = AsyncSuccess(e);
            rebuild();
          }, onError: (e) {
            asyncState = AsyncSuccess(e);
            rebuild();
          });
        }
        return asyncState;
      };
    });

(int, void Function(int)) counterCapsule() => $state(0);

(int, void Function()) countIncrementor() {
  final (count, setCount) = $(counterCapsule);
  return (count, () => setCount(count + 1));
}

(int, void Function()) countDecrementor() {
  final (count, setCount) = $(counterCapsule);
  return (count, () => setCount(count + 2));
}

// This capsule provides the current count, plus one.
int countPlusOneCapsule() => $(countIncrementor).$1 % 2;

class ExerciceView extends HookWidget {
  const ExerciceView({super.key});
  @override
  Widget build(BuildContext context) {
    final (exerciceState, exerciceDispatch) = use(exerciceReducerCapsule);
    return Scaffold(
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const Text('Exercice'),
              TextButton(
                  onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const Dialog(
                            child: ModifyExercice(),
                          )),
                  child: const Text('Nouveau')),
            ],
          ),
          TextFormField(
            onChanged: (String? text) =>
                exerciceDispatch(ExerciceFilter(filter: text)),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            DropdownButton(
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text('widget'),
                )
              ],
              onChanged: (_) {},
            ),
          ]),
          Expanded(
            child: switch (exerciceState) {
              ExerciceEmpty() => const Center(child: Text('No exercices')),
              ExerciceSuccess(data: List<Exercice> data) => ListView.builder(
                  itemBuilder: (BuildContext context, int index) =>
                      DisplayExercice(
                    exercice: data[index],
                  ),
                  itemCount: data.length,
                ),
            },
          ),
        ],
      ),
    );
  }
}

class ModifyExercice extends HookWidget {
  final Exercice? exercice;
  const ModifyExercice({super.key, this.exercice});

  @override
  Widget build(BuildContext context) {
    final (_, exerciceDispatch) = use(exerciceReducerCapsule);
    final nameController =
        use.textEditingController(initialText: exercice?.name);
    final bodypartController =
        use.textEditingController(initialText: exercice?.bodyPart);
    final (valid, setValid) = use.state(false);
    use.effect(() {
      void validate() {
        setValid(nameController.text.isNotEmpty &&
            bodypartController.text.isNotEmpty &&
            (exercice == null ||
                (nameController.text != exercice!.name ||
                    bodypartController.text != exercice!.bodyPart)));
      }

      nameController.addListener(validate);
      bodypartController.addListener(validate);
      return null;
    }, [nameController, bodypartController]);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Icon(Icons.close),
            ),
            Text(exercice == null
                ? 'Créer un nouvel exercice'
                : 'Modifer l\'exercice'),
            TextButton(
              onPressed: valid
                  ? (() {
                      exerciceDispatch(exercice == null
                          ? ExerciceCreate(
                              exercice: Exercice(
                                  name: nameController.text,
                                  bodyPart: bodypartController.text))
                          : ExerciceModify(
                              target: exercice!,
                              name: nameController.text,
                              bodyPart: bodypartController.text));
                      Navigator.of(context).pop();
                    })
                  : null,
              child: const Text("SAVE"),
            ),
          ],
        ),
        TextFormField(
          controller: nameController,
        ),
        TextFormField(
          controller: bodypartController,
        ),
      ],
    );
  }
}

class DisplayExercice extends StatelessWidget {
  final Exercice exercice;
  const DisplayExercice({super.key, required this.exercice});

  @override
  Widget build(BuildContext context) {
    return ListTile(
        title: Text(exercice.name),
        subtitle: Text(exercice.bodyPart),
        onTap: () => showDialog(
            context: context,
            builder: (_) => Dialog(child: ModifyExercice(exercice: exercice))));
  }
}

class Exercice extends Equatable {
  final String name;
  final String bodyPart;

  const Exercice({required this.name, required this.bodyPart});

  @override
  List<Object?> get props => [name, bodyPart];
}

List<Exercice> exerciceCapsule(CapsuleHandle use) => _initExercices;

String bodyFilter = '';
String exerciceFilter = '';

(ExerciceState, Function(ExerciceAction)) exerciceReducerCapsule(
    CapsuleHandle use) {
  final exercices = use(exerciceCapsule);

  return use.reducer((state, action) {
    switch (action) {
      case ExerciceModify(:final name, :final bodyPart, :final target):
        exercices[exercices.indexOf(target)] = Exercice(
            name: name ?? target.name, bodyPart: bodyPart ?? target.bodyPart);
      case ExerciceSwap(:final primary, :final secondary):
        final primaryIndex = exercices.indexOf(primary);
        final secondaryIndex = exercices.indexOf(secondary);
        exercices[primaryIndex] = secondary;
        exercices[secondaryIndex] = primary;
      case ExerciceFilter(:final filter):
        exerciceFilter = filter;
      case ExerciceCreate(:final exercice):
        exercices.add(exercice);
      case ExerciceCategoryFilter(:final filter):
        bodyFilter = filter;
    }

    return switch (state) {
      ExerciceEmpty() => const ExerciceEmpty(),
      ExerciceSuccess() => ExerciceSuccess(data: [
          ...exercices.where((e) =>
              e.bodyPart.toLowerCase().contains(bodyFilter.toLowerCase()) &&
              e.name.toLowerCase().contains(exerciceFilter.toLowerCase()))
        ]),
    };
  }, ExerciceSuccess(data: [...exercices]));
}

sealed class ExerciceAction {
  const ExerciceAction();
}

class ExerciceModify extends ExerciceAction {
  final String? name;
  final String? bodyPart;
  final Exercice target;

  const ExerciceModify({this.name, this.bodyPart, required this.target});
}

class ExerciceSwap extends ExerciceAction {
  final Exercice primary;
  final Exercice secondary;

  const ExerciceSwap({required this.primary, required this.secondary});
}

class ExerciceFilter extends ExerciceAction {
  final String filter;

  const ExerciceFilter({required String? filter}) : filter = filter ?? '';
}

class ExerciceCreate extends ExerciceAction {
  final Exercice exercice;

  const ExerciceCreate({required this.exercice});
}

class ExerciceCategoryFilter extends ExerciceAction {
  final String filter;

  const ExerciceCategoryFilter({required String? filter})
      : filter = filter ?? '';
}

final _initExercices = <Exercice>[
  const Exercice(name: "Squat", bodyPart: "Legs"),
  const Exercice(name: "Bench Press", bodyPart: "Chest"),
  const Exercice(name: "Deadlift", bodyPart: "Back"),
  const Exercice(name: "Pull-up", bodyPart: "Back"),
  const Exercice(name: "Shoulder Press", bodyPart: "Shoulders"),
  const Exercice(name: "Barbell Row", bodyPart: "Back"),
  const Exercice(name: "Leg Press", bodyPart: "Legs"),
  const Exercice(name: "Bicep Curl", bodyPart: "Arms"),
  const Exercice(name: "Tricep Pushdown", bodyPart: "Arms"),
  const Exercice(name: "Lat Pulldown", bodyPart: "Back"),
  const Exercice(name: "Lunge", bodyPart: "Legs"),
  const Exercice(name: "Leg Curl", bodyPart: "Hamstrings"),
  const Exercice(name: "Calf Raise", bodyPart: "Calves"),
  const Exercice(name: "Sit-up", bodyPart: "Abs"),
  const Exercice(name: "Plank", bodyPart: "Core"),
  const Exercice(name: "Fly", bodyPart: "Chest"),
  const Exercice(name: "T-Bar Row", bodyPart: "Back"),
  const Exercice(name: "Face Pull", bodyPart: "Shoulders"),
  const Exercice(name: "Dumbbell Press", bodyPart: "Chest"),
  const Exercice(name: "Crunch", bodyPart: "Abs")
];

@immutable
sealed class ExerciceState extends Equatable {
  const ExerciceState();
}

class ExerciceEmpty extends ExerciceState {
  const ExerciceEmpty();

  @override
  List<Object?> get props => [];
}

class ExerciceSuccess extends ExerciceState {
  final List<Exercice> data;

  const ExerciceSuccess({required this.data});

  @override
  List<Object?> get props => data;
}
