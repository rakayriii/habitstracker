import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_bottom_nav.dart';
import '../features/finance/presentation/account_form_page.dart';
import '../features/finance/presentation/accounts_page.dart';
import '../features/finance/presentation/finance_page.dart';
import '../features/finance/presentation/transaction_detail_page.dart';
import '../features/finance/presentation/transaction_form_page.dart';
import '../features/focus/presentation/focus_form_page.dart';
import '../features/goals/presentation/goal_detail_page.dart';
import '../features/goals/presentation/goal_form_page.dart';
import '../features/goals/presentation/goals_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/projects/presentation/project_detail_page.dart';
import '../features/projects/presentation/project_form_page.dart';
import '../features/projects/presentation/projects_page.dart';
import '../features/projects/presentation/task_form_page.dart';

/// Four workspaces live in the shell so their scroll position and filter state
/// survive a tab switch. Detail and form screens are pushed on top of the
/// shell as full screen routes, which is why they are declared outside it.
final router = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: HomePage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/finance',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: FinancePage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/goals',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: GoalsPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/projects',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ProjectsPage()),
            ),
          ],
        ),
      ],
    ),

    // ------------------------------------------------------------- finance
    GoRoute(
      path: '/finance/accounts',
      builder: (context, state) => const AccountsPage(),
    ),
    GoRoute(
      path: '/finance/account/new',
      builder: (context, state) => const AccountFormPage(),
    ),
    GoRoute(
      path: '/finance/account/:id',
      builder: (context, state) => AccountFormPage(
        accountId: state.pathParameters['id'],
      ),
    ),
    GoRoute(
      path: '/finance/transaction/new',
      builder: (context, state) => const TransactionFormPage(),
    ),
    // Declared before the bare ':id' route so "new" is never read as an id.
    GoRoute(
      path: '/finance/transaction/:id/edit',
      builder: (context, state) => TransactionFormPage(
        transactionId: state.pathParameters['id'],
      ),
    ),
    GoRoute(
      path: '/finance/transaction/:id',
      builder: (context, state) => TransactionDetailPage(
        transactionId: state.pathParameters['id']!,
      ),
    ),

    // --------------------------------------------------------------- goals
    GoRoute(
      path: '/goals/new',
      builder: (context, state) => const GoalFormPage(),
    ),
    GoRoute(
      path: '/goals/:id/edit',
      builder: (context, state) => GoalFormPage(goalId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/goals/:id',
      builder: (context, state) =>
          GoalDetailPage(goalId: state.pathParameters['id']!),
    ),

    // ------------------------------------------------------------ projects
    GoRoute(
      path: '/projects/new',
      builder: (context, state) => const ProjectFormPage(),
    ),
    GoRoute(
      path: '/projects/:id/edit',
      builder: (context, state) =>
          ProjectFormPage(projectId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/projects/:id/task/new',
      builder: (context, state) =>
          TaskFormPage(projectId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/projects/:id/task/:taskId',
      builder: (context, state) => TaskFormPage(
        projectId: state.pathParameters['id']!,
        taskId: state.pathParameters['taskId'],
      ),
    ),
    GoRoute(
      path: '/projects/:id',
      builder: (context, state) =>
          ProjectDetailPage(projectId: state.pathParameters['id']!),
    ),

    // --------------------------------------------------------------- focus
    GoRoute(
      path: '/focus/new',
      builder: (context, state) => const FocusFormPage(),
    ),
    GoRoute(
      path: '/focus/:id',
      builder: (context, state) => FocusFormPage(focusId: state.pathParameters['id']),
    ),
  ],
);

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: navigationShell.currentIndex,
        onSelect: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
