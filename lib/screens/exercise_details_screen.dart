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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(widget.exercise.imageUrl,
                  fit: BoxFit.cover,
                  height: 260,
                  width: double.infinity,
                  loadingBuilder: (context,child,loadingProgress){
                    if(loadingProgress == null) return child;
                    return SizedBox(height: 260,child: const Center(child: CircularProgressIndicator()));
                  },
                  errorBuilder: (context,error,stackTrace)=> SizedBox(
                    height: 260,
                    child: const Center(child: Icon(Icons.broken_image,size: 40)),
                  )),

            ),
            const SizedBox(height: 20),
            Text(widget.exercise.name,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(elevation: 2,shape: RoundedRectangleBorder(
              borderRadius: BorderRadiusGeometry.circular(12),
            ),
              child: Padding(padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildInfoRow(Icons.fitness_center,'Body Parts',bodyPartNames),
                  const SizedBox(height: 12),
                  buildInfoRow(Icons.handyman, 'Equipment', isLoadingEquipment ? 'Loading...' : equipmentName),
                  const SizedBox(height: 12),
                  buildInfoRow(Icons.category,'Exercise Type',exerciseTypeName),
                ],),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Instructions',style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold)),
            Container(width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey,borderRadius: BorderRadius.circular(12)
            ),child: Text(widget.exercise.instruction,
              style: TextStyle(fontSize: 15,fontWeight: FontWeight.bold),),)
          ],
        ),
      ),
    );
  }

  Widget buildInfoRow(IconData icon, String label, String value){
    return Row(crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon,size: 20,color: Colors.blue),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,style: TextStyle(fontSize: 13,color: Colors.grey),),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 15,fontWeight: FontWeight.w500),)
      ],))
    ],);
  }
}