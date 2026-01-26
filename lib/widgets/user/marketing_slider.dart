import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart'; // Make sure this package is added
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/marketing_banner_model.dart';
import '../../services/firestore_service.dart';
import '../../app/theme.dart';

class MarketingSlider extends StatefulWidget {
  const MarketingSlider({super.key});

  @override
  State<MarketingSlider> createState() => _MarketingSliderState();
}

class _MarketingSliderState extends State<MarketingSlider> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return StreamBuilder<List<MarketingBannerModel>>(
      stream: firestoreService.getMarketingBanners(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmer();
        }

        if (snapshot.hasError) {
          // If network error, we'll fall through to empty banners -> fallback
          print('Marketing Banner Error: ${snapshot.error}');
        }

        var banners = snapshot.data ?? [];
        if (banners.isEmpty) {
          // Fallback banner if none exist in DB
          banners = [
            MarketingBannerModel(
              id: 'default',
              imageUrl:
                  '', // Empty indicates we should render a local gradient fallback
              title: 'Welcome to Vignesh Agencies',
              isActive: true,
              createdAt: DateTime.now(),
              priority: 999,
            ),
          ];
        }

        return Column(
          children: [
            CarouselSlider(
              options: CarouselOptions(
                height: 180.0,
                autoPlay: true,
                autoPlayInterval: const Duration(seconds: 5),
                enlargeCenterPage: true,
                viewportFraction: 0.92,
                aspectRatio: 16 / 9,
                onPageChanged: (index, reason) {
                  setState(() => _currentIndex = index);
                },
              ),
              items:
                  banners.map((banner) {
                    return Builder(
                      builder: (BuildContext context) {
                        return GestureDetector(
                          onTap: () {
                            if (banner.targetRoute != null &&
                                banner.targetRoute!.isNotEmpty) {
                              context.push(banner.targetRoute!);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child:
                                  banner.imageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                        imageUrl: banner.imageUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        placeholder:
                                            (context, url) => _buildShimmer(),
                                        errorWidget:
                                            (context, url, error) =>
                                                _buildDefaultGradientBanner(
                                                  banner,
                                                ),
                                      )
                                      : _buildDefaultGradientBanner(banner),
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children:
                  banners.asMap().entries.map((entry) {
                    return Container(
                      width: _currentIndex == entry.key ? 24.0 : 8.0,
                      height: 8.0,
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color:
                            _currentIndex == entry.key
                                ? AppTheme.primary
                                : AppTheme.primary.withOpacity(0.2),
                      ),
                    );
                  }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDefaultGradientBanner(MarketingBannerModel banner) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.6)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.stars,
              size: 100,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Welcome',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  banner.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your trusted service partner',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
