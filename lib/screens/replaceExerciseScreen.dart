import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/exercise.dart';

import '../models/bodyPart.dart';
import '../models/exerciseType.dart';
import 'exercise_details_screen.dart';

class ReplaceExerciseScreen extends StatefulWidget{
  const ReplaceExerciseScreen({super.key});

  @override
  State<ReplaceExerciseScreen> createState() => ReplaceExerciseScreenState();
}

class ReplaceExerciseScreenState extends State<ReplaceExerciseScreen> {
  List<String> selectedBodyPartIds = [];
  String? selectedExerciseTypeId;

  List<BodyPart> bodyParts = [];
  List<ExerciseType> exerciseTypes = [];


  List<Exercise> allExercises = [];
  List<Exercise> filteredExercises = [];
  List<Exercise> visibleExercises = [];

  int currentVisibleCount = 0;
  static const int pageSize = 10;

  bool isLoadingExercises = false;
  bool isLoadingFilters = true;

  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();
  late Map<String,String> bodyPartNameById;
  late Map<String,String> exerciseTypeNameById;

  bool sortAscending = true;

  @override
  void initState() {
    super.initState();
    fetchFitlers().then((_) => loadAllExercises());
  }
  @override
  void dispose(){
    searchController.dispose();
    super.dispose();

  }

  Future<void> fetchFitlers() async {
    final bodyPartsResult = await FS.list.allOfClass<BodyPart>(BodyPart);

    final exerciseTypesResult = await FS.list.allOfClass<ExerciseType>(
        ExerciseType);

    if (!mounted) return;
    setState(() {
      bodyParts = bodyPartsResult;
      exerciseTypes = exerciseTypesResult;
      bodyPartNameById = {
        for(final b in bodyParts) b.id : b.name
      };
      exerciseTypeNameById = {
        for (final t in exerciseTypes) t.id : t.name
      };
      filteredExercises.clear();
      visibleExercises.clear();
      isLoadingFilters = false;
    });
  }
  Future<void> loadAllExercises() async{
    setState(() => isLoadingExercises = true);

    final result = await FS.list.allOfClass<Exercise>(Exercise);

    setState(() {
      allExercises = result;
      applyFiltersAndSearch();
      isLoadingExercises = false;
    });
  }
  void applyFiltersAndSearch() {
    List<Exercise> temp = allExercises;

    if(selectedExerciseTypeId != null){
      temp = temp.where((e) =>
      e.exerciseTypeId == selectedExerciseTypeId).toList();

    }
    if(selectedBodyPartIds.isNotEmpty){
      temp = temp.where((e) =>
          e.bodyParts.any((bp) => selectedBodyPartIds.contains(bp))
      ).toList();
    }
    if(searchQuery.isNotEmpty){
      final q = searchQuery.toLowerCase();
      temp = temp.where((e){
        final nameMatch = e.name.toLowerCase().contains(q);
        final keywordMatch = e.keywords.any(
              (k) => k.toLowerCase().contains(q),
        );
        return nameMatch || keywordMatch;
      }).toList();
    }
    temp.sort((a,b){
      final nameA = a.name.toLowerCase();
      final nameB = b.name.toLowerCase();
      return sortAscending ? nameA.compareTo(nameB)
          : nameB.compareTo(nameA);
    });
    filteredExercises = temp.toList();
    currentVisibleCount = filteredExercises.length > pageSize
        ? pageSize
        : filteredExercises.length;

    visibleExercises = filteredExercises.take(currentVisibleCount).toList();
  }
  Future<void> loadMore() async {
    final remaining = filteredExercises.length - currentVisibleCount;
    if(remaining <= 0) return;

    final toShow = remaining >= pageSize ? pageSize : remaining;
    setState(() {
      visibleExercises.addAll(
          filteredExercises.sublist(
              currentVisibleCount,
              currentVisibleCount + toShow)
      );
      currentVisibleCount += toShow;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Select Exercise'),
          actions: [
            IconButton(
              tooltip: sortAscending ? 'Sorted A->Z': 'Sorted Z->A',
              icon: Icon(
                sortAscending ? Icons.sort_by_alpha : Icons.sort,
                color: sortAscending ? Colors.blue : Colors.yellow,
              ),
              onPressed: (){
                setState(() {
                  sortAscending = !sortAscending;
                  applyFiltersAndSearch();
                });
              },
            ),
          ],
        ),
        body: Column(
          children: [
            searchField(),
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
                    final bodyPartNames = exercise.bodyParts
                        .map((id) => bodyPartNameById[id])
                        .whereType<String>()
                        .join(' , ');
                    final exerciseTypeName = exerciseTypeNameById[exercise.exerciseTypeId];
                    return ListTile(
                        title: Text(exercise.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if(exerciseTypeName != null) Text(
                              'Type: ${exerciseTypeName}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            if(bodyPartNames.isNotEmpty)
                              Text(
                                'Body parts: ${bodyPartNames}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              )
                          ],
                        ),
                        trailing: SizedBox(width: 96,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
                                      onPressed: (){
                                        Navigator.pop(context,exercise);
                                      },
                                      child: const Icon(Icons.add,size: 20)),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 40,height: 40,
                                  child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
                                      onPressed: (){
                                        Navigator.push(context,
                                            MaterialPageRoute(
                                                builder: (_) => ExerciseDetailsScreen(
                                                    exercise: exercise,
                                                    bodyParts: bodyParts,
                                                    exerciseTypes: exerciseTypes)));
                                      },
                                      child: const Icon(Icons.visibility)),
                                )
                              ],
                            ))
                    );
                  } else if (currentVisibleCount < filteredExercises.length){
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
  Widget searchField(){
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8,vertical: 4),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: 'Search exercises',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
              onPressed: (){
                searchController.clear();
                setState(() {
                  searchQuery = '';
                  applyFiltersAndSearch();
                });
              }, icon: const Icon(Icons.clear))
              : null,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value){
          setState(() {
            searchQuery = value.trim().toLowerCase();
            applyFiltersAndSearch();
          });
        },
      ),
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
                    applyFiltersAndSearch();
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
              isDense: true,
              hint: const Text('Exercise Type'),
              value: selectedExerciseTypeId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12,vertical: 12),
              ),
              icon: selectedExerciseTypeId != null
                  ? GestureDetector(
                onTap: (){
                  setState(() {
                    selectedExerciseTypeId = null;
                    applyFiltersAndSearch();
                  });
                },
                child: const Icon(Icons.clear),
              )
                  : const Icon(Icons.arrow_drop_down),

              items: exerciseTypes.map(
                    (t) => DropdownMenuItem<String>(
                  child: Text(t.name),
                  value: t.id,
                ),
              ).toList(),
              onChanged: (v) {
                setState(() {
                  selectedExerciseTypeId = v;
                  applyFiltersAndSearch();
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}