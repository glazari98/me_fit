import 'dart:io';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:me_fit/services/authentication_service.dart';
import '../components/drawer_menu.dart';
import '../models/user.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final AuthenticationService authenticationService = AuthenticationService();
  final ImagePicker picker = ImagePicker();

  late TabController tabController;

  User? currentUserModel;
  bool isLoading = true;

  late var usernameController = TextEditingController();
  final ageController = TextEditingController();
  final weightController = TextEditingController();
  final heightController = TextEditingController();

  String? editedTrainingType;
  String? editedTrainingGoal;
  bool editedHasAccessToGym = false;
  int? editedPreferredWorkoutsPerWeek;
  String? editedAerobicType;
  double? editedAerobicDistanceGoal;
  final aerobicDistanceGoalController = TextEditingController();
  final startingAerobicDistanceController = TextEditingController();
  bool preferencesChanged = false;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    loadUser();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  Future<void> loadUser() async {
    final user = authenticationService.getCurrentUser();
    if (user == null) return;

    final userResult = await FS.get.one<User>(user.uid);

    setState(() {
      currentUserModel = userResult;
      usernameController.text = userResult!.username;
      ageController.text = userResult.age.toString();
      weightController.text = userResult.weight.toString();
      heightController.text = userResult.height.toString();

      //assign user data to editable fields(workout preferences)
      editedTrainingType = userResult.trainingType;
      editedTrainingGoal = userResult.trainingGoal;
      editedHasAccessToGym = userResult.hasAccessToGym;
      editedPreferredWorkoutsPerWeek = userResult.preferredWorkoutsPerWeek;
      editedAerobicType = userResult.aerobicType;
      editedAerobicDistanceGoal = userResult.aerobicDistanceGoal;
      if (userResult.aerobicDistanceGoal != null) {
        aerobicDistanceGoalController.text = userResult.aerobicDistanceGoal.toString();
      }

      preferencesChanged = false; //reset
      isLoading = false;
    });
  }

 //check if preferences changed
  void checkPreferencesChanged() {
    if (currentUserModel == null) return;

    //if we edit distance goal but change to another training type, mark it as unchanged. Give it the value in database
    if((editedAerobicDistanceGoal != currentUserModel?.aerobicDistanceGoal || editedAerobicType != currentUserModel!.aerobicType) && editedTrainingType != 'Aerobic'){
      editedAerobicDistanceGoal = currentUserModel?.aerobicDistanceGoal;
      editedAerobicType = currentUserModel?.aerobicType;
    }

    bool startingDistanceChanged = false;
    if(editedTrainingType  == 'Aerobic') {
      //check  if there is current weekly distance value in database
      if (currentUserModel!.currentAerobicDistance == null) {
        //check if field is not empty
        startingDistanceChanged = startingAerobicDistanceController.text.trim().isNotEmpty;
      }
      if(editedHasAccessToGym != currentUserModel!.hasAccessToGym){
        editedHasAccessToGym = currentUserModel!.hasAccessToGym;
      }

    }
    final changed = editedTrainingType != currentUserModel!.trainingType ||
    editedTrainingGoal != currentUserModel!.trainingGoal || editedHasAccessToGym != currentUserModel!.hasAccessToGym ||
    editedPreferredWorkoutsPerWeek != currentUserModel!.preferredWorkoutsPerWeek || editedAerobicType != currentUserModel!.aerobicType
    || editedAerobicDistanceGoal != currentUserModel!.aerobicDistanceGoal ||startingDistanceChanged;
    setState(() {
      preferencesChanged = changed;
    });
  }

  Future<void> savePreferences() async {
    if (currentUserModel == null) return;

    if (editedTrainingType == 'Aerobic') {
      final goalDistance = double.tryParse(aerobicDistanceGoalController.text.trim());
      final startingDistance = double.tryParse(startingAerobicDistanceController.text.trim());
      if(currentUserModel!.currentAerobicDistance == null) {
        if (startingDistance == null || startingDistance <= 0 || startingDistance > 100) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Starting weekly distance must be between 0.1 and 100 km'),
              duration: Duration(seconds: 2)));
          return;
        }
      }

      if (goalDistance == null || goalDistance < 1 || goalDistance > 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Long-term distance goal must be between 1 and 200 km'),
            duration: Duration(seconds: 2)));
        return;
      }

      if (startingDistance != null) {
        if (goalDistance < startingDistance) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Long-term goal must be greater than or equal to your current distance'),
              duration: Duration(seconds: 2)));
          return;
        }
      }
    }
      //confirmation message
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) =>
            AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 8), Text('Save Preferences')],
              ),
              content: Text(
                  'If you save your changes, your workouts will be generated with your new preferences starting from next week.',
                  style: TextStyle(fontSize: 16)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel')),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Save')),
              ],
            ),
      );
      if (confirm != true) return;
      //update user with new preferences
      final updatedUser = User(
        id: currentUserModel!.id,
        emailAddress: currentUserModel!.emailAddress,
        username: currentUserModel!.username,
        age: currentUserModel!.age,
        weight: currentUserModel!.weight,
        height: currentUserModel!.height,
        trainingType: editedTrainingType ?? currentUserModel!.trainingType,
        trainingGoal: editedTrainingType == 'Aerobic' ? null : (editedTrainingGoal ?? currentUserModel!.trainingGoal),
        hasAccessToGym: editedHasAccessToGym,
        preferredWorkoutsPerWeek: editedPreferredWorkoutsPerWeek ?? currentUserModel!.preferredWorkoutsPerWeek,
        aerobicType: editedAerobicType,
        currentAerobicDistance: currentUserModel!.currentAerobicDistance ?? double.tryParse(startingAerobicDistanceController.text.trim()),
        aerobicDistanceGoal: editedAerobicDistanceGoal,
        profileImageUrl: currentUserModel!.profileImageUrl,
        currentStreak: currentUserModel!.currentStreak,
        bestStreak: currentUserModel!.bestStreak,
        totalCompletedWorkouts: currentUserModel!.totalCompletedWorkouts,
        unlockedBadges: currentUserModel!.unlockedBadges,
        newScheduleMessageShown:  currentUserModel!.newScheduleMessageShown
      );

      await FS.update.one<User>(updatedUser);

      setState(() {
        currentUserModel = updatedUser;
        preferencesChanged = false; //reset save button after changes are made
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Preferences saved successfully!'))
      );
    }
    //if a field is edited in personal details tab this is called automatically
    Future<void> updateUser() async {
      if (currentUserModel == null) return;
      final result = await FS.list.filter<User>(User)
          .whereNotEqualTo('id', currentUserModel!.id)
          .whereEqualTo('username', usernameController.text.trim())
          .fetch();
      if(result.items.isNotEmpty){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('The username is already taken by another user'),duration: Duration(seconds: 2)));
        return;
      }
      final updatedUser = User(
        id: currentUserModel!.id,
        emailAddress: currentUserModel!.emailAddress,
        username: usernameController.text.trim(),
        age: int.parse(ageController.text.trim()),
        weight: double.parse(weightController.text.trim()),
        height: int.parse(heightController.text.trim()),
        trainingType: currentUserModel!.trainingType,
        trainingGoal: currentUserModel!.trainingGoal,
        hasAccessToGym: currentUserModel!.hasAccessToGym,
        preferredWorkoutsPerWeek: currentUserModel!.preferredWorkoutsPerWeek,
        aerobicType: currentUserModel!.aerobicType,
        aerobicDistanceGoal: currentUserModel!.aerobicDistanceGoal,
        profileImageUrl: currentUserModel!.profileImageUrl,
        currentStreak: currentUserModel!.currentStreak,
        bestStreak: currentUserModel!.bestStreak,
        totalCompletedWorkouts: currentUserModel!.totalCompletedWorkouts,
        unlockedBadges: currentUserModel!.unlockedBadges,
        newScheduleMessageShown: currentUserModel!.newScheduleMessageShown
      );

      await FS.update.one<User>(updatedUser);

      setState(() {
        currentUserModel = updatedUser;
      });
  }
    //load an image from your phone's gallery
    Future<void> pickImage() async {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        currentUserModel!.profileImageUrl = image.path;
      });
      await FS.update.one<User>(currentUserModel!);
    }

    Widget buildTextField({required String label, required TextEditingController controller, TextInputType? type}){
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: TextField(
            controller: controller,
            keyboardType: type,decoration: InputDecoration(
                labelText: label,border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12))
            ), onChanged: (_) => updateUser()
        ));
    }

    @override
    Widget build(BuildContext context) {
      if (isLoading) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          centerTitle: true,
          bottom: TabBar(
            controller: tabController,
            labelColor: Colors.yellow,
            indicatorColor: Colors.transparent,
            unselectedLabelColor: Colors.white,
            tabs: const [
              Tab(text: 'Personal Details', icon: Icon(Icons.person)),
              Tab(text: 'Workout Preferences',
                  icon: Icon(Icons.fitness_center)),
            ])),
        drawer: AppDrawer(scaffoldContext: context, currentRoute: '/profile'),
        body: TabBarView(
          controller: tabController,
          children: [
            buildPersonalDetailsTab(),//personal details tab
            buildWorkoutPreferencesTab(),//workout preferences tab
          ]),
      );
    }


    Widget buildPersonalDetailsTab() {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,backgroundImage: currentUserModel!.profileImageUrl != null ?
                    FileImage(File(currentUserModel!.profileImageUrl!)) : null,
                    child: currentUserModel!.profileImageUrl == null
                        ? const Icon(Icons.person, size: 40): null),
                  Positioned(
                    bottom: 0,right: 4,
                    child: GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2)),
                        child: Icon(
                            Icons.edit, color: Colors.white, size: 18)),
                    ))],
              ),
            ),
            SizedBox(height: 30),
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15,
                    offset: Offset(0, 5))],
              ),
              child: Column(
                children: [
                  TextField(enabled: false,
                    decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))
                    ), controller: TextEditingController(
                        text: currentUserModel!.emailAddress),
                  ),
                  SizedBox(height: 16),
                  buildTextField( label: 'Username', controller: usernameController),
                  SizedBox(height: 16),
                  buildTextField(label: 'Age',controller: ageController,type: TextInputType.number),
                  SizedBox(height: 16),
                  buildTextField(label: 'Weight (kg)',controller: weightController,type: TextInputType.number),
                  SizedBox(height: 16),
                  buildTextField(label: 'Height (cm)',controller: heightController,type: TextInputType.number),
                ])),
          ]),
      );
    }

    Widget buildWorkoutPreferencesTab() {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildSectionTitle('Training Type'),
            SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [ Expanded(
                    child: buildEditablePreferenceChip(
                      label: 'Strength',
                      isSelected: editedTrainingType == 'Strength',
                      color: Colors.blue,
                      icon: Icons.fitness_center,
                      onTap: () {
                        setState(() {
                          editedTrainingType = 'Strength';
                          editedTrainingGoal = 'Muscle Building'; //set default goal when moving to strength choice
                          checkPreferencesChanged();
                        });
                      }),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: buildEditablePreferenceChip(
                      label: 'Cardio',
                      isSelected: editedTrainingType == 'Cardio',
                      color: Colors.green,
                      icon: Icons.directions_run,
                      onTap: () {
                        setState(() {
                          editedTrainingType = 'Cardio';
                          editedTrainingGoal = 'Fat Loss'; //set default goal when moving to cardio choice
                          checkPreferencesChanged();
                        });
                      })),
                  SizedBox(width: 4),
                  Expanded(
                    child: buildEditablePreferenceChip(
                      label: 'Aerobic',
                      isSelected: editedTrainingType == 'Aerobic',
                      color: Colors.purple,
                      icon: Icons.directions_bike,
                      onTap: () {
                        setState(() {
                          editedTrainingType = 'Aerobic';
                          editedTrainingGoal = null; //aerobic has no goal (it has weekly distance goal!)
                          editedAerobicType = editedAerobicType ?? 'Running';
                          checkPreferencesChanged();
                        });
                      },
                    ))],
              ),
            ),
             SizedBox(height: 24),
            if (editedTrainingType == 'Strength' ||
                editedTrainingType == 'Cardio') ...[
              buildSectionTitle('Training Goal'),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: editedTrainingType == 'Strength'
                      ? [Expanded(
                      child: buildEditablePreferenceChip(
                        label: 'Muscle Building',
                        isSelected: editedTrainingGoal == 'Muscle Building',
                        color: Colors.blue,
                        icon: Icons.fitness_center,
                        onTap: () {
                          setState(() {
                            editedTrainingGoal = 'Muscle Building';
                            checkPreferencesChanged();
                          });
                        })),
                    SizedBox(width: 4),
                    Expanded(
                      child: buildEditablePreferenceChip(
                        label: 'Power Building',
                        isSelected: editedTrainingGoal == 'Power Building',
                        color: Colors.blue.shade700,
                        icon: Icons.bolt,
                        onTap: () {
                          setState(() {
                            editedTrainingGoal = 'Power Building';
                            checkPreferencesChanged();
                          });
                        },
                      ),
                    ),
                  ]: [
                    Expanded(
                      child: buildEditablePreferenceChip(
                        label: 'Fat Loss',
                        isSelected: editedTrainingGoal == 'Fat Loss',
                        color: Colors.orange,
                        icon: Icons.whatshot,
                        onTap: () {
                          setState(() {
                            editedTrainingGoal = 'Fat Loss';
                            checkPreferencesChanged();
                          });
                        })),
                    SizedBox(width: 4),
                    Expanded(
                      child: buildEditablePreferenceChip(
                        label: 'Endurance',
                        isSelected: editedTrainingGoal == 'Endurance',
                        color: Colors.orange.shade700,
                        icon: Icons.timer,
                        onTap: () {
                          setState(() {
                            editedTrainingGoal = 'Endurance';
                            checkPreferencesChanged();
                          });
                        })),
                  ],
                ),
              ),
              SizedBox(height: 24),
            ],

            if (editedTrainingType != 'Aerobic') ...[
              buildSectionTitle('Gym Access'),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: editedHasAccessToGym
                            ? Colors.green.withOpacity(0.1):Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12)),
                      child: Icon(
                        editedHasAccessToGym
                            ? Icons.fitness_center : Icons.home,
                        color: editedHasAccessToGym ? Colors.green: Colors.grey,
                      )),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            editedHasAccessToGym ? 'Gym Access': 'Home Workout',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            editedHasAccessToGym ? 'Using gym equipment' : 'Bodyweight only',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          )],
                      )),
                    Switch(
                      value: editedHasAccessToGym,
                      onChanged: (value) {
                        setState(() {
                          editedHasAccessToGym = value;
                          checkPreferencesChanged();
                        });
                      },
                      activeColor: Colors.green,
                    )]),
              ),
              SizedBox(height: 24),
            ],

            buildSectionTitle('Workouts per Week'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                    child: Icon(
                      Icons.calendar_today,
                      color: Theme.of(context).primaryColor),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Weekly Frequency',style: TextStyle(fontWeight: FontWeight.w600,fontSize: 16)),
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: editedPreferredWorkoutsPerWeek ?? 3,
                              items: [
                                DropdownMenuItem(
                                    value: 1, child: Text('1 day per week')),
                                DropdownMenuItem(
                                    value: 2, child: Text('2 days per week')),
                                DropdownMenuItem(
                                    value: 3, child: Text('3 days per week')),
                                DropdownMenuItem(
                                    value: 4, child: Text('4 days per week')),
                                DropdownMenuItem(
                                    value: 5, child: Text('5 days per week')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  editedPreferredWorkoutsPerWeek = value;
                                  checkPreferencesChanged();
                                });
                              }),
                          )),
                      ])),
                ],
              ),
            ),

            if (editedTrainingType == 'Aerobic') ...[
              SizedBox(height: 24),
              buildSectionTitle('Aerobic Details'),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12)),
                          child: Icon(
                            editedAerobicType == 'Running'
                                ? Icons.directions_run: editedAerobicType == 'Cycling'
                                ? Icons.directions_bike: Icons.pool,color: Colors.purple),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Activity Type',style: TextStyle(fontWeight: FontWeight.w600,fontSize: 16)),
                              SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20)),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: editedAerobicType ?? 'Running',
                                    items:  [
                                      DropdownMenuItem(value: 'Running',
                                          child: Text('🏃 Running')),
                                      DropdownMenuItem(value: 'Cycling',
                                          child: Text('🚴 Cycling')),
                                      DropdownMenuItem(value: 'Swimming',
                                          child: Text('🏊 Swimming')),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        editedAerobicType = value;
                                        checkPreferencesChanged();
                                      });
                                    },
                                  )),
                              )]),
                        )],
                    ),
                    Divider(height: 24),
                    Row(
                        children: [
                          Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.flag, color: Colors.blue)),
                          SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Starting Weekly Distance (km)',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                  SizedBox(height: 4),
                                  if (currentUserModel!.currentAerobicDistance != null)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        '${currentUserModel!.currentAerobicDistance!.toStringAsFixed(1)} km',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    )
                                  else
                                    TextField(
                                      controller: startingAerobicDistanceController,
                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          checkPreferencesChanged();
                                        });
                                      },
                                    ),
                                ],
                              )),
                        ]),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child:  Icon(Icons.route,color: Colors.purple)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Long-term Weekly Distance Goal (km)',
                                style: TextStyle(fontWeight: FontWeight.w600,fontSize: 16)),
                              SizedBox(height: 4),
                              TextField(
                                controller: aerobicDistanceGoalController,
                                keyboardType: TextInputType.numberWithOptions(
                                    decimal: true),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8)),
                                onChanged: (value) {
                                  setState(() {
                                    editedAerobicDistanceGoal = double.tryParse(value);
                                    checkPreferencesChanged();
                                  });
                                },
                              ),
                            ],
                          )),
                      ])],
                ),
              )],
            SizedBox(height: 10),
          if (preferencesChanged) ...[
            SizedBox(height:10),
            SizedBox(
              width: double.infinity,child: ElevatedButton(
                onPressed: savePreferences,
                  style: ElevatedButton.styleFrom( backgroundColor: Colors.green,foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child:  Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Icon(Icons.save),
                  SizedBox(width: 8),
                  Text('Save Preferences', style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold),
                  )],
                )),
            )],
            ]),
      );
    }

    //styling for active tab
    Widget buildEditablePreferenceChip({required String label,required bool isSelected,required Color color,required IconData icon,required VoidCallback onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,color: isSelected ? Colors.white : color,size: 20),
              SizedBox(height: 4),
              Text(
                label,style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ])),
      );
    }
    //titles for workout preferences tab sections
    Widget buildSectionTitle(String title) {
      return Padding(
        padding: EdgeInsets.only(left: 4),
        child: Row(
          children: [
            Container( width: 4,height: 20,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(4)),
            ),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,fontWeight: FontWeight.w600,letterSpacing: 0.5),
            )])
      );
    }

    Widget buildPreferenceChip({required String label,required bool isSelected,required Color color,required IconData icon}) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,color: isSelected ? Colors.white : color,
              size: 20),
            SizedBox(height: 4),
            Text(
              label,style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 11),
              textAlign: TextAlign.center,
            )]),
      );
    }

}

