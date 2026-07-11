import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/data/models/game_model.dart';
import 'package:epic_app/data/repositories/game_repository.dart';

/// Grid menu game — menampilkan daftar game dari Firestore.
class GameMenuGrid extends StatefulWidget {
  const GameMenuGrid({super.key});

  @override
  State<GameMenuGrid> createState() => _GameMenuGridState();
}

class _GameMenuGridState extends State<GameMenuGrid> {
  final GameRepository _gameRepo = GameRepository();
  List<GameModel> _games = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    try {
      final games = await _gameRepo.getGames();
      if (mounted) {
        setState(() {
          _games = games;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_games.isEmpty) {
      return Center(
        child: Text(
          'Game belum tersedia',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            color: Colors.grey.shade400,
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _games.length,
      itemBuilder: (context, index) {
        final game = _games[index];
        return _buildGameCard(game);
      },
    );
  }

  Widget _buildGameCard(GameModel game) {
    return GestureDetector(
      onTap: () {
        if (game.isLocked) {
          Get.snackbar('Terkunci', 'Game ini belum tersedia.');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: game.isLocked
              ? const Color(0xFFE2E8F0)
              : AppColors.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videogame_asset_rounded,
              color: game.isLocked ? Colors.grey : Colors.white,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              game.nama,
              style: TextStyle(
                fontFamily: 'FredokaOne',
                fontSize: 16,
                color: game.isLocked ? Colors.grey : Colors.white,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              game.deskripsi,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: game.isLocked
                    ? Colors.grey.shade400
                    : Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
