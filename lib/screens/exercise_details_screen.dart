import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/bodyPart.dart';
import 'package:me_fit/models/equipment.dart';
import 'package:me_fit/models/exerciseType.dart';

import '../models/exercise.dart';

class ExerciseDetailsScreen extends StatefulWidget {
  final Exercise exercise;
  final List<BodyPart> bodyParts;
  final List<ExerciseType> exerciseTypes;

  const ExerciseDetailsScreen({
    super.key,
    required this.exercise,
    required this.bodyParts,
    required this.exerciseTypes,
  });

  @override
  State<ExerciseDetailsScreen> createState() => ExerciseDetailsScreenState();
}

class ExerciseDetailsScreenState extends State<ExerciseDetailsScreen>{

  String equipmentName = '';
  bool isLoadingEquipment = true;
  @override
  void initState() {
    super.initState();
    fetchEquipments();
  }

  Future<void> fetchEquipments() async{
    try{
      if(widget.exercise.equipmentId.isNotEmpty){
        final result = await FS.get.one<Equipment>(widget.exercise.equipmentId);
        if(!mounted) return;

        setState(() {
          equipmentName = result?.name ?? 'Unknown';
          isLoadingEquipment = false;
        });
      }else{
        setState(() {
          equipmentName = 'None';
          isLoadingEquipment = false;
        });
      }
    }catch(e){
      setState(() {
        equipmentName = 'Unknown';
        isLoadingEquipment = false;
      });
    }
  }
  @override
  Widget build(BuildContext context){
    final bodyPartNames = widget.exercise.bodyParts
        .map((id) => widget.bodyParts.firstWhere((b) => b.id == id,
        orElse: () => BodyPart(id: '', name: '',imageUrl: '')).name)
        .where((name) =>name.isNotEmpty)
        .join(' , ');

    final exerciseTypeName = widget.exerciseTypes
    .firstWhere((t) => t.id == widget.exercise.exerciseTypeId, orElse: () => ExerciseType(id: '', name: '', imageUrl: ''))
    .name;

    return Scaffold(
      appBar: AppBar(title: Text(widget.exercise.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRect(
              child: Image.network(widget.exercise.imageUrl,
                  fit: BoxFit.cover,
                  height: 300,
                  width: 400,
                  loadingBuilder: (context,child,loadingProgress){
                    if(loadingProgress == null) return child;
                    return SizedBox(height: 200,child: const Center(child: CircularProgressIndicator()));
                  },
                  errorBuilder: (context,error,stackTrace)=> SizedBox(
                    height: 200,
                    child: const Center(child: Icon(Icons.broken_image)),
                  )),

            ),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
              border: TableBorder.all(color: Colors.black,width: 0.5),
              defaultVerticalAlignment: TableCellVerticalAlignment.fill ,
              children: [
                createTableRow('Exercise name', widget.exercise.name!),
                createTableRow('Body Parts', bodyPartNames),
                createTableRow('Equipment', equipmentName ),
                createTableRow('Instruction', widget.exercise.instruction!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow createTableRow(String label, String value){
    return TableRow(
        children: [
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.fill,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.grey,
              child: Text(label,style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.bottom,
            child: Container(
              width: 50,
              padding: const EdgeInsets.all(8),
              child: Text(value),
            ),
          ),
        ]
    );
  }
}