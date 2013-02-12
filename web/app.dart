import 'dart:html';
import 'package:web_ui/web_ui.dart';

main() {

}

List<Phone> phones = [
    new Phone("Nexus S", "Fast just got faster with Nexus S."),
    new Phone("Motorola XOOM™ with Wi-Fi","The Next, Next Generation tablet."),
    new Phone("MOTOROLA XOOM™", "The Next, Next Generation tablet.") 
  ];

class Phone {
  String name;
  String snippet;
  
  Phone(this.name, this.snippet);
}