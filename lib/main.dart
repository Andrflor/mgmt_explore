import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

void main() {
  // runApp(const App());
  runApp(const MaterialApp(home: ExerciceView()));
  // runApp(const MaterialApp(home: SimpleWidget()));
}

// TODO(andrflor): find a way to cleanup on umount for capsules
class App extends VxWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final (value, setter) = $state('youpi');
    final (initial, otherSetter) = $(countIncrementor);
    final countPrevious = $previous(initial);
    $watch(value, () {
      print('the value is $value');
    });
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
          // const SomeWidget(
          //   key: ValueKey(1),
          //   data: 1,
          // ),
          if (value != 'youpi')
            // const SomeWidget(
            //   key: ValueKey(2),
            //   data: 2,
            // ),
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

class SimpleWidget extends VxWidget {
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

T $effect<T>(Effect<T>? Function() effect, [Object? key]) =>
    $(Vx._effect(effect), key);

void $dispose(VoidCallback dispose) => $(Vx._effect(() => (null, dispose)));
T $memo<T>(T Function() memo, [Object? key]) => $(Vx(memo), key);

void $watch<T>(Object? data, void Function() callback) =>
    $(Vx($firstBuild() ? () {} : callback), data);

TextEditingController $textEditingController({String? text}) => $effect(() {
      final controller = TextEditingController(text: text);
      return (() => controller, () => controller.dispose());
    });

bool $firstBuild() => (Vx._currentVx as dynamic).firstBuild;

T? $previous<T>(T current) {
  final (cache, setCache) = $state<(T?, T)>((null, current));
  if (current != cache.$2) {
    setCache((cache.$2, current));
    return cache.$2;
  }
  return cache.$1;
}

AsyncState<T> $future<T>(Future<T> future) => $memo(() {
      final (state, setState) = $state<AsyncState<T>>(const AsyncLoading());
      if ($firstBuild()) {
        future.then((data) => setState(AsyncSuccess(data)),
            onError: (error) => setState(AsyncError(error)));
      }
      return state;
    }, future);

(T, void Function(T)) $state<T>(T initial) => $(Vx._state(initial));

typedef Reducer<State, Action> = State Function(State, Action);

(State, void Function(Action)) $reducer<State, Action>(
  Reducer<State, Action> reducer,
  State initialState,
) {
  final (state, setState) = $state(initialState);
  return (state, (Action action) => setState(reducer(state, action)));
}

typedef VoidCallback = void Function();

VoidCallback $rebuild() => Vx._currentVx?._rebuild ?? () {};
T $<T>(Vx<T> vx, [Object? key]) => Vx._currentVx!._register(vx, key);

typedef Effect<T> = (T Function()?, VoidCallback?);
typedef Effector<T> = Effect<T>? Function();

class _VxCompute<E> extends _VxData<E> {
  final List<Vx> _dependencies = [];
  List<CacheEntry>? _cache;
  int _idx = -1;
  E Function()? _compute;
  _VxCompute();
  _VxCompute._(this._compute);

  bool get firstBuild => _idx + 1 == _cache?.length;

  @override
  void _dispose() {
    if (_cache == null) return;
    for (final elt in _cache!) {
      elt.vx._removeDependency(this);
    }
    _cache = null;
  }

  @override
  void _addDependency(Vx vx) {
    if (_dependencies.isEmpty && _cache == null) {
      _idx = -1;
      _cache = [];
      final currentVx = Vx._currentVx;
      Vx._currentVx = this;
      _data = _compute!();
      Vx._currentVx = currentVx;
    }
    _dependencies.add(vx);
  }

  @override
  void _removeDependency(Vx vx) {
    _dependencies.remove(vx);
    if (_dependencies.isEmpty) {
      _dispose();
    }
  }

  @override
  void _rebuild() {
    _idx = -1;
    final oldData = _data;
    final currentVx = Vx._currentVx;
    Vx._currentVx = this;
    _data = _compute!();
    Vx._currentVx = currentVx;
    if (_data != oldData) {
      for (final dep in _dependencies) {
        dep._rebuild();
      }
    }
  }

  @override
  T _register<T>(Vx<T> vx, Object? key) {
    if (_cache!.length == ++_idx) {
      _cache!.add(CacheEntry<T>(vx.._addDependency(this), key));
      return vx._data;
    }
    final CacheEntry<T> cache = _cache![_idx] as CacheEntry<T>;
    if (cache.key != key) {
      cache.vx._removeDependency(this);
      _cache![_idx] = CacheEntry<T>(vx.._addDependency(this), key);
      return vx._data;
    }
    return cache.vx._data;
  }
}

class _VxState<T, E extends void Function(T)> extends _VxData<(T, E)> {
  Vx? _dependency;
  _VxState._(T initial) {
    _data = (initial, _setData as E);
  }

  @override
  void _addDependency(Vx vx) => _dependency = vx;

  @override
  void _removeDependency(Vx vx) => _dependency = null;

  @override
  void _rebuild() => _dependency?._rebuild();

  void _setData(T data) {
    if (_data.$1 == data) return;
    _data = (data, _setData as E);
    _rebuild();
  }
}

class _VxEffect<T> extends _VxCompute<T> {
  final Effect<T>? Function() _effect;
  VoidCallback? _onDispose;
  _VxEffect._(this._effect);

  @override
  void _addDependency(Vx vx) {
    if (_dependencies.isEmpty && _cache == null) {
      _idx = -1;
      _cache = [];
      final res = _effect();
      _onDispose = res?.$2;
      _compute = res?.$1 ??
          () {
            return null as T;
          };
      final currentVx = Vx._currentVx;
      Vx._currentVx = this;
      _data = _compute!();
      Vx._currentVx = currentVx;
    }
    _dependencies.add(vx);
  }

