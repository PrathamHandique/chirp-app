import 'dart:io';
import 'package:buddiesgram/models/user.dart';
import 'package:buddiesgram/pages/HomePage.dart';
import 'package:buddiesgram/widgets/ProgressWidget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as ImD;
import 'package:flutter/material.dart';


final postsReference = Firestore.instance.collection('posts');
final FirebaseStorage storage = FirebaseStorage.instance;
final StorageReference storageReference = storage.ref().child('posts');

//final postsReference = Firestore.instance.document('posts/documentId');

class UploadPage extends StatefulWidget {
  final User  gCurrentUser;

  UploadPage({this.gCurrentUser});

  @override
  _UploadPageState createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> with AutomaticKeepAliveClientMixin<UploadPage>{
  File file;
  bool uploading = false;
  String postId = Uuid().v4();
  TextEditingController descriptionTextEditingController = TextEditingController();
  TextEditingController locationTextEditingController = TextEditingController();

  captureImageWithCamera() async{
    Navigator.pop(context);
    File imageFile = await ImagePicker.pickImage(
        source: ImageSource.camera,
        maxHeight: 680,
        maxWidth: 970
    );
    setState(() {
      this.file = imageFile;
    });
  }

  pickImageFromGallery() async{
    Navigator.pop(context);
    File imageFile = await ImagePicker.pickImage(
      source: ImageSource.gallery,
    );
    setState(() {
      this.file = imageFile;
    });
  }

  takeImage(mContext){
    return showDialog(
        context: mContext,
        builder: (context){
          return SimpleDialog(
            title: Text("New Post", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            children: <Widget>[
              SimpleDialogOption(
                child: Text("Capture Image with Camera", style: TextStyle(color: Colors.white, fontSize: 18.0)),
                onPressed: captureImageWithCamera,
              ),
              SimpleDialogOption(
                child: Text("Select Image from Gallery", style: TextStyle(color: Colors.white, fontSize: 18.0)),
                onPressed: pickImageFromGallery,
              ),
              SimpleDialogOption(
                child: Text("Cancel", style: TextStyle(color: Colors.white, fontSize: 18.0)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          );
        }
    );
  }

  Widget displayUploadScreen(){
    return Container(
      color: Theme.of(context).accentColor.withOpacity(0.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.add_photo_alternate, color: Colors.grey, size: 200.0),
          Padding(
            padding: EdgeInsets.only(top: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TextButton(
                  onPressed: uploading ? null : () => controlUploadAndSave(),
                  child: Text("Share", style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 16.0)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9.0)),
                    primary: Colors.blue,
                  ),
                  child: Text("Upload Image", style: TextStyle(color: Colors.white, fontSize: 20.0)),
                  onPressed: () => takeImage(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  clearPostInfo(){
    locationTextEditingController.clear();
    descriptionTextEditingController.clear();

    setState(() {
      file = null;
    });
  }

  getUserCurrentLocation() async{
    Position position = await Geolocator().getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    List <Placemark> placeMarks = await Geolocator().placemarkFromCoordinates(position.latitude, position.longitude);
    Placemark mPlacemark = placeMarks[0];
    String completeAdressInfo = '${mPlacemark.subThoroughfare} ${mPlacemark.thoroughfare}, ${mPlacemark.subLocality} ${mPlacemark.locality}, ${mPlacemark.subAdministrativeArea} ${mPlacemark.administrativeArea}, ${mPlacemark.postalCode} ${mPlacemark.country}';
    String specificAdress = '${mPlacemark.locality}, ${mPlacemark.country}';
    locationTextEditingController.text = specificAdress;
  }

  compressingPhoto() async{
    final tDirectory = await getTemporaryDirectory();
    final path = tDirectory.path;
    ImD.Image mImageFile = ImD.decodeImage(file.readAsBytesSync());
    final compressedImageFile = File('$path/img_$postId.jpg')..writeAsBytesSync(ImD.encodeJpg(mImageFile, quality: 60));
    setState(() {
      file = compressedImageFile;
    });
  }

  controlUploadAndSave() async {
    setState(() {
      uploading = true;
    });

    await compressingPhoto();

    String downloadUrl = await uploadPhoto(file);

    savePostInfoToFireStore(url: downloadUrl, location: locationTextEditingController.text, description: descriptionTextEditingController.text);

    locationTextEditingController.clear();
    descriptionTextEditingController.clear();

    setState(() {
      file = null;
      uploading = false;
      postId = Uuid().v4();
    });
  }

  savePostInfoToFireStore({String url, String location, String description}){
    postsReference
        .document(widget.gCurrentUser.id)
        .collection("usersPosts")
        .document(postId)
        .setData({
      "postId": postId,
      "ownerId": widget.gCurrentUser.id,
      "timestamp": DateTime.now(),
      "likes": {},
      "profileName": widget.gCurrentUser.profileName,
      "username": widget.gCurrentUser.username,
      "description": description,
      "location": location,
      "url": url
    });

  }

  Future <String> uploadPhoto(mImageFile) async {
    StorageUploadTask storageUploadTask = storageReference.child("post_$postId.jpg").putFile(mImageFile);
    StorageTaskSnapshot storageTaskSnapshot = await storageUploadTask.onComplete;
    String downloadUrl = await storageTaskSnapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  Widget displayUploadFormScreen(){
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: clearPostInfo,
        ),
        title: Text(
          "New Post",
          style: TextStyle(fontSize: 24.0, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: uploading ? null : () => controlUploadAndSave(),
            child: Text(
              "Share",
              style: TextStyle(
                color: Colors.lightBlueAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16.0,
              ),
            ),
          ),
        ],
      ),

      body: ListView(
        children: <Widget>[
          uploading ? linearProgress() : Text(""),
          Container(
            height: 230.0,
            width: MediaQuery.of(context).size.width * 0.8,
            child: Center(
              child: AspectRatio(
                aspectRatio: 16/9,
                child: Container(
                  decoration: BoxDecoration(
                      image: DecorationImage(image: FileImage(file), fit: BoxFit.cover)
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: EdgeInsets.only(top: 12.0)),
          ListTile(
            leading: CircleAvatar(backgroundImage: CachedNetworkImageProvider(widget.gCurrentUser.url)),
            title: Container(
              width: 250.0,
              child: TextField(
                style: TextStyle(color: Colors.white),
                controller: descriptionTextEditingController,
                decoration: InputDecoration(
                  hintText: "Write a caption...",
                  hintStyle: TextStyle(color: Colors.white),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.person_pin, color: Colors.white, size: 36.0),
            title: Container(
              width: 250.0,
              child: TextField(
                style: TextStyle(color: Colors.white),
                controller: locationTextEditingController,
                decoration: InputDecoration(
                  hintText: "Write the location here...",
                  hintStyle: TextStyle(color: Colors.white),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          Container(
            width: 220.0,
            height: 110.0,
            alignment: Alignment.center,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(35.0)
                ),
                primary: Colors.blue,
              ),
              icon: Icon(Icons.location_on, color: Colors.white),
              label: Text("Get my current location", style: TextStyle(color: Colors.white)),
              onPressed: getUserCurrentLocation,
            ),

          ),
        ],
      ),
    );
  }
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    return file == null ? displayUploadScreen(): displayUploadFormScreen();
  }
}
