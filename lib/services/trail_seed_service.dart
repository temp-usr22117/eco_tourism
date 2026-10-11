import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class TrailSeedService {
  TrailSeedService._();

  /// Curated list of iconic Indian treks across Himalayas, Western Ghats, and Eastern Himalayas.
  static final List<Map<String, dynamic>> curatedTrails = [
    {
      'id': 'triund_trek',
      'name': 'Triund Trek',
      'lat': 32.2598,
      'lng': 76.3526,
      'baseStatus': 'EASY',
      'checkInCount': 0,
      'trailBg':
          'https://images.unsplash.com/photo-1589182373726-e4f658ab50f0?auto=format&fit=crop&w=1200&q=80',
      'aboutTrail':
          'Triund is the crown jewel of Dharamshala, perched at 2,828m in the Dhauladhar Range. A scenic day trek offering spectacular views of the Kangra Valley and snow-draped granite peaks.',
      'emergency': {
        'police': '112',
        'ambulance': '108',
        'rescue': '1070',
        'local_contact': '+91-1892-224928',
      },
      'safetyTips': [
        {
          'title': 'Night Temperature Drops',
          'description':
              'Temperatures on the ridge drop sharply after sunset. Always carry warm fleece layers and a windproof jacket.',
          'type': 'SPECIFIC',
          'icon': 'ac_unit',
        },
        {
          'title': 'Carry Sufficient Water',
          'description':
              'Natural water sources are scarce along the ridge. Carry at least 2 liters of drinking water before ascending.',
          'type': 'COMMON',
          'icon': 'water',
        },
      ],
    },
    {
      'id': 'kedarkantha_trek',
      'name': 'Kedarkantha Trek',
      'lat': 31.0225,
      'lng': 78.1728,
      'baseStatus': 'MODERATE',
      'checkInCount': 0,
      'trailBg':
          'https://images.unsplash.com/photo-1605649487212-47bdab064df7?auto=format&fit=crop&w=1200&q=80',
      'aboutTrail':
          'Standing tall at 3,800m inside Govind Pashu Vihar National Park, Kedarkantha is one of India’s most beloved summit treks featuring dense pine forests, frozen lakes, and 360-degree Himalayan views.',
      'emergency': {
        'police': '112',
        'ambulance': '108',
        'rescue': '1070',
        'local_contact': '+91-1375-222137',
      },
      'safetyTips': [
        {
          'title': 'Microspikes & Gaiters for Snow',
          'description':
              'Summit ridge can be covered in hard ice. Microspikes and trekking poles are mandatory during winter climbs.',
          'type': 'SPECIFIC',
          'icon': 'terrain',
        },
        {
          'title': 'Acute Mountain Sickness (AMS)',
          'description':
              'Summit altitude is 3,800m. Drink plenty of water and acclimatize properly at Juda Ka Talab base camp.',
          'type': 'SPECIFIC',
          'icon': 'medical_services',
        },
      ],
    },
    {
      'id': 'hampta_pass',
      'name': 'Hampta Pass Trek',
      'lat': 32.2700,
      'lng': 77.3680,
      'baseStatus': 'MODERATE',
      'checkInCount': 0,
      'trailBg':
          'https://images.unsplash.com/photo-1544735716-392fe2489ffa?auto=format&fit=crop&w=1200&q=80',
      'aboutTrail':
          'A dramatic crossover trek connecting the lush green Kullu Valley with the barren, rugged terrain of Lahaul & Spiti. Ascends to 4,287m with views of Mount Indrasan and Deo Tibba.',
      'emergency': {
        'police': '112',
        'ambulance': '108',
        'rescue': '1070',
        'local_contact': '+91-1902-252720',
      },
      'safetyTips': [
        {
          'title': 'Cold River Crossings',
          'description':
              'Glacial river crossings require rope assistance and quick-dry shoes. Cross during early morning hours.',
          'type': 'SPECIFIC',
          'icon': 'water',
        },
        {
          'title': 'Rapid Weather Swings',
          'description':
              'Weather at the pass summit changes swiftly from sun to intense hail. Always track morning forecasts.',
          'type': 'COMMON',
          'icon': 'cloud',
        },
      ],
    },
    {
      'id': 'valley_of_flowers',
      'name': 'Valley of Flowers',
      'lat': 30.7280,
      'lng': 79.6053,
      'baseStatus': 'MODERATE',
      'checkInCount': 0,
      'trailBg':
          'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1200&q=80',
      'aboutTrail':
          'A UNESCO World Heritage site in Chamoli, Uttarakhand. Situated at 3,658m, this vibrant alpine valley blossoms with hundreds of endemic flora species against high glaciated cliffs.',
      'emergency': {
        'police': '112',
        'ambulance': '108',
        'rescue': '1070',
        'local_contact': '+91-1372-252144',
      },
      'safetyTips': [
        {
          'title': 'Monsoon Slippery Trails',
          'description':
              'Bloom peaks during monsoon (July-Aug). Carry high-traction waterproof boots and reliable rain gear.',
          'type': 'SPECIFIC',
          'icon': 'water',
        },
        {
          'title': 'Protected Biosphere Zone',
          'description':
              'Camping inside the national park is prohibited. All trekkers must exit to Ghangaria before 5:00 PM.',
          'type': 'COMMON',
          'icon': 'shield',
        },
      ],
    },
    {
      'id': 'kudremukh_trek',
      'name': 'Kudremukh Peak Trek',
      'lat': 13.2173,
      'lng': 75.2589,
      'baseStatus': 'MODERATE',
      'checkInCount': 0,
      'trailBg':
          'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1200&q=80',
      'aboutTrail':
          'Named after the distinct horse-face shape of the peak, Kudremukh (1,894m) is the second highest summit in Karnataka. Famous for rolling green shola grasslands, streams, and rich biodiversity.',
      'emergency': {
        'police': '112',
        'ambulance': '108',
        'rescue': '1070',
        'local_contact': '+91-8263-249455',
      },
      'safetyTips': [
        {
          'title': 'Forest Department Permits',
          'description':
              'Daily permits are capped by the Forest Department. Reach the Kudremukh checkpost early in the morning.',
          'type': 'SPECIFIC',
          'icon': 'shield',
        },
        {
          'title': 'Leech Protection in Monsoons',
          'description':
              'Dense vegetation harbors leeches during monsoons. Carry salt, leech socks, or tobacco powder.',
          'type': 'COMMON',
          'icon': 'backpack',
        },
      ],
    },
    {
      'id': 'har_ki_dun',
      'name': 'Har Ki Dun Trek',
      'lat': 31.1447,
      'lng': 78.4310,
      'baseStatus': 'MODERATE',
      'checkInCount': 0,
      'trailBg':
          'https://images.unsplash.com/photo-1486870591958-9b9d0d1dda99?auto=format&fit=crop&w=1200&q=80',
      'aboutTrail':
          'The "Valley of Gods" is a legendary cradle-shaped hanging valley in the Garhwal Himalayas at 3,566m, framed by Swargarohini peaks and historic wooden village hamlets of Osla and Sankri.',
      'emergency': {
        'police': '112',
        'ambulance': '108',
        'rescue': '1070',
        'local_contact': '+91-1375-222137',
      },
      'safetyTips': [
        {
          'title': 'Zero Network Connectivity',
          'description':
              'There is no mobile signal beyond Sankri. Inform family members of your itinerary before starting.',
          'type': 'SPECIFIC',
          'icon': 'warning',
        },
        {
          'title': 'Long Trail Distance',
          'description':
              'Round trip is over 45km. Pace your daily walks and ensure comfortable, broken-in trekking footwear.',
          'type': 'COMMON',
          'icon': 'hiking',
        },
      ],
    },
    {
      'id': 'sandakphu_trek',
      'name': 'Sandakphu Ridge Trek',
      'lat': 27.1065,
      'lng': 88.0016,
      'baseStatus': 'HARD',
      'checkInCount': 0,
      'trailBg':
          'https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=1200&q=80',
      'aboutTrail':
          'The highest point in West Bengal at 3,636m, located along the Indo-Nepal Singalila Ridge. Renowned worldwide for viewing four of the five tallest mountains on Earth, including Everest and Kanchenjunga.',
      'emergency': {
        'police': '112',
        'ambulance': '108',
        'rescue': '1070',
        'local_contact': '+91-354-2252159',
      },
      'safetyTips': [
        {
          'title': 'Sub-Zero Ridge Winds',
          'description':
              'Night temperatures frequently plunge below -5°C with howling ridge winds. High-grade thermals and down jackets are essential.',
          'type': 'SPECIFIC',
          'icon': 'ac_unit',
        },
        {
          'title': 'Valid Photo ID Mandatory',
          'description':
              'The trail zig-zags along the international Indo-Nepal border. Trekkers must carry original ID proofs.',
          'type': 'COMMON',
          'icon': 'shield',
        },
      ],
    },
    {
      'id': 'chembra_peak',
      'name': 'Chembra Peak Trek',
      'lat': 11.5126,
      'lng': 76.0877,
      'baseStatus': 'EASY',
      'checkInCount': 0,
      'trailBg':
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
      'aboutTrail':
          'Standing at 2,100m, Chembra is the highest summit in Wayanad. Celebrated for its heart-shaped perennial mountain lake (Hridaya Saras) and sprawling tea plantations enveloped in mist.',
      'emergency': {
        'police': '112',
        'ambulance': '108',
        'rescue': '1070',
        'local_contact': '+91-4936-202239',
      },
      'safetyTips': [
        {
          'title': 'Steep Grassland Slopes',
          'description':
              'Upper sections feature slippery grass terrain. Avoid trekking during active thunderstorms.',
          'type': 'SPECIFIC',
          'icon': 'terrain',
        },
        {
          'title': 'Eco-Sensitive Zone Rules',
          'description':
              'Strict zero-plastic policy enforced by the forest department. Discarding any litter attracts severe penalties.',
          'type': 'COMMON',
          'icon': 'shield',
        },
      ],
    },
  ];

  /// Seeds curated trails and corresponding safety tips into Cloud Firestore.
  static Future<int> seedCuratedTrails() async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final now = Timestamp.now();
    int count = 0;

    for (final trail in curatedTrails) {
      final trailId = trail['id'] as String;
      final trailRef = firestore.collection('trails').doc(trailId);

      final trailData = {
        'name': trail['name'],
        'lat': trail['lat'],
        'lng': trail['lng'],
        'baseStatus': trail['baseStatus'],
        'checkInCount': trail['checkInCount'] ?? 0,
        'trailBg': trail['trailBg'],
        'aboutTrail': trail['aboutTrail'],
        'emergency': trail['emergency'],
        'lastUpdated': now,
      };

      batch.set(trailRef, trailData, SetOptions(merge: true));
      count++;

      // Seed safety tips associated with this trail
      final tips = trail['safetyTips'] as List<dynamic>?;
      if (tips != null) {
        for (int i = 0; i < tips.length; i++) {
          final tip = tips[i] as Map<String, dynamic>;
          final tipDocId = '${trailId}_tip_$i';
          final tipRef = firestore.collection('safetyTips').doc(tipDocId);

          batch.set(
            tipRef,
            {
              'trailId': trailId,
              'title': tip['title'],
              'description': tip['description'],
              'type': tip['type'],
              'icon': tip['icon'],
            },
            SetOptions(merge: true),
          );
        }
      }
    }

    await batch.commit();
    debugPrint('[TRAIL SEED] Successfully seeded $count curated trails & safety tips.');
    return count;
  }
}
