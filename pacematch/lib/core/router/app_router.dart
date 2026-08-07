import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/calendar/calendar_screen.dart';
import '../../features/groups/create_group_screen.dart';
import '../../features/groups/group_detail_screen.dart';
import '../../features/groups/groups_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/companions_screen.dart';
import '../../features/profile/my_rides_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/rider_profile_screen.dart';
import '../../data/models.dart';
import '../../data/route_models.dart';
import '../../features/rides/create_ride_screen.dart';
import '../../features/rides/ride_detail_screen.dart';
import '../../features/rides/route_planner_screen.dart';
import '../../shared/widgets/shell_scaffold.dart';

class AppRouter {
  static GoRouter create(AppState state) {
    return GoRouter(
      initialLocation: '/home',
      refreshListenable: state,
      redirect: (context, routerState) {
        final loc = routerState.matchedLocation;
        final loggingIn = loc == '/login' || loc == '/register';
        final onboarding = loc == '/onboarding';

        if (!state.isAuthenticated) {
          return loggingIn ? null : '/login';
        }
        if (!state.onboardingComplete && !onboarding) {
          return '/onboarding';
        }
        if (state.onboardingComplete && (loggingIn || onboarding)) {
          return '/home';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, _) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, _) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, _) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/create-group',
          builder: (context, _) => const CreateGroupScreen(),
        ),
        GoRoute(
          path: '/create-ride',
          builder: (context, state) {
            final groupId = state.uri.queryParameters['groupId'];
            final extra = state.extra;
            final initialRoute = extra is PlannedRoute ? extra : null;
            return CreateRideScreen(
              preselectedGroupId: groupId,
              initialRoute: initialRoute,
            );
          },
        ),
        GoRoute(
          path: '/plan-route',
          builder: (context, state) {
            final bikeParam = state.uri.queryParameters['bike'];
            final bike = BikeType.values.where((b) => b.name == bikeParam);
            return RoutePlannerScreen(
              initialBikeType:
                  bike.isEmpty ? BikeType.road : bike.first,
            );
          },
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return ShellScaffold(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, _) => const HomeScreen(),
                  routes: [
                    GoRoute(
                      path: 'ride/:id',
                      builder: (context, state) => RideDetailScreen(
                        rideId: state.pathParameters['id']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/calendar',
                  builder: (context, _) => const CalendarScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/groups',
                  builder: (context, _) => const GroupsScreen(),
                  routes: [
                    GoRoute(
                      path: ':id',
                      builder: (context, state) => GroupDetailScreen(
                        groupId: state.pathParameters['id']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, _) => const ProfileScreen(),
                  routes: [
                    GoRoute(
                      path: 'my-rides',
                      builder: (context, _) => const MyRidesScreen(),
                    ),
                    GoRoute(
                      path: 'companions',
                      builder: (context, _) => const CompanionsScreen(),
                    ),
                    GoRoute(
                      path: 'rider/:id',
                      builder: (context, state) => RiderProfileScreen(
                        riderId: state.pathParameters['id']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
