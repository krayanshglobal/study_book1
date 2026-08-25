import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'app_logo.dart';

// ─────────────────────────────────────────────────────────────────────────────
// App Drawer
// ─────────────────────────────────────────────────────────────────────────────

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isAdmin = user?.isAdmin ?? false;
    final isSuperAdmin = user?.isSuperAdmin ?? false;

    // User initials for avatar
    final initials = (user?.name.isNotEmpty == true)
        ? user!.name
            .split(' ')
            .take(2)
            .map((s) => s.isNotEmpty ? s[0] : '')
            .join()
            .toUpperCase()
        : 'SB';

    final planLabel =
        user?.subscriptionActive == true ? 'Premium Member' : 'Free Plan';

    return Drawer(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      width: 292,
      child: Column(
        children: [
          // ── Premium Header ───────────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.navy,
                  Color(0xFF1E3A8A),
                  Color(0xFF312E81),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo + app name row
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const AppLogo(size: 36),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'StudyBook',
                              style: GoogleFonts.fraunces(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'LEARN • FOCUS • ACHIEVE',
                              style: GoogleFonts.inter(
                                color: Colors.white60,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                  ],
                ),
              ),
            ),
          ),

          // ── Nav Items ────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                if (!isAdmin) ...[
                  const _NavItem(
                      icon: Icons.dashboard_rounded,
                      label: 'Dashboard',
                      route: '/dashboard'),
                  const _NavItem(
                      icon: Icons.explore_rounded,
                      label: 'Study Explorer',
                      route: '/explorer'),
                  const _NavItem(
                      icon: Icons.quiz_rounded,
                      label: 'Question Bank',
                      route: '/questions'),
                  const _NavItem(
                      icon: Icons.assignment_rounded,
                      label: 'Tests',
                      route: '/tests'),
                  const _NavItem(
                      icon: Icons.play_circle_rounded,
                      label: 'Videos',
                      route: '/videos'),
                  const _NavItem(
                      icon: Icons.leaderboard_rounded,
                      label: 'Leaderboard',
                      route: '/leaderboard'),
                  const _NavItem(
                      icon: Icons.bar_chart_rounded,
                      label: 'My Analytics',
                      route: '/my-analytics'),
                  const _NavItem(
                      icon: Icons.share_rounded,
                      label: 'Referrals',
                      route: '/referrals'),
                  const _NavItem(
                      icon: Icons.workspace_premium_rounded,
                      label: 'Pricing',
                      route: '/pricing'),
                ],
                if (isAdmin) ...[
                  const _NavItem(
                      icon: Icons.dashboard_rounded,
                      label: 'Overview',
                      route: '/admin'),
                  const _NavItem(
                      icon: Icons.quiz_rounded,
                      label: 'Questions',
                      route: '/admin/questions'),
                  const _NavItem(
                      icon: Icons.assignment_rounded,
                      label: 'Tests',
                      route: '/admin/tests'),
                  const _NavItem(
                      icon: Icons.play_circle_rounded,
                      label: 'Videos',
                      route: '/admin/videos'),
                  const _NavItem(
                      icon: Icons.article_rounded,
                      label: 'Study Notes',
                      route: '/admin/notes'),
                  const _NavItem(
                      icon: Icons.local_offer_rounded,
                      label: 'Offers',
                      route: '/admin/promos'),
                  const _NavItem(
                      icon: Icons.bar_chart_rounded,
                      label: 'Analytics',
                      route: '/admin/analytics'),
                  const _NavItem(
                      icon: Icons.group_rounded,
                      label: 'Users',
                      route: '/admin/users'),
                  const _NavItem(
                      icon: Icons.workspace_premium_rounded,
                      label: 'Plans',
                      route: '/admin/plans'),
                  const _NavItem(
                      icon: Icons.campaign_rounded,
                      label: 'Announcements',
                      route: '/admin/announcements'),
                  const _NavItem(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Class Requests',
                      route: '/admin/class-requests'),
                  const _NavItem(
                      icon: Icons.style_rounded,
                      label: 'Flashcards',
                      route: '/admin/flashcards'),
                  const _NavItem(
                      icon: Icons.payments_rounded,
                      label: 'Payments',
                      route: '/admin/payments'),
                  if (isSuperAdmin)
                    const _NavItem(
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Super Admin',
                        route: '/superadmin'),
                ],
              ],
            ),
          ),

          // ── Profile Card (Bottom of Drawer) ─────────────────────────────
          if (user != null && !isAdmin)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _DrawerProfileCard(
                  initials: initials,
                  name: user.name,
                  planLabel: planLabel,
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push('/profile');
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav Item
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _NavItem(
      {required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isActive = location == route ||
        (route != '/' &&
            route != '/admin' &&
            location.startsWith('$route/'));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: isActive
            ? AppColors.blue.withAlpha(15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).pop();
            if (location == route) return;
            context.go(route);
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.blue.withAlpha(20)
                        : AppColors.slate100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 18,
                      color: isActive
                          ? AppColors.blue
                          : AppColors.slate500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? AppColors.navy
                          : AppColors.slate700,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drawer Profile Card  (reference image 2)
// ─────────────────────────────────────────────────────────────────────────────

class _DrawerProfileCard extends StatelessWidget {
  final String initials;
  final String name;
  final String planLabel;
  final VoidCallback onTap;

  const _DrawerProfileCard({
    required this.initials,
    required this.name,
    required this.planLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF0B2D7A),
              Color(0xFF233EA5),
              Color(0xFF5A2DDB),
            ],
          ),
          borderRadius: BorderRadius.all(Radius.circular(14)),
          border: Border.fromBorderSide(
              BorderSide(color: Color(0xFF4A6FCC), width: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF0B2D7A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Purple avatar circle with first letter
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.violet,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials.isNotEmpty ? initials[0] : 'U',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + plan badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2A6D),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      planLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right arrow
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Persistent Bottom Navigation Bar (Material 3)
// ─────────────────────────────────────────────────────────────────────────────

class AppBottomNavBar extends ConsumerWidget {
  const AppBottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user?.isAdmin == true) return const SizedBox.shrink();

    final location = GoRouterState.of(context).matchedLocation;
    final path = location.split('?').first;

    // Hide bottom nav on full screen pages
    final bool isFullScreenPage = path == '/' ||
        path == '/landing' ||
        path == '/login' ||
        path == '/register' ||
        path == '/forgot-password' ||
        path == '/payment/success' ||
        (path.startsWith('/tests/') &&
            (path.endsWith('/live') || path.endsWith('/result')));

    if (isFullScreenPage) return const SizedBox.shrink();

    int currentIndex = 0;
    if (path == '/dashboard') {
      currentIndex = 0;
    } else if (path == '/explorer' || path == '/questions') {
      currentIndex = 1;
    } else if (path == '/tests') {
      currentIndex = 2;
    } else if (path == '/my-analytics' || path == '/leaderboard') {
      currentIndex = 3;
    } else if (path == '/profile' ||
        path == '/referrals' ||
        path == '/pricing' ||
        path == '/videos') {
      currentIndex = 4;
    }

    const items = [
      _NavBarItemData(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
        route: '/dashboard',
      ),
      _NavBarItemData(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore_rounded,
        label: 'Explore',
        route: '/explorer',
      ),
      _NavBarItemData(
        icon: Icons.assignment_outlined,
        activeIcon: Icons.assignment_rounded,
        label: 'Tests',
        route: '/tests',
      ),
      _NavBarItemData(
        icon: Icons.bar_chart_rounded,
        activeIcon: Icons.bar_chart_rounded,
        label: 'Analytics',
        route: '/my-analytics',
      ),
      _NavBarItemData(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profile',
        route: '/profile',
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.slate200, width: 0.8),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isActive = index == currentIndex;

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (path != item.route) {
                        context.go(item.route);
                      }
                    },
                    splashColor: AppColors.blue.withAlpha(20),
                    highlightColor: Colors.transparent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.blue.withAlpha(18)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            isActive ? item.activeIcon : item.icon,
                            color: isActive
                                ? AppColors.blue
                                : const Color(0xFF94A3B8), // Slate 400 grey
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? AppColors.blue
                                : const Color(0xFF94A3B8), // Slate 400 grey
                          ),
                          child: Text(item.label),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavBarItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  const _NavBarItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Scaffold
// ─────────────────────────────────────────────────────────────────────────────

class MainScaffold extends ConsumerStatefulWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final bool showBack;
  final String parentRoute;
  final bool showBottomNav;

  const MainScaffold({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.actions,
    this.showBack = false,
    this.parentRoute = '/dashboard',
    this.showBottomNav = true,
  });

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      final user = ref.read(authProvider).user;
      final defaultParent =
          (user?.isAdmin ?? false) ? '/admin' : '/dashboard';
      final targetParent =
          (widget.parentRoute == '/dashboard' && (user?.isAdmin ?? false))
              ? '/admin'
              : widget.parentRoute;
      context.go(targetParent.isNotEmpty ? targetParent : defaultParent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.isAdmin ?? false;
    final initials = (user?.name.isNotEmpty == true)
        ? user!.name
            .split(' ')
            .take(2)
            .map((s) => s.isNotEmpty ? s[0] : '')
            .join()
            .toUpperCase()
        : 'SB';

    final String matched = GoRouterState.of(context).matchedLocation;
    final String path = matched.split('?').first;
    final bool isFullScreenPage = path == '/' ||
        path == '/landing' ||
        path == '/login' ||
        path == '/register' ||
        path == '/forgot-password' ||
        path == '/payment/success' ||
        (path.startsWith('/tests/') &&
            (path.endsWith('/live') || path.endsWith('/result')));

    final bool displayBottomNav =
        widget.showBottomNav && !isAdmin && !isFullScreenPage;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_scaffoldKey.currentState?.isDrawerOpen == true) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }
        final String matched = GoRouterState.of(context).matchedLocation;
        final String path = matched.split('?').first;
        final bool isRootScreen = path == '/dashboard' ||
            path == '/admin' ||
            path == '/superadmin' ||
            path == '/' ||
            path == '/login';

        if (!isRootScreen) {
          if (context.canPop()) {
            context.pop();
          } else {
            final defaultParent =
                (user?.isAdmin ?? false) ? '/admin' : '/dashboard';
            final targetParent =
                (widget.parentRoute == '/dashboard' &&
                        (user?.isAdmin ?? false))
                    ? '/admin'
                    : widget.parentRoute;
            context.go(
                targetParent.isNotEmpty ? targetParent : defaultParent);
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.background,
        drawer: const AppDrawer(),

        // ── Premium AppBar ────────────────────────────────────────────────
        appBar: AppBar(
          backgroundColor: AppColors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,

          // Leading: hamburger or back
          leading: widget.showBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.navy, size: 20),
                  onPressed: _handleBack,
                )
              : Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu_rounded,
                        color: AppColors.navy, size: 22),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),

          // Title: Logo + "StudyBook"
          title: widget.showBack
              ? Text(
                  widget.title,
                  style: GoogleFonts.fraunces(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppLogo(size: 32),
                    const SizedBox(width: 8),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [AppColors.navy, AppColors.blue],
                      ).createShader(bounds),
                      child: Text(
                        'StudyBook',
                        style: GoogleFonts.fraunces(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white, // masked by shader
                        ),
                      ),
                    ),
                  ],
                ),

          // Actions: custom + notification + avatar
          actions: [
            if (widget.actions != null) ...widget.actions!,
            // Notification bell with unread badge
            Consumer(
              builder: (context, ref, _) {
                final unreadCount = ref.watch(notificationProvider).unreadCount;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded,
                          color: AppColors.navy, size: 22),
                      onPressed: () => context.push('/notifications'),
                      tooltip: 'Notifications',
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            // Profile avatar
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  final location =
                      GoRouterState.of(context).matchedLocation.split('?').first;
                  if (location != '/profile') {
                    context.push('/profile');
                  }
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.blue, AppColors.violet],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AppColors.slate200),
          ),
        ),

        body: widget.body,
        floatingActionButton: widget.floatingActionButton,
        bottomNavigationBar: displayBottomNav ? const AppBottomNavBar() : null,
      ),
    );
  }
}

