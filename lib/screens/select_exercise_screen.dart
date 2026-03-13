import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/exercise.dart';

import '../models/bodyPart.dart';
import '../models/exerciseType.dart';
import 'exercise_details_screen.dart';
//widget where user selects an exercise to add to a workout
class SelectExerciseScreen extends StatefulWidget {
  const SelectExerciseScreen({super.key});

  @override
  State<SelectExerciseScreen> createState() => SelectExerciseScreenState();
}

class SelectExerciseScreenState extends State<SelectExerciseScreen> {
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
  late Map<String, String> bodyPartNameById;
  late Map<String, String> exerciseTypeNameById;

  bool sortAscending = true;

  @override
  void initState() {
    super.initState();
    fetchFilters().then((_) => loadAllExercises());
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
//retrieve body parts, exercise types
  Future<void> fetchFilters() async {
    final bodyPartsResult = await FS.list.allOfClass<BodyPart>(BodyPart);

    final exerciseTypesResult = await FS.list.allOfClass<ExerciseType>(
      ExerciseType,
    );

    if (!mounted) return;
    setState(() {
      bodyParts = bodyPartsResult;
      exerciseTypes = exerciseTypesResult;
      bodyPartNameById = {for (final b in bodyParts) b.id: b.name};
      exerciseTypeNameById = {for (final t in exerciseTypes) t.id: t.name};
      filteredExercises.clear();
      visibleExercises.clear();
      isLoadingFilters = false;
    });
  }
//get all exercises from database
  Future<void> loadAllExercises() async {
    setState(() => isLoadingExercises = true);

    final result = await FS.list.allOfClass<Exercise>(Exercise);

    setState(() {
      allExercises = result;
      applyFiltersAndSearch();
      isLoadingExercises = false;
    });
  }
//function for searching according name of exercises and keywords
  void applyFiltersAndSearch() {
    List<Exercise> temp = allExercises;

    if (selectedExerciseTypeId != null) {
      temp = temp
          .where((e) => e.exerciseTypeId == selectedExerciseTypeId)
          .toList();
    }
    if (selectedBodyPartIds.isNotEmpty) {
      temp = temp
          .where(
            (e) => e.bodyParts.any((bp) => selectedBodyPartIds.contains(bp)),
          )
          .toList();
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      temp = temp.where((e) {
        final nameMatch = e.name.toLowerCase().contains(q);
        final keywordMatch = e.keywords.any((k) => k.toLowerCase().contains(q));
        return nameMatch || keywordMatch;
      }).toList();
    }
    temp.sort((a, b) {
      final nameA = a.name.toLowerCase();
      final nameB = b.name.toLowerCase();
      return sortAscending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
    });
    filteredExercises = temp.toList();
    currentVisibleCount = filteredExercises.length > pageSize
        ? pageSize
        : filteredExercises.length;

    visibleExercises = filteredExercises.take(currentVisibleCount).toList();
  }
//function for loading more results
  Future<void> loadMore() async {
    final remaining = filteredExercises.length - currentVisibleCount;
    if (remaining <= 0) return;

    final toShow = remaining >= pageSize ? pageSize : remaining;
    setState(() {
      visibleExercises.addAll(
        filteredExercises.sublist(
          currentVisibleCount,
          currentVisibleCount + toShow,
        ),
      );
      currentVisibleCount += toShow;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Exercise'),
        actions: [
          IconButton(
            tooltip: sortAscending ? 'Sorted A->Z' : 'Sorted Z->A',
            icon: Icon(
              sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(sortAscending ? 'Sorted Z->A': 'Sorted A->Z'),duration: Duration(seconds: 2),),
              );
              setState(() {
                sortAscending = !sortAscending;
                applyFiltersAndSearch();
              });
            }),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,borderRadius: BorderRadius.circular(16)),
              child: searchField(),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: filters(),
            ),
            SizedBox(height: 8),
            Padding( padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row( children: [
                  Container( padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon( Icons.fitness_center,
                      color: Theme.of(context).primaryColor,size: 16)),
                SizedBox(width: 12),
                  Text('EXERCISES',
                    style: TextStyle(
                      fontSize: 14,fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,color: Colors.grey[700],
                    )),
                  SizedBox(width: 8), Container(width: 4,height: 4,
                    decoration: BoxDecoration(color: Colors.grey[400],
                      shape: BoxShape.circle),
                  ),
                  SizedBox(width: 8), Text('${visibleExercises.length} of ${filteredExercises.length}',
                    style: TextStyle(fontSize: 14,color: Colors.grey[600], fontWeight: FontWeight.w500)),
                ]),
            ),
            SizedBox(height: 8),
            if (isLoadingExercises)
              const Padding(padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator())),
            Expanded(
              child: visibleExercises.isEmpty
                  ? buildEmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: visibleExercises.length + 1,
                itemBuilder: (context, index) {
                  if (index < visibleExercises.length) {
                    final exercise = visibleExercises[index];
                    final bodyPartNames = exercise.bodyParts
                        .map((id) => bodyPartNameById[id])
                        .whereType<String>()
                        .join(' • ');
                    final exerciseTypeName =
                    exerciseTypeNameById[exercise.exerciseTypeId];

                    return buildExerciseCard(
                      exercise: exercise,
                      exerciseTypeName: exerciseTypeName,
                      bodyPartNames: bodyPartNames,
                      index: index,
                    );
                  } else if (currentVisibleCount <
                      filteredExercises.length) {
                    return buildLoadMoreButton();
                  } else {
                    return const SizedBox.shrink();
                  }
                }),
            )],
        )),
    );
  }
