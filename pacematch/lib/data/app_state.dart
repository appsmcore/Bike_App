import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/backend_sync_service.dart';
import '../services/local_profile_store.dart';
import 'fake_data.dart';
import 'models.dart';
import 'route_models.dart';

class AppState extends ChangeNotifier {
  AppState() {
    if (!AuthService.isConfigured) {
      _seedDemoCatalog();
    }
  }

  bool isAuthenticated = false;
  bool onboardingComplete = false;
  bool authReady = false;
  bool syncing = false;
  String? syncError;
  ThemeMode themeMode = ThemeMode.system;
  bool get usesBackendAuth => AuthService.isConfigured;

  UserProfile profile = demoProfile;
  final Map<String, RsvpStatus> rsvps = {};
  final Set<String> joinedGroupIds = {};

  List<Ride> _rides = [];
  List<CyclingGroup> _groups = [];
  List<RiderProfile> _riders = [];
  Map<String, List<String>> _rideParticipantIds = {};
  List<RidePhoto> _ridePhotos = [];
  List<GroupMessage> _groupMessages = [];
  final List<SavedRoute> _savedRoutes = [];

  // Onboarding draft
  final Set<BikeType> draftBikes = {};
  FitnessLevel draftFitness = FitnessLevel.intermediate;
  final Set<String> draftDays = {'Sat', 'Sun'};
  RangeValues draftDistance = const RangeValues(40, 100);
  RangeValues draftElevation = const RangeValues(200, 1500);
  final Set<TerrainPref> draftTerrains = {
    TerrainPref.flat,
    TerrainPref.climbs,
  };

  String get currentUserId => profile.id;

  StreamSubscription<AuthState>? _authSubscription;

  /// Restore Supabase session and listen for sign-in / sign-out.
  Future<void> initAuth() async {
    if (!usesBackendAuth) {
      authReady = true;
      notifyListeners();
      return;
    }

    _applySupabaseUser(AuthService.currentUser, notify: false);
    if (AuthService.hasSession) {
      await _restoreSessionProfile();
      await refreshSharedData();
    }
    _authSubscription = AuthService.authStateChanges.listen((event) {
      final user = event.session?.user;
      if (user == null) {
        _applySupabaseUser(null);
        return;
      }
      // Skip duplicate handling when loginWithPassword already applied this user.
      final already = isAuthenticated && profile.id == user.id;
      _applySupabaseUser(user, notify: false);
      unawaited(() async {
        if (!already || !onboardingComplete) {
          await _restoreSessionProfile();
        }
        await refreshSharedData();
        notifyListeners();
      }());
    });
    authReady = true;
    notifyListeners();
  }

  void _seedDemoCatalog() {
    _rides = createDemoRides();
    _groups = createDemoGroups();
    _riders = createDemoRiders();
    _rideParticipantIds = createDemoRideParticipants();
    _ridePhotos = createDemoRidePhotos();
    _groupMessages = createDemoGroupMessages();
    joinedGroupIds
      ..clear()
      ..addAll({'g1', 'g3'});
    rsvps
      ..clear()
      ..addAll({
        'ride-road-1': RsvpStatus.joined,
        'ride-gravel-1': RsvpStatus.joined,
        'ride-mtb-1': RsvpStatus.maybe,
        'ride-past-1': RsvpStatus.joined,
        'ride-past-2': RsvpStatus.joined,
        'ride-past-3': RsvpStatus.joined,
        'ride-past-4': RsvpStatus.joined,
        'ride-past-5': RsvpStatus.joined,
        'ride-offered-1': RsvpStatus.joined,
        'ride-offered-2': RsvpStatus.joined,
      });
  }

