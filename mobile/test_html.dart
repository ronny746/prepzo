import 'package:html/parser.dart' as html_parser;
void main() {
  var doc = html_parser.parseFragment('<math><mfrac><mn>1</mn><mn>2</mn></mfrac></math>');
  print(doc.children.length);
}
