import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const App());
  // runApp(const MaterialApp(home: ExerciceView()));
  // runApp(const MaterialApp(home: SimpleWidget()));
}

// TODO(andrflor): find a way to cleanup on umount for capsules
class App extends FlowWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final (value, setter) = $state('youpi');
    final (initial, otherSetter) = $(countIncrementor);
    final countPrevious = $previous(initial);
    $watch(value, (value) => print('the value is $value'));
    $effect(() {
      print('hey');
    }, initial < 0);
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
          Text(countPrevious.toString()),
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

Future<int> myFuture = Future.value(4);

class SimpleWidget extends FlowWidget {
  const SimpleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final result = $(getSome);

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      switch (result) {
        AsyncLoading<int>() => const CircularProgressIndicator(),
        AsyncError<int>() => const Text('Error'),
        AsyncSuccess<int>(:final data) => Text('Success $data'),
      }
    ]);
  }
}

final Map<Function(), _CapsuleFlow> _flows = {};
_NodeFlow? _currentFlow;

T $effect<T>(Effect<T> Function() effectCallback, [Object? key]) {
  assert(
      _currentFlow != null,
      throw StateError(
          'Only use side effects inside a capsule or a FlowWidget build'));
  return _currentFlow!.effect(effectCallback, key);
}

T $<T>(T Function() capsule) {
  assert(_currentFlow != null,
      throw StateError('Only use \$ inside a capsule or a FlowWidget build'));
  return ((_flows[capsule] ??= _CapsuleFlow(capsule))
        ..dependencies.add(_currentFlow!..flowIn.add(_flows[capsule]!)))
      .data;
}

class _CapsuleFlow<T> extends _NodeFlow<T> {
  final Set<_NodeFlow> dependencies = {};

  _CapsuleFlow(super.capsule) {
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
    if (building) {
      return;
    }
    building = true;
    cacheIndex = 0;
    final oldData = data;
    this();
    if (oldData != data) {
      for (final capsuleFlow in dependencies) {
        capsuleFlow.rebuild();
      }
    }
    building = false;
  }
}

class _TopFlow extends _NodeFlow<void> {
  _TopFlow(super.capsule);

  @override
  void rebuild() {
    if (building) return;
    building = true;
    cacheIndex = 0;
    capsule();
    building = false;
  }
}

typedef Effect<T> = (T Function()?, VoidCallback?)?;

Effect<int> someEffect() => (() => 0, null);

E $map<T, E>(T value, E Function(T) mapper) {
  // TODO(andrflor): implement map and other operators
}

(int, void Function(int)) $count(int value) => $state(value);

TextEditingController $textEditingController(
        {String? initialText, Object? key}) =>
    $effect(() {
      final controller = TextEditingController(text: initialText);
      return (() => controller, controller.dispose);
    }, key);

void $listen<T extends Listenable>(T listenable, VoidCallback listener) =>
    $effect(() {
      listenable.addListener(listener);
      return (null, () => listenable.removeListener(listener));
    }, listenable);

typedef Reducer<State, Action> = State Function(State, Action);

(State, void Function(Action)) $reducer<State, Action>(
  Reducer<State, Action> reducer,
  State initialState,
) {
  final (state, setState) = $state(initialState);
  return (state, (action) => setState(reducer(state, action)));
}

T? $previous<T>(T current) {
  final (cache, setCache) = $data<(T?, T)>((null, current));
  if (current != cache.$2) {
    setCache((cache.$2, current));
    return cache.$2;
  }
  return cache.$1;
}

List<T> $cache<T>(T current, [int depth = 1000]) {
  final (cache, setCache) = $data<List<T>>([current]);
  if (current != cache.last) {
    cache.add(current);
  }
  while (cache.length > depth) {
    cache.removeAt(0);
  }
  return cache;
}

(T, VoidCallback?, VoidCallback?) $replay<T>(T current) => $effect(() {
      T lastValue = current;
      Node<T> node = Node(current);
      final rebuild = $rebuild();
      void next() {
        node = node.next!;
        rebuild();
      }

      void previous() {
        node = node.previous!;
        rebuild();
      }

      return (
        () {
          if (lastValue != current) {
            Node<T>? newNode = node.next;
            while (newNode != null) {
              node.previous = null;
              newNode = node.next;
            }
            node = node.next = Node(current);
            lastValue = current;
          }

          return (
            node.value,
            (node.hasPrevious ? previous : null),
            (node.hasNext ? next : null),
          );
        },
        null
      );
    });

class Node<T> {
  Node<T>? previous;
  Node<T>? next;

  bool get hasNext => next != null;
  bool get hasPrevious => previous != null;

  T value;
  Node(this.value);
}

void $onDispose(VoidCallback dispose) => $effect(() => (null, dispose));

void $dispose<T>(T disposable, Function(T) disposer) =>
    $effect(() => (null, () => disposer(disposable)), disposable);

void $autoDispose<T>(T disposable) => $effect(() {
      assert(
          (disposable as dynamic).dipose is VoidCallback,
          throw ArgumentError(
              'You used autoDispose on an element that does not have a dispose function'));
      return (null, (disposable as dynamic).dispose);
    }, disposable);

bool firstRun() {
  final (firstRun, setFirstRun) = $data<bool>(true);
  setFirstRun(false);
  return firstRun;
}

void $watch<T>(T value, Function(T) watcher) {
  final watch = !firstRun();
  $effect(() {
    if (watch) {
      watcher(value);
    }
  }, value);
}

// TODO(andrflor): rebuild during capsule build should be forbidden??
void Function() $rebuild() => _currentFlow?.rebuild ?? () {};

T $memo<T>(T Function() memo, [Object? key]) => $effect(() {
      final value = memo();
      return (() => value, null);
    }, key);

