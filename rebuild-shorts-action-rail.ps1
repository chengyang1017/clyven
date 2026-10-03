$ErrorActionPreference = "Stop"

$path = "apps/clyven_app/lib/features/home/presentation/pages/discover_page.dart"

if (-not (Test-Path $path)) {
    throw "File not found: $path"
}

$content = Get-Content -Raw -Encoding UTF8 $path

$startMarker = "class _ActionRail"
$endMarker = "class _Avatar"

$start = $content.IndexOf($startMarker)
$end = $content.IndexOf($endMarker)

if ($start -lt 0) {
    throw "Could not find: $startMarker"
}

if ($end -lt 0 -or $end -le $start) {
    throw "Could not find valid end marker: $endMarker"
}

$replacement = @'
class _ActionRail extends StatelessWidget {
  final String videoId;
  final int initialLikeCount;
  final int initialFavoriteCount;
  final int commentCount;
  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final VoidCallback onComments;
  final VoidCallback onShare;

  const _ActionRail({
    required this.videoId,
    required this.initialLikeCount,
    required this.initialFavoriteCount,
    required this.commentCount,
    required this.onLike,
    required this.onFavorite,
    required this.onComments,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LikeAction(
          videoId: videoId,
          fallbackCount: initialLikeCount,
          onTap: onLike,
        ),
        const SizedBox(height: 17),
        _StaticAction(
          icon: Icons.mode_comment_outlined,
          count: commentCount,
          onTap: onComments,
        ),
        const SizedBox(height: 17),
        _FavoriteAction(
          videoId: videoId,
          fallbackCount: initialFavoriteCount,
          onTap: onFavorite,
        ),
        const SizedBox(height: 17),
        _StaticAction(
          icon: Icons.ios_share_rounded,
          onTap: onShare,
        ),
      ],
    );
  }
}

class _LikeAction extends ConsumerWidget {
  final String videoId;
  final int fallbackCount;
  final VoidCallback onTap;

  const _LikeAction({
    required this.videoId,
    required this.fallbackCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiked = ref.watch(
      videoInteractionProvider(videoId).select(
        (state) => state.unwrapPrevious().value?.isLiked ?? false,
      ),
    );
    final count = ref.watch(
      videoInteractionProvider(videoId).select(
        (state) => state.unwrapPrevious().value?.likeCount ?? fallbackCount,
      ),
    );
    final busy = ref.watch(
      videoInteractionProvider(videoId).select(
        (state) => state.unwrapPrevious().value?.isChangingLike ?? false,
      ),
    );

    return RepaintBoundary(
      child: _ActionButton(
        icon: isLiked
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        iconColor: isLiked ? Colors.red : Colors.white,
        countText: _formatActionCount(context, count),
        onTap: busy ? null : onTap,
      ),
    );
  }
}

class _FavoriteAction extends ConsumerWidget {
  final String videoId;
  final int fallbackCount;
  final VoidCallback onTap;

  const _FavoriteAction({
    required this.videoId,
    required this.fallbackCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorited = ref.watch(
      videoInteractionProvider(videoId).select(
        (state) => state.unwrapPrevious().value?.isFavorited ?? false,
      ),
    );
    final count = ref.watch(
      videoInteractionProvider(videoId).select(
        (state) => state.unwrapPrevious().value?.favoriteCount ?? fallbackCount,
      ),
    );
    final busy = ref.watch(
      videoInteractionProvider(videoId).select(
        (state) => state.unwrapPrevious().value?.isChangingFavorite ?? false,
      ),
    );

    return RepaintBoundary(
      child: _ActionButton(
        icon: isFavorited
            ? Icons.bookmark_rounded
            : Icons.bookmark_border_rounded,
        countText: _formatActionCount(context, count),
        onTap: busy ? null : onTap,
      ),
    );
  }
}

class _StaticAction extends StatelessWidget {
  final IconData icon;
  final int? count;
  final VoidCallback onTap;

  const _StaticAction({
    required this.icon,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _ActionButton(
        icon: icon,
        countText: count == null ? null : _formatActionCount(context, count!),
        onTap: onTap,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String? countText;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    this.iconColor = Colors.white,
    this.countText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 54,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0x5C000000),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 28,
              ),
            ),
            if (countText != null) ...[
              const SizedBox(height: 4),
              RepaintBoundary(
                child: Text(
                  countText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    shadows: <Shadow>[],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatActionCount(BuildContext context, int value) {
  return NumberFormat.compact(
    locale: Localizations.localeOf(context).toString(),
  ).format(value);
}

'@

$before = $content.Substring(0, $start)
$after = $content.Substring($end)

$backupDir = ".clyven-patch-backup"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = Join-Path $backupDir "discover_page-$timestamp.dart"
Copy-Item $path $backupPath

$newContent = $before + $replacement + $after
Set-Content -Path $path -Value $newContent -Encoding UTF8

Write-Host "Rebuilt shorts action rail."
Write-Host "Backup: $backupPath"
Write-Host ""
Write-Host "Formatting..."
dart format $path

Write-Host ""
Write-Host "Done. Run: flutter analyze"
