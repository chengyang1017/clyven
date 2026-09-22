import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'components/admin_auth_gate.dart';
import 'pages/review_page.dart';

class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'admin-app', [
      AdminAuthGate(child: const ReviewPage()),
    ]);
  }
}