  @override
  void _dispose() {
    if (_cache == null) return;
    _onDispose?.call();
    for (final elt in _cache!) {
      elt.vx._removeDependency(this);
    }
    _cache = null;
  }
}

class CacheEntry<T> {
  final Vx<T> vx;
  Object? key;

  CacheEntry(this.vx, this.key);
}

class _VxData<T> extends _VxImpl<T> {
  _VxData._(this._data);
  _VxData();

  @override
  late T _data;

  @override
  void _addDependency(Vx vx) {}

  @override
  void _rebuild() {}

  @override
  void _removeDependency(Vx vx) {}
}

abstract class _VxImpl<_> implements Vx<_> {
  @override
  T _register<T>(Vx<T> vx, Object? key) => vx._data;

  @override
  void _dispose() {}
}

abstract class Vx<E> {
  static Vx? _currentVx;
  static Vx<(T, void Function(T))> _state<T>(T initial) =>
      _VxState<T, void Function(T)>._(initial);

  factory Vx._effect(Effect<E>? Function() effect) => _VxEffect._(effect);
  factory Vx._value(E value) => _VxData._(value);
  factory Vx(E Function() compute) => _VxCompute._(compute);

  late E _data;

  void _addDependency(Vx vx);
  void _removeDependency(Vx vx);

  T _register<T>(Vx<T> vx, Object? key);
  void _rebuild();
  void _dispose();
}

abstract class VxWidget extends StatelessWidget {
  const VxWidget({super.key});

  @override
  VxElement createElement() => VxElement(this);
}

class VxElement extends StatelessElement implements Vx<Null> {
  VxElement(super.widget);
  List<CacheEntry>? _cache = [];
  int _idx = -1;

  @override
  void _rebuild() => markNeedsBuild();

  @override
  T _register<T>(Vx<T> vx, Object? key) {
    if (_cache!.length == ++_idx) {
      _cache!.add(CacheEntry<T>(vx.._addDependency(this), key));
      return vx._data;
    }
    final CacheEntry<T> cache = _cache![_idx] as CacheEntry<T>;
    if (cache.key != key) {
      cache.vx._removeDependency(this);
      _cache![_idx] = CacheEntry<T>(vx.._addDependency(this), key);
      return vx._data;
    }
    return cache.vx._data;
  }

  bool get firstBuild => _idx + 1 == _cache?.length;

  @override
  Widget build() {
    _idx = -1;
    Vx._currentVx = this;
    return super.build();
  }

  @override
  void unmount() {
    _dispose();
    super.unmount();
  }

  @override
  Null _data;

  @override
  void _addDependency(Vx vx) {}

  @override
  void _dispose() {
    if (_cache == null) return;
    for (final elt in _cache!) {
      elt.vx._removeDependency(this);
    }
    _cache = null;
  }

  @override
  void _removeDependency(Vx vx) {}
}

class InnerWidget extends VxWidget {
  const InnerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final (initial, otherSetter) = $(countDecrementor);
    final countPlusOne = $(countPlusOneFlux);

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(initial.toString()),
      Text(countPlusOne.toString()),
      ElevatedButton(onPressed: () => otherSetter(), child: Text('decrement')),
    ]);
  }
}

void $override<T>(Vx vx, T Function() implementation, [Object? key]) {}

class SomeWidget extends VxWidget {
  final int data;
  const SomeWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    $override(scopeFlux, () {
      final (count, setCount) = $state(data);
      return (count, () => setCount(count + 1));
    }, data);

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

class SomeOtherWidget extends VxWidget {
  const SomeOtherWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final (count, setCount) = $(scopeFlux);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count.toString()),
        ElevatedButton(onPressed: setCount, child: const Text('Inner'))
      ],
    );
  }
}

final scopeFlux = Vx(() {
  final (state, setState) = $state(0);
  return (state, () => setState(2));
});

final deleyadedFuture = Vx(deleyadedFutureFactory(1));
Future<int> Function() deleyadedFutureFactory(int ratio) => () {
      final (count, setState) = $(counterFlux);
      Future.delayed(Duration(seconds: 4 * ratio), () => setState(count + 1));
      return Future.delayed(Duration(seconds: 2 * ratio), () => count)
          .then((delayed) => delayed + 1);
    };

final getSome = Vx(() {
  final delayed = $(deleyadedFuture);
  return $future(delayed);
});

final counterFlux = Vx(() => $state(0));
final countIncrementor = Vx(() {
  final (count, setCount) = $(counterFlux);
  return (count, () => setCount(count + 1));
});

final countDecrementor = Vx(() {
  final (count, setCount) = $(counterFlux);
  return (count, () => setCount(count - 1));
});

// This capsule provides the current count, plus one.
final countPlusOneFlux = Vx(() => $(countIncrementor).$1 % 2);

class ExerciceView extends VxWidget {
  const ExerciceView({super.key});
  @override
  Widget build(BuildContext context) {
    final (exerciceState, exerciceDispatch) = $(exerciceReducerFlux);
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

class ModifyExercice extends VxWidget {
  final Exercice? exercice;
  const ModifyExercice({super.key, this.exercice});

  @override
  Widget build(BuildContext context) {
    final (_, exerciceDispatch) = $(exerciceReducerFlux);
    final nameController = $textEditingController(text: exercice?.name);
    final bodypartController = $textEditingController(text: exercice?.bodyPart);
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

final exerciceFlux = Vx(() => _initExercices);

String bodyFilter = '';
String exerciceFilter = '';

final exerciceReducerFlux = Vx(() {
  final exercices = $(exerciceFlux);

  return $reducer<ExerciceState, ExerciceAction>((state, action) {
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
});

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
