import 'package:objectbox/objectbox.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../objectbox.g.dart';

class ObjectBox {
  late final Store store;

  ObjectBox._create(this.store);

  static Future<ObjectBox> create() async {
    final docsDir = await getApplicationSupportDirectory();
    final store = await openStore(directory: p.join(docsDir.path, "rag_objectbox"));
    return ObjectBox._create(store);
  }
}
