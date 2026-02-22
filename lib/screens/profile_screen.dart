import 'dart:io';

import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';



import 'package:image_picker/image_picker.dart';import 'package:me_fit/services/authentication_service.dart';

import '../models/user.dart';class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen>{
  final AuthenticationService authenticationService = AuthenticationService();
  final ImagePicker picker = ImagePicker();
  
  User? currentUserModel;
  bool isLoading = true;
  
  late var usernameController = TextEditingController();
  final ageController = TextEditingController();
  final weightController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    loadUser();
  }
  
  Future<void> loadUser() async {
    final user = authenticationService.getCurrentUser();
    if(user == null) return;

    final userResult = await FS.get.one<User>(user.uid);

    setState(() {
      currentUserModel = userResult;
      usernameController.text = userResult!.username;
      ageController.text = userResult.age.toString();
      weightController.text = userResult.weight.toString();
      isLoading = false;
    });
  }

  Future<void> updateUser() async {
    if(currentUserModel == null)return;

    final updatedUser = User(
      id: currentUserModel!.id,
      emailAddress: currentUserModel!.emailAddress,
      username: usernameController.text.trim(),
      age: int.parse(ageController.text.trim()),
      weight: double.parse(weightController.text.trim()),
      trainingType: currentUserModel!.trainingType,
      hasAccessToGym: currentUserModel!.hasAccessToGym,
      preferredWorkoutsPerWeek: currentUserModel!.preferredWorkoutsPerWeek,
      aerobicType: currentUserModel!.aerobicType,
      aerobicDistance: currentUserModel!.aerobicDistance,
      profileImageUrl: currentUserModel!.profileImageUrl,
      currentStreak: currentUserModel!.currentStreak,
      bestStreak: currentUserModel!.bestStreak,
      totalCompletedWorkouts: currentUserModel!.totalCompletedWorkouts,
      unlockedBadges: currentUserModel!.unlockedBadges,
    );

    await FS.update.one<User>(updatedUser);

    setState(() {
      currentUserModel = updatedUser;
    });
  }

  Future<void> pickImage() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if(image == null) return;

    setState(() {
      currentUserModel!.profileImageUrl = image.path;
    });
    await FS.update.one<User>(currentUserModel!);
  }
  Widget buildTextField({required String label, required TextEditingController controller, TextInputType? type}){
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: TextField(controller: controller,
      keyboardType: type,decoration: InputDecoration(
            labelText: label,border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
          ),
      onChanged: (_) => updateUser()),
    );
  }

  @override
  Widget build(BuildContext context){
    if(isLoading){
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(appBar: AppBar(
      title: Text('Profile'),
      centerTitle: true,
    ),
    body: SingleChildScrollView( padding: EdgeInsets.all(20),
    child: Column(
      children: [
        Center(child : Stack ( children : [CircleAvatar(
        radius: 60,backgroundImage: currentUserModel!.profileImageUrl != null ?
        FileImage(File(currentUserModel!.profileImageUrl!)): null,
          child: currentUserModel!.profileImageUrl == null ? Icon(Icons.person,size: 40) : null,
        ),
        Positioned(bottom: 0, right: 4,
          child: GestureDetector(
            onTap: pickImage, child: Container(padding: EdgeInsets.all(8),
            decoration: BoxDecoration(color: Theme.of(context).primaryColor,
            shape: BoxShape.circle, border: Border.all(color: Colors.white,width: 2)),
            child: Icon(Icons.edit,color: Colors.white,size: 18),
          ),
          ),
        ),
       ],
    ),
    ),
    SizedBox(height: 20),
      TextField(enabled: false,decoration: InputDecoration(labelText: 'Email',border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      controller: TextEditingController(text: currentUserModel!.emailAddress)),
      SizedBox(height: 20),
      buildTextField(label: 'Username', controller: usernameController),
      buildTextField(label: 'Age', controller: ageController,type: TextInputType.number),
      buildTextField(label: 'Weight (kg)', controller: weightController,type: TextInputType.number),

      ],
    ),
    )
    );

  }
  
}