//widget for showing when there are not exercises to show
  Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[200],shape: BoxShape.circle),
          child: Icon(Icons.fitness_center_outlined,size: 64,color: Colors.grey[600])),
          const SizedBox(height: 24),
          Text('No exercises found',
            style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold,color: Colors.grey[800])),
          SizedBox(height: 8),
          Text('Try adjusting your filters or search',
            style: TextStyle(
              fontSize: 14,color: Colors.grey[600],
            )),
        ]),
    );
  }
//widget where exercises details and add button are included
  Widget buildExerciseCard({required Exercise exercise,String? exerciseTypeName,required String bodyPartNames, required int index}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,offset: Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context, MaterialPageRoute(
                builder: (_) => ExerciseDetailsScreen(
                  exercise: exercise,
                  bodyParts: bodyParts,exerciseTypes: exerciseTypes,
                )),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(children: [
                Container( width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: getTypeColor(exerciseTypeName!),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                        blurRadius: 8,offset: Offset(0, 4),
                      )],
                  ),
                  child: Center(
                    child: Icon(
                      getExerciseIcon(exerciseTypeName), color: Colors.white,size: 24),
                  )),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(exercise.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      if (exerciseTypeName != null)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: getTypeColor(exerciseTypeName).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12)),
                          child: Row(mainAxisSize: MainAxisSize.min,
                            children: [SizedBox(width: 4),
                              Text(exerciseTypeName,
                                style: TextStyle(fontSize: 11,
                                  fontWeight: FontWeight.w600,color: getTypeColor(exerciseTypeName),
                                ))],
                          ),
                        ),
                      SizedBox(height: 8),
                      if (bodyPartNames.isNotEmpty)
                        Wrap(spacing: 4,runSpacing: 4,
                          children: bodyPartNames.split(' • ').map((part) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,vertical: 2,
                              ),decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),child: Text(
                                part,style: TextStyle(
                                  fontSize: 10,color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                )));
                          }).toList(),
                        )],
                  )),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    onPressed: () {
                      Navigator.pop(context, exercise);
                    },
                    icon:Icon(
                      Icons.add_circle, color: Colors.green,size: 32),
                    tooltip: 'Add exercise',
                    padding: EdgeInsets.all(8),
                  ))],
            )),
        )),
    );
  }
//widget for show load more button
  Widget buildLoadMoreButton() {
    return Container(
      margin:  EdgeInsets.symmetric(vertical: 16),
      child: ElevatedButton(
        onPressed: loadMore,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          minimumSize:  Size(200, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),elevation: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.expand_more),
            SizedBox(width: 8),
            Text('Load More',
              style: TextStyle( fontSize: 16,fontWeight: FontWeight.bold,letterSpacing: 1),
            ),
          ])),
    );
  }
//get icon according to exercise type
  IconData getExerciseIcon(String? typeName) {
    switch (typeName) {
      case 'STRENGTH':
        return Icons.fitness_center;
      case 'CARDIO':
        return Icons.sports_gymnastics;
      case 'PLYOMETRICS':
        return Icons.sports_gymnastics;
      case 'AEROBIC':
        return Icons.directions_run;
      case 'STRETCHING':
        return Icons.self_improvement;
      default:
        return Icons.fitness_center;
    }
  }

//get color for exercise type
  Color getTypeColor(String typeName) {
    switch (typeName) {
      case 'STRENGTH':
        return Colors.blue;
      case 'CARDIO':
        return Colors.green;
      case 'PLYOMETRICS':
        return Colors.orange;
      case 'AEROBIC':
        return Colors.purple;
      case 'STRETCHING':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
//widget for search field
  Widget searchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: 'Search exercises',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    searchController.clear();
                    setState(() {
                      searchQuery = '';
                      applyFiltersAndSearch();
                    });
                  },
                  icon: const Icon(Icons.clear),
                )
              : null,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) {
          setState(() {
            searchQuery = value.trim().toLowerCase();
            applyFiltersAndSearch();
          });
        },
      ),
    );
  }
//widget for showing body part and exercise type filters
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
                              onPressed: () =>
                                  Navigator.pop(context, tempSelected),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  selectedBodyPartIds!.isEmpty
                      ? 'Select Body Parts'
                      : selectedBodyPartIds
                            .map(
                              (id) =>
                                  bodyParts.firstWhere((b) => b.id == id).name,
                            )
                            .join(', '),
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              isDense: false,
              hint: Text('Exercise Type'),
              value: selectedExerciseTypeId,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
              icon: selectedExerciseTypeId != null
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedExerciseTypeId = null;
                          applyFiltersAndSearch();
                        });
                      },
                      child: Icon(Icons.clear),
                    )
                  : Icon(Icons.arrow_drop_down),

              items: [
                DropdownMenuItem<String>(value: null, child: Text('All')),
                ...exerciseTypes.map(
                  (t) => DropdownMenuItem(value: t.id, child: Text(t.name)),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  selectedExerciseTypeId = v;
                  applyFiltersAndSearch();
                });
              },
            ),
          )]),
    );
  }
}
