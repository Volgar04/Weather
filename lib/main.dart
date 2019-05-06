import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'package:geocoder/geocoder.dart';
import 'package:http/http.dart' as http;
import 'package:weather/temperature.dart';
import 'dart:convert';
import 'my_flutter_app_icons.dart';

void main() {
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent
    ));
    return new MaterialApp(
      home: new MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State createState() => new MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {

  String _key = "cities";
  List<String> _cities = [];
  String _cityChosen;
  Coordinates coordinatesCityChosed;
  Temperature temperature;
  String nameCurrent = "Current City";

  Location _location;
  LocationData _locationData;
  Stream<LocationData> stream;
  
  AssetImage night = AssetImage("assets/n.jpg");
  AssetImage sun = AssetImage("assets/d1.jpg");
  AssetImage rain = AssetImage("assets/d2.jpg");


  @override
  void initState() {
    super.initState();
    getPreferences();
    _location = new Location();
    listenToStream();
  }

  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: (temperature == null) ? AppBar(
        backgroundColor: Colors.white,
        elevation: 0.0,
        title: new Text('FlutterWeather'),
      )
      : AppBar(
          backgroundColor: (getBackgroundColor()),
          elevation: 0.0,
          title: new Text('FlutterWeather'),
      ),
      drawer: new Drawer(
        child: new Container(
          color: Colors.grey,
          child: new ListView.builder(
            itemCount: _cities.length + 2,
            itemBuilder: (context, i){
              if (i==0){
                return DrawerHeader(
                  decoration: new BoxDecoration(
                    color: Colors.grey
                  ),
                  child: new Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      textWithStyle("My Cities", fontSize: 22.0),
                      new RaisedButton(
                          color: Colors.white,
                          elevation: 8.0,
                          child: textWithStyle("Add city", color: Colors.grey),
                          onPressed: addCity
                      )
                    ],
                  ),
                );
              } else if(i==1){
                return new ListTile(
                  title: textWithStyle(nameCurrent),
                  onTap: (){
                    setState(() {
                      _cityChosen = null;
                      coordinatesCityChosed = null;
                      weatherApi();
                      Navigator.pop(context);
                    });
                  },
                );
              }else{
                String city = _cities[i-2];
                return new ListTile(
                  title: textWithStyle(city),
                  trailing: new IconButton(
                      icon: new Icon(Icons.delete, color: Colors.white,),
                      onPressed: (() => deletePreferences(city))
                  ),
                  onTap: () {
                    setState(() {
                      _cityChosen = city;
                      coordinatesToCity();
                      Navigator.pop(context);
                    });
                  },
                );
              }
            }),
        ),
      ),
      body: (temperature == null) ? Center(
        child: new Text((_cityChosen == null)? "Current city ": _cityChosen))
        : Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        color: getBackgroundColor(),
        //decoration: new BoxDecoration(
        //  image: new DecorationImage(image: getBackground(), fit: BoxFit.cover)
        //),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            Column(
              children: <Widget>[
                Text((_cityChosen==null) ? nameCurrent : _cityChosen, style: new TextStyle(fontWeight: FontWeight.bold, fontSize: 50.0, color: Colors.white)),
                //textWithStyle((_cityChosen==null) ? nameCurrent : _cityChosen, fontSize: 40.0,  ),
                Container(
                  height: 15.0,
                ),
                textWithStyle(temperature.description, fontSize: 30.0),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                new Icon(getIcon(), color: Colors.white, size: 150.0,),
                textWithStyle("${temperature.temp.toInt()}°C", fontSize: 75.0)
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                extra("${temperature.min.toInt()}°C", MyFlutterApp.down),
                extra("${temperature.max.toInt()}°C", MyFlutterApp.up),
                extra("${temperature.pressure.toInt()}", MyFlutterApp.temperatire),
                extra("${temperature.humidity.toInt()}%", MyFlutterApp.drizzle),
              ],
            )
          ],
        ),
      )
    );
  }

  Column extra(String data, IconData iconData){
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        Icon(iconData, color: Colors.white, size: 30.0,),
        textWithStyle(data)
      ],
    );
  }

  Text textWithStyle(String data, {color: Colors.white, fontSize: 18.0, fontStyle: FontStyle.italic, textAlign: TextAlign.center}){
    return new Text(
      data,
      textAlign: textAlign,
      style: new TextStyle(
          color: color,
          fontStyle: fontStyle,
          fontSize: fontSize
      ),
    );
  }

  Future<Null> addCity() async {
    return showDialog(
        barrierDismissible: true,
        builder: (BuildContext buildContext){
          return new SimpleDialog(
            contentPadding: EdgeInsets.all(20.0),
            title: textWithStyle("Add city", fontSize: 22.0, color: Colors.grey),
            children: <Widget>[
              new TextField(
                  decoration: new InputDecoration(
                      labelText: "City: "
                  ),
                  onSubmitted: (String str){
                    addPreferences(str);
                    Navigator.pop(context);
                  }
              )
            ],
          );
        },
        context: context
    );
  }

  //*************************
  //SHARED PREFERENCES
  //*************************

  //get all preferences
  void getPreferences() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    List<String> list = await sharedPreferences.getStringList(_key);
    if(list!=null){
      setState(() {
        _cities = list;
      });
    }
  }

  //add a new city in preferences
  void addPreferences(String str) async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    _cities.add(str);
    await sharedPreferences.setStringList(_key, _cities);
    getPreferences();
  }

  //remove a city of preferences
  void deletePreferences(String str) async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    _cities.remove(str);
    await sharedPreferences.setStringList(_key, _cities);
    getPreferences();
  }

  IconData getIcon() {
    String icon = temperature.icon.replaceAll('d', '').replaceAll('n', '');
    //return AssetImage("assets/$icon.png");
    switch (icon) {
      case '01':
        return MyFlutterApp.sun;
        break;
      case '02':
        return MyFlutterApp.cloud_sun;
        break;
      case '03':
        return MyFlutterApp.cloud_sun;
        break;
      case '04':
        return MyFlutterApp.cloud;
        break;
      case '09':
        return MyFlutterApp.rain;
        break;
      case '10':
        return MyFlutterApp.drizzle;
        break;
      case '11':
        return MyFlutterApp.cloud_flash;
        break;
      case '13':
        return MyFlutterApp.snow;
        break;
      case '50':
        return MyFlutterApp.wind;
        break;
    }
  }

  Color getBackgroundColor(){
    print(temperature.icon);
    if (temperature.icon.contains("n")){

      return Colors.blueGrey[800];
    } else {
      return Colors.blue[200];
    }
  }

  //*************************
  //LOCATION
  //*************************

  //Each Change
  listenToStream() {
    stream = _location.onLocationChanged();
    stream.listen((newPosition) {
      if((_locationData==null) || (newPosition.longitude!=_locationData.longitude) && (newPosition.latitude!=_locationData.latitude)){
        setState(() {
          print("New => ${newPosition.latitude} / ${newPosition.longitude}");
          _locationData = newPosition;
          locationToString();
        });
      }
    });
  }

  //*************************
  //GEOCODER
  //*************************

  //convert coordinates in city
  locationToString() async {
    if(_locationData!=null){
      Coordinates coordinates = new Coordinates(_locationData.latitude, _locationData.longitude);
      final cityName = await Geocoder.local.findAddressesFromCoordinates(coordinates);
      setState(() {
        nameCurrent = cityName.first.locality;
        weatherApi();
      });
    }
  }

  //convert city in coordinates
  coordinatesToCity() async {
    if (_cityChosen != null){
      List<Address> addresses = await Geocoder.local.findAddressesFromQuery(_cityChosen);
      if(addresses.length > 0){
        Address first = addresses.first;
        Coordinates coordinates = first.coordinates;
        setState(() {
          coordinatesCityChosed = coordinates;
          weatherApi();
        });
      }
     }
  }

  //*************************
  //API https://openweathermap.org/
  //*************************

  weatherApi() async{
    double lat;
    double lon;
    if (coordinatesCityChosed!=null){
      lat = coordinatesCityChosed.latitude;
      lon = coordinatesCityChosed.longitude;
    }else if(_locationData!=null){
      lat = _locationData.latitude;
      lon = _locationData.longitude;
    }

    if(lat!=null && lon != null){
      final key = "&APPID=a2124b74360dd75d920379c61b629aea";
      String lang = "&lang=${Localizations.localeOf(context).languageCode}";
      String baseAPI = "http://api.openweathermap.org/data/2.5/weather?";
      String coordsString = "lat=$lat&lon=$lon";
      String units = "&units=metric";
      String totalString = baseAPI + coordsString + units + lang + key;
      final response = await http.get(totalString);
      if (response.statusCode == 200){
        Map map = json.decode(response.body);
        setState(() {
          temperature = Temperature(map);
          print(temperature.description);
        });
      }
    }
  }
}