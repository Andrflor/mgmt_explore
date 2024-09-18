import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rearch/flutter_rearch.dart';

void main() {
  // runApp(const App());
  runApp(const MaterialApp(home: ExerciceView()));
}

class App extends HookWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final (value, setter) = use.state('youpi');
    final (initial, otherSetter) = use(countManager);
    final countPlusOne = use(countPlusOneCapsule);
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
          // Expanded(
          //     child: ListView.builder(
          //         itemBuilder: (context, index) => SomeWidget(data: index)))
        ],
      ),
    )));
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

Future<int> deleyadedFuture(CapsuleHandle use) =>
    deleyadedFutureFactory(1)(use);
Future<int> Function(CapsuleHandle use) deleyadedFutureFactory(int ratio) =>
    (use) {
      final (count, setState) = use.state(0);
      Future.delayed(Duration(seconds: 4 * ratio), () => setState(count + 1));
      return Future.delayed(Duration(seconds: 2 * ratio), () => count)
          .then((delayed) => delayed + 1);
    };

AsyncValue<int> getSome(CapsuleHandle use) {
  final delayed = use(deleyadedFuture);
  return use.future(delayed);
}

(int, void Function()) countManager(CapsuleHandle use) {
  final (count, setCount) = use.state(0);
  return (count, () => setCount(count + 1));
}

// This capsule provides the current count, plus one.
int countPlusOneCapsule(CapsuleHandle use) => use(countManager).$1 + 1;

class ExerciceView extends HookWidget {
  const ExerciceView({super.key});
  @override
  Widget build(BuildContext context) {
    final (exerciceState, exerciceDispatch) = use(exerciceReducerCapsule);
    print((exerciceState as ExerciceSuccess).data.length);
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
    // use.inContext(capsule);
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
