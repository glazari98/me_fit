import 'package:firestorm/fs/fs.dart';
import 'package:firestorm/fs/queries/fs_paginator.dart';
import 'package:firestorm/fs/queries/fs_query_result.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/exercise.dart';

import '../models/bodyPart.dart';
import '../models/exerciseType.dart';

class SelectExerciseScreen extends StatefulWidget{
  const SelectExerciseScreen({super.key});

  @override
  State<SelectExerciseScreen> createState() => SelectExerciseScreenState();
}

class SelectExerciseScreenState extends State<SelectExerciseScreen> {
  List<String> selectedBodyPartIds = [];
  String? selectedExerciseTypeId;

  List<BodyPart> bodyParts = [];
  List<ExerciseType> exerciseTypes = [];



  List<Exercise> allFilteredExercises = [];
  List<Exercise> visibleExercises = [];

  int currentVisibleCount = 0;
  static const int pageSize = 10;

  bool isLoadingExercises = false;
  bool isLoadingFilters = true;

  @override
  void initState() {
    super.initState();
    fetchFitlers();
  }


  Future<void> fetchFitlers() async {
    final bodyPartsResult = await FS.list.allOfClass<BodyPart>(BodyPart);

    final exerciseTypesResult = await FS.list.allOfClass<ExerciseType>(
        ExerciseType);

    if (!mounted) return;
    setState(() {
      bodyParts = bodyPartsResult;
      exerciseTypes = exerciseTypesResult;
      allFilteredExercises.clear();
      visibleExercises.clear();
      isLoadingFilters = false;
    });
  }
  Future<void> fetchExercises() async{
    if(selectedBodyPartIds!.isEmpty && selectedExerciseTypeId == null) {
      setState(() {
        allFilteredExercises.clear();
        visibleExercises.clear();
        currentVisibleCount = 0;
      });
      return;
    }
    setState(() {
      isLoadingExercises = true;
    });

    var query = FS.list.filter<Exercise>(Exercise);

    if(selectedExerciseTypeId != null){
      query = query.whereEqualTo('exerciseTypeId', selectedExerciseTypeId);
    }
    if(selectedBodyPartIds.isNotEmpty){
      query = query.whereArrayContainsAny('bodyParts', selectedBodyPartIds);
    }

    FSQueryResult<Exercise> result = await query.fetch();
    setState(() {
      allFilteredExercises = result.items;

      currentVisibleCount = allFilteredExercises.length >= pageSize
      ? pageSize
      : allFilteredExercises.length;
      visibleExercises = allFilteredExercises.sublist(0, currentVisibleCount);
      isLoadingExercises = false;
    });
  }

  Future<void> loadMore() async {
    final remaining = allFilteredExercises.length - currentVisibleCount;
    if(remaining <= 0) return;

    final toShow = remaining >= pageSize ? pageSize : remaining;
    setState(() {
      visibleExercises.addAll(
        allFilteredExercises.sublist(currentVisibleCount,currentVisibleCount + toShow)
      );
      currentVisibleCount += toShow;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Select Exercise')),
        body: Column(
          children: [
            filters(),
            if(isLoadingExercises)
              const Padding(
                  padding: EdgeInsets.all(16),
              child: CircularProgressIndicator()),
            Expanded(
              child: visibleExercises.isEmpty
              ? Center (
                child: isLoadingExercises
                ? const CircularProgressIndicator()
                : const Text('No exercises to show'),
              )
              :
              ListView.builder(
                itemCount: visibleExercises.length + 1,
                itemBuilder: (context, index) {
                  if (index < visibleExercises.length) {
                    final exercise = visibleExercises[index];
                    return ListTile(
                      title: Text(exercise.name),
                      trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, exercise);
                          },
                          child: const Text('Add')),
                    );
                  } else if (currentVisibleCount < allFilteredExercises.length){
                    return Padding(
                        padding: const EdgeInsets.all(16),
                        child: ElevatedButton(
                            onPressed: loadMore, child: const Text('Load More'),
                        ),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }


                },
              ),
            ),
          ],
        )
    );
  }

  Widget filters() {
    if (isLoadingFilters) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                // Show a multi-select dialog
                final selected = await showDialog<List<String>>(
                  context: context,
                  builder: (_) {
                    List<String> tempSelected = List.from(selectedBodyPartIds);

                    return StatefulBuilder(
                      builder: (context, setDialogState) {
                        return AlertDialog(
                          title: const Text('Select Body Parts'),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: ListView(
                              shrinkWrap: true,
                              children: bodyParts.map((b) {
                                final checked = tempSelected.contains(b.id);
                                return CheckboxListTile(
                                  title: Text(b.name),
                                  value: checked,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        tempSelected.add(b.id);
                                      } else {
                                        tempSelected.remove(b.id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, null),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, tempSelected),
                              child: const Text('Apply'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );

                if (selected != null) {
                  setState(() {
                    selectedBodyPartIds = selected;
                    fetchExercises();
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  selectedBodyPartIds!.isEmpty
                      ? 'Select Body Parts'
                      : selectedBodyPartIds
                      .map((id) =>
                  bodyParts.firstWhere((b) => b.id == id).name)
                      .join(', '),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              hint: const Text('Exercise Type'),
              value: selectedExerciseTypeId,
              items: exerciseTypes
                  .map(
                    (t) => DropdownMenuItem(
                  child: Text(t.name),
                  value: t.id,
                ),
              )
                  .toList(),
              onChanged: (v) {
                setState(() {
                  selectedExerciseTypeId = v;
                  fetchExercises();
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}