AsyncState<T> $future<T>(Future<T> future) => $effect(() {
      AsyncState<T> asyncState = const AsyncLoading();
      AsyncState<T> stateGetter() => asyncState;
      if (asyncState is AsyncLoading) {
        final rebuild = $rebuild();
        future.then((data) {
          asyncState = AsyncSuccess(data);
          rebuild();
        }, onError: (error) {
          asyncState = AsyncError(error);
          rebuild();
        });
      }
      return (stateGetter, null);
    }, future);

AsyncState<T> $stream<T>(Stream<T> stream) => $effect(() {
      AsyncState<T> asyncState = const AsyncLoading();
      AsyncState<T> stateGetter() => asyncState;
      final rebuild = $rebuild();
      final subscription = stream.listen((data) {
        asyncState = AsyncSuccess(data);
        rebuild();
      }, onError: (error) {
        asyncState = AsyncError(error);
        rebuild();
      });
      return (stateGetter, subscription.cancel);
    }, stream);

(T, void Function(T)) $data<T>(T initial) => $effect(() {
      T data = initial;
      void setData(T e) {
        if (data != e) {
          data = e;
        }
      }

      return (() => (data, setData), null);
    });

(T, void Function(T)) $state<T>(T initial) => $effect(() {
      final rebuild = $rebuild();
      T data = initial;
      void setData(T e) {
        if (data != e) {
          data = e;
          rebuild();
        }
      }

      return (() => (data, setData), null);
    });

abstract class _NodeFlow<T> {
  int cacheIndex = 0;
  bool building = false;
  final Set<_CapsuleFlow> flowIn = {};
  late final T Function() capsule;
  final List<((Function()?, VoidCallback?)?, Object?)> indexCache = [];
  _NodeFlow(this.capsule);

  T effect(Effect<T> Function() effect, Object? key) {
    if (indexCache.length == cacheIndex) {
      indexCache.add((effect(), key));
      return indexCache[cacheIndex++].$1?.$1?.call();
    }
    final cache = indexCache[cacheIndex];
    if (cache.$2 != key) {
      cache.$1?.$2?.call();
      return ((indexCache[cacheIndex++] = (effect(), key)).$1?.$1)?.call() as T;
    }
    cacheIndex++;
    return (cache.$1?.$1)?.call() as T;
  }

  @mustCallSuper
  void dispose() {
    for (final flow in flowIn) {
      flow.dependencies.remove(this);
    }
    for (final cached in indexCache) {
      cached.$1?.$2?.call();
    }
    indexCache.clear();
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

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(initial.toString()),
      Text(countPlusOne.toString()),
      ElevatedButton(onPressed: () => otherSetter(), child: Text('decrement')),
    ]);
  }
}

class SomeWidget extends FlowWidget {
  final int data;
  const SomeWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // scopeCapsule.override((use) {
    //   final (count, setCount) = $state(data);
    //   return (count, () => setCount(count + 1));
    // }, [data]);
    // $automaticKeepAlive();

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

class SomeOtherWidget extends FlowWidget {
  const SomeOtherWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final (count, setCount) = $(scopeCapsule);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count.toString()),
        ElevatedButton(onPressed: setCount, child: const Text('Inner'))
      ],
    );
  }
}

(int, void Function()) scopeCapsule() => throw UnimplementedError();

Future<int> deleyadedFuture() => deleyadedFutureFactory(1)();
Future<int> Function() deleyadedFutureFactory(int ratio) => () {
      final (count, setState) = $(counterCapsule);
      Future.delayed(Duration(seconds: 4 * ratio), () => setState(count + 1));
      return Future.delayed(Duration(seconds: 2 * ratio), () => count)
          .then((delayed) => delayed + 1);
    };

AsyncState<int> getSome() {
  final delayed = $(deleyadedFuture);
  $effect(() {
    return (null, () => print('diposed ${delayed.hashCode}'));
  }, delayed);
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

(int, void Function(int)) counterCapsule() => $state(0);

(int, void Function()) countIncrementor() {
  final (count, setCount) = $(counterCapsule);
  return (count, () => setCount(count + 1));
}

(int, void Function()) countDecrementor() {
  final (count, setCount) = $(counterCapsule);
  return (count, () => setCount(count - 1));
}

// This capsule provides the current count, plus one.
int countPlusOneCapsule() => $(countIncrementor).$1 % 2;

class ExerciceView extends FlowWidget {
  const ExerciceView({super.key});
  @override
  Widget build(BuildContext context) {
    final (exerciceState, exerciceDispatch) = $(exerciceReducerCapsule);
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

class ModifyExercice extends FlowWidget {
  final Exercice? exercice;
  const ModifyExercice({super.key, this.exercice});

  @override
  Widget build(BuildContext context) {
    final (_, exerciceDispatch) = $(exerciceReducerCapsule);
    final nameController = $textEditingController(initialText: exercice?.name);
    final bodypartController =
        $textEditingController(initialText: exercice?.bodyPart);
    final (valid, setValid) = $state(false);
    $effect(() {
      void validate() {
        setValid(nameController.text.isNotEmpty &&
            bodypartController.text.isNotEmpty &&
            (exercice == null ||
                (nameController.text != exercice!.name ||
                    bodypartController.text != exercice!.bodyPart)));
      }

      nameController.addListener(validate);
      bodypartController.addListener(validate);
    }, (nameController, bodypartController));
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

List<Exercice> exerciceCapsule() => _initExercices;

String bodyFilter = '';
String exerciceFilter = '';

(ExerciceState, Function(ExerciceAction)) exerciceReducerCapsule() {
  final exercices = $(exerciceCapsule);

  return $reducer((state, action) {
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