  /// Pull groups, rides, memberships and RSVPs from Supabase.
  Future<void> refreshSharedData() async {
    if (!BackendSyncService.isAvailable) return;
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      final catalog = await BackendSyncService.fetchCatalog();
      _groups
        ..clear()
        ..addAll(catalog.groups);
      _rides
        ..clear()
        ..addAll(catalog.rides);
      joinedGroupIds
        ..clear()
        ..addAll(catalog.joinedGroupIds);
      rsvps
        ..clear()
        ..addAll(catalog.rsvps);
      _rideParticipantIds
        ..clear()
        ..addAll(
          catalog.rideParticipantIds.map(
            (key, value) => MapEntry(key, List<String>.from(value)),
          ),
        );
      // Keep local demos for riders/photos/chat until those are synced too.
      if (_riders.isEmpty) {
        _riders = createDemoRiders();
      }
    } catch (e) {
      syncError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  void _applySupabaseUser(User? user, {bool notify = true}) {
    if (user == null) {
      if (isAuthenticated) {
        isAuthenticated = false;
        onboardingComplete = false;
        profile = demoProfile;
        rsvps.clear();
        joinedGroupIds.clear();
        _rides.clear();
        _groups.clear();
        if (notify) notifyListeners();
      }
      return;
    }

    final name = (user.userMetadata?['display_name'] as String?)?.trim();
    final email = (user.email ?? profile.email).trim().toLowerCase();
    final displayName =
        name?.isNotEmpty == true ? name! : _nameFromEmail(user.email);
    final sameUser = isAuthenticated && profile.id == user.id;

    if (sameUser) {
      // Keep onboarding prefs already restored for this session.
      profile = profile.copyWith(
        name: displayName,
        email: email,
      );
    } else {
      profile = demoProfile.copyWith(
        id: user.id,
        name: displayName,
        email: email,
      );
      onboardingComplete = false;
    }
    isAuthenticated = true;
    if (notify) notifyListeners();
  }

  /// Load bike/fitness prefs from device so onboarding runs only once per account.
  Future<void> restoreSavedProfile() async {
    await _restoreSessionProfile();
    notifyListeners();
  }

  Future<void> _restoreSessionProfile() async {
    final saved = await LocalProfileStore.load(
      userId: profile.id,
      email: profile.email,
    );
    // Only set true when we find a completed profile. Never force false here —
    // a concurrent restore race must not wipe a successful load.
    if (saved == null || !saved.onboardingComplete) return;

    profile = profile.copyWith(
      name: saved.name ?? profile.name,
      email: saved.email ?? profile.email,
      location: saved.location ?? profile.location,
      bio: saved.bio ?? profile.bio,
      bikeTypes: saved.bikeTypes.isEmpty ? profile.bikeTypes : saved.bikeTypes,
      fitnessLevel: saved.fitnessLevel,
      preferredDays: saved.preferredDays.isEmpty
          ? profile.preferredDays
          : saved.preferredDays,
      preferredDistanceMin: saved.preferredDistanceMin,
      preferredDistanceMax: saved.preferredDistanceMax,
      preferredElevationMin: saved.preferredElevationMin,
      preferredElevationMax: saved.preferredElevationMax,
      preferredTerrains: saved.preferredTerrains.isEmpty
          ? profile.preferredTerrains
          : saved.preferredTerrains,
    );
    _syncDraftFromProfile();
    onboardingComplete = true;
  }

  void _syncDraftFromProfile() {
    draftBikes
      ..clear()
      ..addAll(profile.bikeTypes);
    draftFitness = profile.fitnessLevel;
    draftDays
      ..clear()
      ..addAll(profile.preferredDays);
    draftDistance = RangeValues(
      profile.preferredDistanceMin,
      profile.preferredDistanceMax,
    );
    draftElevation = RangeValues(
      profile.preferredElevationMin.toDouble(),
      profile.preferredElevationMax.toDouble(),
    );
    draftTerrains
      ..clear()
      ..addAll(profile.preferredTerrains);
  }

  Future<void> _persistProfilePrefs() async {
    await LocalProfileStore.save(
      profile: profile,
      onboardingComplete: onboardingComplete,
    );
  }

  String _nameFromEmail(String? email) {
    if (email == null || !email.contains('@')) return 'Rider';
    return email.split('@').first;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  List<Ride> get rides => List.unmodifiable(_rides);
  List<CyclingGroup> get groups => List.unmodifiable(_groups);
  List<RiderProfile> get riders => List.unmodifiable(_riders);
  List<SavedRoute> get savedRoutes => List.unmodifiable(_savedRoutes);

  /// Persist a planned route for later inspiration (not shown on home map).
  SavedRoute savePlannedRoute(
    PlannedRoute route, {
    String? name,
  }) {
    final stamp = DateTime.now();
    final label = (name == null || name.trim().isEmpty)
        ? '${route.bikeType.label} · ${route.distanceKm.toStringAsFixed(1)} km'
        : name.trim();
    final saved = SavedRoute(
      id: 'route-${stamp.millisecondsSinceEpoch}',
      name: label,
      createdAt: stamp,
      route: route,
      createdByUserId: currentUserId,
    );
    _savedRoutes.insert(0, saved);
    notifyListeners();
    return saved;
  }

  void deleteSavedRoute(String id) {
    _savedRoutes.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  SavedRoute? savedRouteById(String id) {
    try {
      return _savedRoutes.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Your groups first, then others — by start time within each bucket.
  /// Past rides are kept out of the home finder.
  List<Ride> get recommendedRides {
    final mine = <Ride>[];
    final others = <Ride>[];
    for (final ride in _rides) {
      if (ride.isPast) continue;
      if (joinedGroupIds.contains(ride.groupId)) {
        mine.add(ride);
      } else {
        others.add(ride);
      }
    }
    int byTime(Ride a, Ride b) => a.startsAt.compareTo(b.startsAt);
    mine.sort(byTime);
    others.sort(byTime);
    return [...mine, ...others];
  }

  Ride? rideById(String id) {
    try {
      return _rides.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  CyclingGroup? groupById(String id) {
    try {
      return _groups.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  RiderProfile? riderById(String id) {
    if (id == currentUserId) return profile.toPublicRider();
    try {
      return _riders.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  RsvpStatus rsvpFor(String rideId) => rsvps[rideId] ?? RsvpStatus.none;

  bool hasJoinedRsvp(String rideId) => rsvpFor(rideId) == RsvpStatus.joined;

  bool hasMaybeRsvp(String rideId) => rsvpFor(rideId) == RsvpStatus.maybe;

  /// Confirmed riders for a ride. Only available once you've joined.
  List<RiderProfile> confirmedRidersFor(String rideId, {bool includeSelf = true}) {
    if (!hasJoinedRsvp(rideId) && !isOrganizerOf(rideId)) {
      return const [];
    }
    final ids = _rideParticipantIds[rideId] ?? const <String>[];
    final riders = <RiderProfile>[];
    final seen = <String>{};

    if (includeSelf && hasJoinedRsvp(rideId)) {
      riders.add(profile.toPublicRider());
      seen.add(currentUserId);
    }

    for (final id in ids) {
      if (seen.contains(id)) continue;
      final rider = riderById(id);
      if (rider != null) {
        riders.add(rider);
        seen.add(id);
      }
    }

    final ride = rideById(rideId);
    final organizerId = ride?.organizerId;
    if (organizerId != null && !seen.contains(organizerId)) {
      final organizer = riderById(organizerId);
      if (organizer != null) {
        riders.insert(0, organizer);
      }
    }

    return riders;
  }

  bool canSeeParticipants(String rideId) =>
      hasJoinedRsvp(rideId) || isOrganizerOf(rideId);

  bool isOrganizerOf(String rideId) {
    final ride = rideById(rideId);
    return ride?.organizerId == currentUserId;
  }

  void setRsvp(String rideId, RsvpStatus status) {
    final previous = rsvpFor(rideId);
    if (status == RsvpStatus.none) {
      rsvps.remove(rideId);
    } else {
      rsvps[rideId] = status;
    }

    final list = _rideParticipantIds.putIfAbsent(rideId, () => <String>[]);
    if (status == RsvpStatus.joined && previous != RsvpStatus.joined) {
      if (!list.contains(currentUserId)) list.add(currentUserId);
    } else if (status != RsvpStatus.joined && previous == RsvpStatus.joined) {
      list.remove(currentUserId);
    }

    final ride = rideById(rideId);
    if (ride != null) {
      final idx = _rides.indexWhere((r) => r.id == rideId);
      if (idx >= 0) {
        _rides[idx] = Ride(
          id: ride.id,
          title: ride.title,
          description: ride.description,
          startsAt: ride.startsAt,
          meetingPoint: ride.meetingPoint,
          bikeType: ride.bikeType,
          distanceKm: ride.distanceKm,
          elevationM: ride.elevationM,
          participants: list.length,
          riderLimit: ride.riderLimit,
          difficulty: ride.difficulty,
          skillLevel: ride.skillLevel,
          groupId: ride.groupId,
          groupName: ride.groupName,
          coverGradient: ride.coverGradient,
          elevationProfile: ride.elevationProfile,
          startLat: ride.startLat,
          startLng: ride.startLng,
          organizerId: ride.organizerId,
          routeLatLngs: ride.routeLatLngs,
        );
      }
    }

    notifyListeners();
    if (BackendSyncService.isAvailable) {
      unawaited(BackendSyncService.setRsvp(rideId: rideId, status: status));
    }
  }

  void toggleTheme() {
    themeMode = switch (themeMode) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    notifyListeners();
  }

  Future<AuthResult> loginWithPassword({
    required String email,
    required String password,
  }) async {
    if (!usesBackendAuth) {
      login(email: email, notify: false);
      await _restoreSessionProfile();
      notifyListeners();
      return AuthResult.ok();
    }

    final result = await AuthService.signIn(email: email, password: password);
    if (result.success) {
      _applySupabaseUser(AuthService.currentUser, notify: false);
      await _restoreSessionProfile();
      notifyListeners();
    }
    return result;
  }

  void login({String? email, String? name, bool notify = true}) {
    isAuthenticated = true;
    if (email != null || name != null) {
      profile = profile.copyWith(
        email: email?.trim().toLowerCase() ?? profile.email,
        name: name ?? profile.name,
      );
    }
    if (notify) notifyListeners();
  }

  Future<AuthResult> registerAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!usesBackendAuth) {
      await register(name: name, email: email);
      return AuthResult.ok();
    }

    final result = await AuthService.signUp(
      name: name,
      email: email,
      password: password,
    );
    if (result.success) {
      _applySupabaseUser(AuthService.currentUser, notify: false);
      onboardingComplete = false;
      await LocalProfileStore.clear(
        userId: AuthService.currentUser?.id,
        email: email,
      );
      notifyListeners();
    }
    return result;
  }

  Future<void> register({required String name, required String email}) async {
    profile = profile.copyWith(name: name, email: email);
    isAuthenticated = true;
    onboardingComplete = false;
    await LocalProfileStore.clear(userId: profile.id, email: email);
    notifyListeners();
  }

  Future<void> logout() async {
    if (usesBackendAuth) {
      await AuthService.signOut();
    }
    isAuthenticated = false;
    onboardingComplete = false;
    profile = demoProfile;
    rsvps.clear();
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    if (draftTerrains.isEmpty) {
      draftTerrains.addAll({TerrainPref.flat, TerrainPref.climbs});
    }
    profile = profile.copyWith(
      email: profile.email.trim().toLowerCase(),
      bikeTypes: draftBikes.toList(),
      fitnessLevel: draftFitness,
      preferredDays: draftDays.toList(),
      preferredDistanceMin: draftDistance.start,
      preferredDistanceMax: draftDistance.end,
      preferredElevationMin: draftElevation.start.round(),
      preferredElevationMax: draftElevation.end.round(),
      preferredTerrains: draftTerrains.toList(),
    );
    onboardingComplete = true;
    await _persistProfilePrefs();
    notifyListeners();
  }

  void toggleDraftBike(BikeType type) {
    if (draftBikes.contains(type)) {
      draftBikes.remove(type);
    } else {
      draftBikes.add(type);
    }
    notifyListeners();
  }

  void setDraftFitness(FitnessLevel level) {
    draftFitness = level;
    notifyListeners();
  }

  void toggleDraftDay(String day) {
    if (draftDays.contains(day)) {
      draftDays.remove(day);
    } else {
      draftDays.add(day);
    }
    notifyListeners();
  }

  void setDraftDistance(RangeValues values) {
    draftDistance = RangeValues(
      values.start.clamp(10, 250),
      values.end.clamp(10, 250),
    );
    notifyListeners();
  }

  void setDraftElevation(RangeValues values) {
    draftElevation = RangeValues(
      values.start.clamp(0, 6000),
      values.end.clamp(0, 6000),
    );
    notifyListeners();
  }

  void toggleDraftTerrain(TerrainPref terrain) {
    if (draftTerrains.contains(terrain)) {
      if (draftTerrains.length > 1) draftTerrains.remove(terrain);
    } else {
      draftTerrains.add(terrain);
    }
    notifyListeners();
  }

  void toggleGroupMembership(String groupId) {
    final joining = !joinedGroupIds.contains(groupId);
    if (joining) {
      joinedGroupIds.add(groupId);
    } else {
      joinedGroupIds.remove(groupId);
    }
    final group = groupById(groupId);
    if (group != null) {
      group.memberCount = (group.memberCount + (joining ? 1 : -1)).clamp(0, 99999);
    }
    notifyListeners();
    if (BackendSyncService.isAvailable) {
      unawaited(
        BackendSyncService.setMembership(groupId: groupId, join: joining),
      );
    }
  }

  bool isMemberOf(String groupId) => joinedGroupIds.contains(groupId);

  Future<CyclingGroup> createGroup({
    required String name,
    required String description,
    required String location,
    required bool isPrivate,
  }) async {
    if (BackendSyncService.isAvailable) {
      final group = await BackendSyncService.createGroup(
        name: name,
        description: description,
        location: location,
        isPrivate: isPrivate,
      );
      _groups.insert(0, group);
      joinedGroupIds.add(group.id);
      notifyListeners();
      return group;
    }

    final id = 'g-${DateTime.now().millisecondsSinceEpoch}';
    final group = CyclingGroup(
      id: id,
      name: name,
      description: description,
      memberCount: 1,
      isPrivate: isPrivate,
      location: location,
      upcomingRideIds: [],
      coverGradient: const [Color(0xFF1A7A4C), Color(0xFF0F4D32)],
    );
    _groups.insert(0, group);
    joinedGroupIds.add(id);
    notifyListeners();
    return group;
  }

  Future<Ride> createRide({
    required String title,
    required String description,
    required DateTime startsAt,
    required String meetingPoint,
    required BikeType bikeType,
    required double distanceKm,
    required int elevationM,
    required int riderLimit,
    required Difficulty difficulty,
    required FitnessLevel skillLevel,
    String? groupId,
    double? startLat,
    double? startLng,
    List<double>? elevationProfile,
    List<double> routeLatLngs = const [],
  }) async {
    final resolvedGroupId = (groupId == null || groupId.isEmpty) ? '' : groupId;
    final group =
        resolvedGroupId.isEmpty ? null : groupById(resolvedGroupId);
    final profileElev = elevationProfile ?? _syntheticProfile(elevationM);
    final lat = startLat ?? 46.4983;
    final lng = startLng ?? 11.3548;
    final gradient = group?.coverGradient ??
        const [Color(0xFF1A7A4C), Color(0xFF0B3D28)];
    final groupName = group?.name ?? 'Open ride';

    late final Ride ride;
    if (BackendSyncService.isAvailable) {
      ride = await BackendSyncService.createRide(
        title: title,
        description: description,
        startsAt: startsAt,
        meetingPoint: meetingPoint,
        bikeType: bikeType,
        distanceKm: distanceKm,
        elevationM: elevationM,
        riderLimit: riderLimit,
        difficulty: difficulty,
        skillLevel: skillLevel,
        groupId: resolvedGroupId.isEmpty ? null : resolvedGroupId,
        groupName: groupName,
        coverGradient: gradient,
        elevationProfile: profileElev,
        startLat: lat,
        startLng: lng,
        routeLatLngs: routeLatLngs,
      );
    } else {
      final id = 'ride-${DateTime.now().millisecondsSinceEpoch}';
      ride = Ride(
        id: id,
        title: title,
        description: description,
        startsAt: startsAt,
        meetingPoint: meetingPoint,
        bikeType: bikeType,
        distanceKm: distanceKm,
        elevationM: elevationM,
        participants: 1,
        riderLimit: riderLimit,
        difficulty: difficulty,
        skillLevel: skillLevel,
        groupId: resolvedGroupId,
        groupName: groupName,
        organizerId: currentUserId,
        coverGradient: gradient,
        elevationProfile: profileElev,
        startLat: lat,
        startLng: lng,
        routeLatLngs: routeLatLngs,
      );
    }

    _rides.insert(0, ride);
    group?.upcomingRideIds.insert(0, ride.id);
    rsvps[ride.id] = RsvpStatus.joined;
    _rideParticipantIds[ride.id] = [currentUserId];
    profile = profile.copyWith(ridesOrganized: profile.ridesOrganized + 1);
    if (group != null && !joinedGroupIds.contains(resolvedGroupId)) {
      joinedGroupIds.add(resolvedGroupId);
    }
    notifyListeners();
    return ride;
  }

  List<double> _syntheticProfile(int elevationM) {
    final base = (elevationM * 0.2).clamp(50, 800).toDouble();
    final peak = elevationM.toDouble().clamp(100, 3000).toDouble();
    return <double>[
      base,
      base + (peak - base) * 0.35,
      peak * 0.85,
      peak,
      peak * 0.7,
      base + (peak - base) * 0.4,
      base,
    ];
  }

  void setBikePhoto(Uint8List? bytes) {
    profile = bytes == null
        ? profile.copyWith(clearBikePhoto: true)
        : profile.copyWith(bikePhotoBytes: bytes);
    notifyListeners();
  }

  List<RidePhoto> get ridePhotos => List.unmodifiable(_ridePhotos);

  List<RidePhoto> photosForRide(String rideId) {
    final list =
        _ridePhotos.where((p) => p.rideId == rideId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<RidePhoto> photosForUser(String userId) {
    final list =
        _ridePhotos.where((p) => p.uploaderId == userId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Whether the current user can attach memories to this ride.
  bool canAddPhotosToRide(String rideId) {
    final ride = rideById(rideId);
    if (ride == null || !ride.isPast) return false;
    return hasJoinedRsvp(rideId) || isOrganizerOf(rideId);
  }

  void addRidePhotos({
    required String rideId,
    required List<Uint8List> images,
    String? caption,
  }) {
    if (images.isEmpty || !canAddPhotosToRide(rideId)) return;
    final now = DateTime.now();
    for (var i = 0; i < images.length; i++) {
      _ridePhotos.insert(
        0,
        RidePhoto(
          id: 'photo-${now.millisecondsSinceEpoch}-$i',
          rideId: rideId,
          uploaderId: currentUserId,
          createdAt: now.add(Duration(milliseconds: i)),
          caption: i == 0 ? caption : null,
          bytes: images[i],
        ),
      );
    }
    notifyListeners();
  }

  void removeRidePhoto(String photoId) {
    _ridePhotos.removeWhere(
      (p) => p.id == photoId && p.uploaderId == currentUserId,
    );
    notifyListeners();
  }

  /// Chronological messages for a group chat (oldest first).
  List<GroupMessage> messagesForGroup(String groupId) {
    final list =
        _groupMessages.where((m) => m.groupId == groupId).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  GroupMessage? latestMessageForGroup(String groupId) {
    final messages = messagesForGroup(groupId);
    if (messages.isEmpty) return null;
    return messages.last;
  }

  /// Members can post to the group thread.
  GroupMessage? sendGroupMessage(String groupId, String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty || !isMemberOf(groupId) || groupById(groupId) == null) {
      return null;
    }
    final message = GroupMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      groupId: groupId,
      senderId: currentUserId,
      body: trimmed,
      createdAt: DateTime.now(),
    );
    _groupMessages.add(message);
    notifyListeners();
    return message;
  }

  List<Ride> filteredRides({
    BikeType? bikeType,
    Difficulty? difficulty,
    DateTime? day,
    DateTime? month,
    bool includePast = false,
  }) {
    return _rides.where((ride) {
      if (!includePast && ride.isPast) return false;
      if (bikeType != null && ride.bikeType != bikeType) return false;
      if (difficulty != null && ride.difficulty != difficulty) return false;
      if (day != null) {
        final sameDay = ride.startsAt.year == day.year &&
            ride.startsAt.month == day.month &&
            ride.startsAt.day == day.day;
        if (!sameDay) return false;
      }
      if (month != null) {
        if (ride.startsAt.year != month.year ||
            ride.startsAt.month != month.month) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final aMine = joinedGroupIds.contains(a.groupId);
        final bMine = joinedGroupIds.contains(b.groupId);
        if (aMine != bMine) return aMine ? -1 : 1;
        return a.startsAt.compareTo(b.startsAt);
      });
  }

  List<Ride> ridesOnDay(DateTime day) {
    return filteredRides(day: day, includePast: true);
  }

  /// Past rides you joined (completed).
  List<Ride> get completedRides {
    final list = _rides
        .where((r) => r.isPast && hasJoinedRsvp(r.id))
        .toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return list;
  }

  /// Rides you offered / organized.
  List<Ride> get offeredRides {
    final list = _rides
        .where((r) => r.organizerId == currentUserId)
        .toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return list;
  }

  /// Upcoming rides you've confirmed.
  List<Ride> get upcomingJoinedRides {
    final list = _rides
        .where((r) => !r.isPast && hasJoinedRsvp(r.id))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return list;
  }

  double get lifetimeJoinedKm =>
      completedRides.fold(0.0, (sum, r) => sum + r.distanceKm);

  int get lifetimeJoinedElevationM =>
      completedRides.fold(0, (sum, r) => sum + r.elevationM);

  List<Ride> _sharedPastRidesWith(String riderId) {
    return completedRides.where((ride) {
      final others = _rideParticipantIds[ride.id] ?? const <String>[];
      return others.contains(riderId) || ride.organizerId == riderId;
    }).toList();
  }

  List<CompanionStats> get companionStats {
    final byRider = <String, CompanionStats>{};

    for (final ride in completedRides) {
      final ids = <String>{
        ...(_rideParticipantIds[ride.id] ?? const <String>[]),
        if (ride.organizerId != null) ride.organizerId!,
      }..remove(currentUserId);

      final isMorning = ride.startsAt.hour < 8;
      final isWeekend = ride.startsAt.weekday == DateTime.saturday ||
          ride.startsAt.weekday == DateTime.sunday;
      final isHard = ride.difficulty == Difficulty.challenging ||
          ride.difficulty == Difficulty.expert;

      for (final id in ids) {
        final rider = riderById(id);
        if (rider == null) continue;
        final existing = byRider[id];
        if (existing == null) {
          byRider[id] = CompanionStats(
            rider: rider,
            sharedRides: 1,
            sharedKm: ride.distanceKm,
            sharedElevationM: ride.elevationM,
            longestRideKm: ride.distanceKm,
            biggestClimbM: ride.elevationM,
            morningRides: isMorning ? 1 : 0,
            weekendRides: isWeekend ? 1 : 0,
            hardRides: isHard ? 1 : 0,
          );
        } else {
          byRider[id] = CompanionStats(
            rider: rider,
            sharedRides: existing.sharedRides + 1,
            sharedKm: existing.sharedKm + ride.distanceKm,
            sharedElevationM: existing.sharedElevationM + ride.elevationM,
            longestRideKm: ride.distanceKm > existing.longestRideKm
                ? ride.distanceKm
                : existing.longestRideKm,
            biggestClimbM: ride.elevationM > existing.biggestClimbM
                ? ride.elevationM
                : existing.biggestClimbM,
            morningRides: existing.morningRides + (isMorning ? 1 : 0),
            weekendRides: existing.weekendRides + (isWeekend ? 1 : 0),
            hardRides: existing.hardRides + (isHard ? 1 : 0),
          );
        }
      }
    }

    return byRider.values.toList();
  }

  List<CompanionStats> companionsRankedBy(CompanionRankMetric metric) {
    final list = List<CompanionStats>.from(companionStats);
    int valueOf(CompanionStats c) => switch (metric) {
          CompanionRankMetric.sharedKm => c.sharedKm.round(),
          CompanionRankMetric.sharedElevation => c.sharedElevationM,
          CompanionRankMetric.sharedRides => c.sharedRides,
          CompanionRankMetric.longestRide => c.longestRideKm.round(),
          CompanionRankMetric.biggestClimb => c.biggestClimbM,
          CompanionRankMetric.earlyBird => c.morningRides,
          CompanionRankMetric.weekendWarrior => c.weekendRides,
          CompanionRankMetric.climbDuo => c.hardRides,
        };

    list.removeWhere((c) => valueOf(c) <= 0);
    list.sort((a, b) {
      final cmp = valueOf(b).compareTo(valueOf(a));
      if (cmp != 0) return cmp;
      return a.rider.name.compareTo(b.rider.name);
    });
    return list;
  }

  String companionMetricLabel(CompanionStats stats, CompanionRankMetric metric) {
    return switch (metric) {
      CompanionRankMetric.sharedKm => '${stats.sharedKm.round()} km',
      CompanionRankMetric.sharedElevation => '${stats.sharedElevationM} m',
      CompanionRankMetric.sharedRides => '${stats.sharedRides} rides',
      CompanionRankMetric.longestRide => '${stats.longestRideKm.round()} km',
      CompanionRankMetric.biggestClimb => '${stats.biggestClimbM} m',
      CompanionRankMetric.earlyBird => '${stats.morningRides} early starts',
      CompanionRankMetric.weekendWarrior => '${stats.weekendRides} weekends',
      CompanionRankMetric.climbDuo => '${stats.hardRides} hard days',
    };
  }

  /// Shared past rides with a companion (for rider profile).
  List<Ride> sharedPastRidesWith(String riderId) => _sharedPastRidesWith(riderId);
}
