import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';

Future<List<Uint8List>> pickRidePhotoBytes({
  ImageSource source = ImageSource.gallery,
  bool multi = true,
}) async {
  final picker = ImagePicker();
  if (multi && source == ImageSource.gallery) {
    final files = await picker.pickMultiImage(
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (files.isEmpty) return const [];
    final out = <Uint8List>[];
    for (final file in files.take(8)) {
      out.add(await file.readAsBytes());
    }
    return out;
  }

  final file = await picker.pickImage(
    source: source,
    maxWidth: 1600,
    imageQuality: 85,
  );
  if (file == null) return const [];
  return [await file.readAsBytes()];
}

Future<void> showAddRidePhotosSheet(
  BuildContext context, {
  required String rideId,
}) async {
  final state = context.read<AppState>();
  if (!state.canAddPhotosToRide(rideId)) return;

  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              subtitle: const Text('Pick one or more photos'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
  if (source == null || !context.mounted) return;

  final images = await pickRidePhotoBytes(
    source: source,
    multi: source == ImageSource.gallery,
  );
  if (images.isEmpty || !context.mounted) return;

  state.addRidePhotos(rideId: rideId, images: images);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        images.length == 1
            ? 'Memory added'
            : '${images.length} memories added',
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Instagram-style square grid of ride memories.
class RideMemoriesGrid extends StatelessWidget {
  const RideMemoriesGrid({
    super.key,
    required this.photos,
    this.emptyTitle = 'No memories yet',
    this.emptySubtitle = 'Add photos after a ride to fill your feed.',
    this.onAddTap,
    this.padding = EdgeInsets.zero,
    this.shrinkWrap = true,
  });

  final List<RidePhoto> photos;
  final String emptyTitle;
  final String emptySubtitle;
  final VoidCallback? onAddTap;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Padding(
        padding: padding,
        child: _EmptyMemories(
          title: emptyTitle,
          subtitle: emptySubtitle,
          onAddTap: onAddTap,
        ),
      );
    }

    return Padding(
      padding: padding,
      child: GridView.builder(
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        itemCount: photos.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemBuilder: (context, index) {
          final photo = photos[index];
          return RideMemoryThumb(
            photo: photo,
            onTap: () => openRideMemoryViewer(
              context,
              photos: photos,
              initialIndex: index,
            ),
          );
        },
      ),
    );
  }
}

class RideMemoryThumb extends StatelessWidget {
  const RideMemoryThumb({
    super.key,
    required this.photo,
    this.onTap,
    this.borderRadius = 0,
  });

  final RidePhoto photo;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: RideMemoryImage(photo: photo),
        ),
      ),
    );
  }
}

class RideMemoryImage extends StatelessWidget {
  const RideMemoryImage({
    super.key,
    required this.photo,
    this.fit = BoxFit.cover,
  });

  final RidePhoto photo;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (photo.hasBytes) {
      return Image.memory(
        photo.bytes!,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
      );
    }

    final colors = photo.moodGradient ??
        const [AppColors.forest, AppColors.forestDeep];
    final state = context.read<AppState>();
    final ride = state.rideById(photo.rideId);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _MemoryGrainPainter()),
          Center(
            child: Icon(
              ride?.bikeType.icon ?? Icons.directions_bike,
              color: Colors.white.withValues(alpha: 0.55),
              size: 36,
            ),
          ),
          if (ride != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                ride.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  shadows: [
                    Shadow(blurRadius: 6, color: Colors.black54),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal strip of memories for ride detail.
class RideMemoriesStrip extends StatelessWidget {
  const RideMemoriesStrip({
    super.key,
    required this.photos,
    this.onAddTap,
  });

  final List<RidePhoto> photos;
  final VoidCallback? onAddTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 112,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (onAddTap != null) ...[
            _AddMemoryTile(onTap: onAddTap!),
            const SizedBox(width: 8),
          ],
          for (var i = 0; i < photos.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            SizedBox(
              width: 112,
              height: 112,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: RideMemoryThumb(
                  photo: photos[i],
                  borderRadius: 14,
                  onTap: () => openRideMemoryViewer(
                    context,
                    photos: photos,
                    initialIndex: i,
                  ),
                ),
              ),
            ),
          ],
          if (photos.isEmpty && onAddTap == null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No photos yet',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _AddMemoryTile extends StatelessWidget {
  const _AddMemoryTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.forest.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_a_photo_outlined,
                color: AppColors.forest,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                'Add',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.forest,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMemories extends StatelessWidget {
  const _EmptyMemories({
    required this.title,
    required this.subtitle,
    this.onAddTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onAddTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        children: [
          Icon(
            Icons.photo_camera_back_outlined,
            size: 40,
            color: AppColors.forest.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          if (onAddTap != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onAddTap,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add photos'),
            ),
          ],
        ],
      ),
    );
  }
}

void openRideMemoryViewer(
  BuildContext context, {
  required List<RidePhoto> photos,
  required int initialIndex,
}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => RideMemoryViewer(
        photos: photos,
        initialIndex: initialIndex,
      ),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class RideMemoryViewer extends StatefulWidget {
  const RideMemoryViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  final List<RidePhoto> photos;
  final int initialIndex;

  @override
  State<RideMemoryViewer> createState() => _RideMemoryViewerState();
}

class _RideMemoryViewerState extends State<RideMemoryViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.photos.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final photo = widget.photos[_index];
    final ride = state.rideById(photo.rideId);
    final uploader = state.riderById(photo.uploaderId);
    final isOwn = photo.uploaderId == state.currentUserId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 3,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: RideMemoryImage(photo: widget.photos[i]),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 4,
              left: 4,
              right: 4,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      '${_index + 1} / ${widget.photos.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isOwn)
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: () {
                        state.removeRidePhoto(photo.id);
                        Navigator.pop(context);
                      },
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white70,
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (photo.caption != null && photo.caption!.isNotEmpty)
                      Text(
                        photo.caption!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (photo.caption != null && photo.caption!.isNotEmpty)
                      const SizedBox(height: 8),
                    Text(
                      [
                        if (uploader != null) uploader.name,
                        DateFormat('MMM d, yyyy').format(photo.createdAt),
                      ].join(' · '),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (ride != null) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/home/ride/${ride.id}');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                ride.bikeType.icon,
                                size: 16,
                                color: AppColors.lime,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  ride.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: Colors.white54,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 14) {
      canvas.drawLine(Offset(x, 0), Offset(x + 8, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
