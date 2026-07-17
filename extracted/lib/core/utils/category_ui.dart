import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../features/navigation/domain/entities/place.dart';

/// نگاشت دسته‌ی مکان به آیکون و رنگ (مطابق تصاویر جستجو و علاقه‌مندی‌ها).
class CategoryUi {
  CategoryUi._();

  static IconData icon(PlaceCategory c) {
    switch (c) {
      case PlaceCategory.home:
        return Icons.home_rounded;
      case PlaceCategory.work:
        return Icons.work_rounded;
      case PlaceCategory.restaurant:
        return Icons.restaurant_rounded;
      case PlaceCategory.cafe:
        return Icons.local_cafe_rounded;
      case PlaceCategory.shopping:
        return Icons.shopping_bag_rounded;
      case PlaceCategory.hotel:
        return Icons.hotel_rounded;
      case PlaceCategory.park:
        return Icons.park_rounded;
      case PlaceCategory.fuel:
        return Icons.local_gas_station_rounded;
      case PlaceCategory.parking:
        return Icons.local_parking_rounded;
      case PlaceCategory.hospital:
        return Icons.local_hospital_rounded;
      case PlaceCategory.pharmacy:
        return Icons.local_pharmacy_rounded;
      case PlaceCategory.bank:
        return Icons.account_balance_rounded;
      case PlaceCategory.evCharge:
        return Icons.ev_station_rounded;
      case PlaceCategory.family:
        return Icons.groups_rounded;
      case PlaceCategory.friends:
        return Icons.people_rounded;
      case PlaceCategory.travel:
        return Icons.card_travel_rounded;
      case PlaceCategory.other:
        return Icons.star_rounded;
    }
  }

  static Color color(PlaceCategory c) {
    switch (c) {
      case PlaceCategory.restaurant:
        return AppColors.poiRestaurant;
      case PlaceCategory.cafe:
        return AppColors.poiCafe;
      case PlaceCategory.shopping:
        return AppColors.poiShopping;
      case PlaceCategory.hotel:
        return AppColors.poiHotel;
      case PlaceCategory.park:
        return AppColors.poiPark;
      case PlaceCategory.fuel:
        return AppColors.poiFuel;
      case PlaceCategory.parking:
        return AppColors.poiParking;
      case PlaceCategory.family:
      case PlaceCategory.friends:
        return AppColors.poiFamily;
      default:
        return AppColors.primary;
    }
  }
}
