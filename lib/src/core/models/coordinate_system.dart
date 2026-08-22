import 'package:flutter/material.dart';

/// Supported Official National and International Coordinate Reference Systems (CRS).
enum CoordinateSystem {
  // --- Bulgaria ---
  bgs2005Cadastral(
    id: 'bgs_2005_cadastral',
    name: 'BGS 2005 (Cadastral / Lambert)',
    country: 'Bulgaria',
    countryFlag: '🇧🇬',
    region: 'Balkans',
    epsg: 'EPSG:7801',
    description: 'Official Bulgarian Cadastral coordinate system (Lambert Conformal Conic 2SP)',
    isDefault: true,
  ),
  bgs2005Utm35n(
    id: 'bgs_2005_utm35n',
    name: 'BGS 2005 / UTM Zone 35N',
    country: 'Bulgaria',
    countryFlag: '🇧🇬',
    region: 'Balkans',
    epsg: 'EPSG:32635',
    description: 'Bulgarian Military & Geodetic UTM Zone 35N projection',
  ),
  cs1970(
    id: 'cs_1970',
    name: 'CS 1970 (Bulgaria Zones K-3, K-5, K-7, K-9)',
    country: 'Bulgaria',
    countryFlag: '🇧🇬',
    region: 'Balkans',
    epsg: 'CS 1970',
    description: 'Historical Bulgarian Geodetic Coordinate System 1970',
  ),

  // --- Romania ---
  romaniaStereo70(
    id: 'romania_stereo70',
    name: 'Stereo 70 (Dealul Piscului 1970)',
    country: 'Romania',
    countryFlag: '🇷🇴',
    region: 'Balkans',
    epsg: 'EPSG:31700',
    description: 'Official Romanian national cadastral & geodetic projection (Stereographic 1970)',
  ),
  romaniaStereo33(
    id: 'romania_stereo33',
    name: 'Stereo 33 / ETRS89 (Romania)',
    country: 'Romania',
    countryFlag: '🇷🇴',
    region: 'Balkans',
    epsg: 'EPSG:3844',
    description: 'Pulkovo 1942(58) / Stereo 70 & modern ETRS89 Romania Grid',
  ),

  // --- Greece ---
  greeceGgrs87(
    id: 'greece_ggrs87',
    name: 'GGRS87 / Greek Grid (EGSA87)',
    country: 'Greece',
    countryFlag: '🇬🇷',
    region: 'Balkans',
    epsg: 'EPSG:2100',
    description: 'Official Greek Geodetic Reference System 1987 used in national cadastre (Ktimatologio)',
  ),

  // --- Germany ---
  germanyEtrs89Utm32(
    id: 'germany_etrs89_utm32',
    name: 'ETRS89 / UTM Zone 32N (Germany)',
    country: 'Germany',
    countryFlag: '🇩🇪',
    region: 'Europe',
    epsg: 'EPSG:25832',
    description: 'Official standard coordinate system for western & central German survey and cadastre (AdV standard)',
  ),
  germanyEtrs89Utm33(
    id: 'germany_etrs89_utm33',
    name: 'ETRS89 / UTM Zone 33N (Germany East)',
    country: 'Germany',
    countryFlag: '🇩🇪',
    region: 'Europe',
    epsg: 'EPSG:25833',
    description: 'Official standard coordinate system for eastern German survey and cadastre',
  ),
  germanyDhdnGaussKruger(
    id: 'germany_dhdn_gk',
    name: 'DHDN / 3-degree Gauss-Kruger (Zones 2-5)',
    country: 'Germany',
    countryFlag: '🇩🇪',
    region: 'Europe',
    epsg: 'EPSG:31467',
    description: 'Traditional German DHDN Gauss-Kruger coordinate system',
  ),

  // --- France ---
  franceRgf93Lambert93(
    id: 'france_rgf93_lambert93',
    name: 'RGF93 / Lambert-93 (France)',
    country: 'France',
    countryFlag: '🇫🇷',
    region: 'Europe',
    epsg: 'EPSG:2154',
    description: 'Official legal projection for metropolitan France (IGN / Cadastre)',
  ),
  franceCcConformal(
    id: 'france_cc_conformal',
    name: 'RGF93 / CC 9 Zones (CC42-CC50)',
    country: 'France',
    countryFlag: '🇫🇷',
    region: 'Europe',
    epsg: 'EPSG:3942-3950',
    description: 'High-precision 9-zone Coniques Conformes for French large-scale cadastral surveys',
  ),

  // --- United Kingdom & Ireland ---
  ukOsgb36Bng(
    id: 'uk_osgb36_bng',
    name: 'OSGB36 / British National Grid',
    country: 'United Kingdom',
    countryFlag: '🇬🇧',
    region: 'Europe',
    epsg: 'EPSG:27700',
    description: 'Official Ordnance Survey National Grid for Great Britain (England, Scotland, Wales)',
  ),
  ukIrishGrid(
    id: 'uk_irish_grid',
    name: 'TM65 / Irish National Grid',
    country: 'Ireland & UK',
    countryFlag: '🇮🇪',
    region: 'Europe',
    epsg: 'EPSG:29902',
    description: 'Official mapping grid for Northern Ireland and Republic of Ireland',
  ),

  // --- Switzerland ---
  swissLv95(
    id: 'swiss_lv95',
    name: 'CH1903+ / LV95 (Swiss Grid)',
    country: 'Switzerland',
    countryFlag: '🇨🇭',
    region: 'Europe',
    epsg: 'EPSG:2056',
    description: 'Official Swiss Federal national cadastral & topographic survey (swisstopo)',
  ),
  swissLv03(
    id: 'swiss_lv03',
    name: 'CH1903 / LV03 (Old Swiss Grid)',
    country: 'Switzerland',
    countryFlag: '🇨🇭',
    region: 'Europe',
    epsg: 'EPSG:21781',
    description: 'Historical Swiss military and civil coordinate system',
  ),

  // --- Austria ---
  austriaMgiGk(
    id: 'austria_mgi_gk',
    name: 'MGI / Austria Gauss-Kruger (M28/M31/M34)',
    country: 'Austria',
    countryFlag: '🇦🇹',
    region: 'Europe',
    epsg: 'EPSG:31258',
    description: 'Official Austrian Federal Office of Metrology and Surveying (BEV) cadastral grid',
  ),
  austriaLambert(
    id: 'austria_lambert',
    name: 'ETRS89 / Austria Lambert',
    country: 'Austria',
    countryFlag: '🇦🇹',
    region: 'Europe',
    epsg: 'EPSG:3416',
    description: 'Modern official ETRS89 Austrian Lambert conformal projection',
  ),

  // --- Italy ---
  italyMonteMarioZone1(
    id: 'italy_monte_mario_1',
    name: 'Monte Mario / Italy Zone 1 (Gauss-Boaga West)',
    country: 'Italy',
    countryFlag: '🇮🇹',
    region: 'Europe',
    epsg: 'EPSG:3003',
    description: 'Official Italian Gauss-Boaga West Grid (Agenzia delle Entrate / Catasto)',
  ),
  italyMonteMarioZone2(
    id: 'italy_monte_mario_2',
    name: 'Monte Mario / Italy Zone 2 (Gauss-Boaga East)',
    country: 'Italy',
    countryFlag: '🇮🇹',
    region: 'Europe',
    epsg: 'EPSG:3004',
    description: 'Official Italian Gauss-Boaga East Grid for peninsular Italy & Sicily',
  ),
  italyEtrs89Utm32(
    id: 'italy_etrs89_utm32',
    name: 'ETRS89 / UTM Zone 32N & 33N (Italy)',
    country: 'Italy',
    countryFlag: '🇮🇹',
    region: 'Europe',
    epsg: 'EPSG:25832',
    description: 'Modern Italian national geodetic survey and RNDT standard',
  ),

  // --- Spain ---
  spainEtrs89Utm30(
    id: 'spain_etrs89_utm30',
    name: 'ETRS89 / UTM Zone 30N (Mainland Spain)',
    country: 'Spain',
    countryFlag: '🇪🇸',
    region: 'Europe',
    epsg: 'EPSG:25830',
    description: 'Official Spanish National Geographic Institute (IGN) & Sede Electrónica del Catastro',
  ),
  spainEd50Utm30(
    id: 'spain_ed50_utm30',
    name: 'ED50 / UTM Zone 30N (Spain)',
    country: 'Spain',
    countryFlag: '🇪🇸',
    region: 'Europe',
    epsg: 'EPSG:23030',
    description: 'Historical Spanish European Datum 1950 coordinate system',
  ),

  // --- Poland ---
  polandEtrf2000Cs2000(
    id: 'poland_etrf2000_cs2000',
    name: 'ETRF2000-PL / CS2000 (Układ 2000)',
    country: 'Poland',
    countryFlag: '🇵🇱',
    region: 'Europe',
    epsg: 'EPSG:2177',
    description: 'Official Polish cadastral and large-scale geodetic survey projection (Zones 5-8)',
  ),
  polandEtrf2000Cs92(
    id: 'poland_etrf2000_cs92',
    name: 'ETRF2000-PL / CS92 (Układ 1992)',
    country: 'Poland',
    countryFlag: '🇵🇱',
    region: 'Europe',
    epsg: 'EPSG:2180',
    description: 'Official Polish national topographic and civil mapping projection',
  ),

  // --- Czechia & Slovakia ---
  czechSjtskKrovak(
    id: 'czech_sjtsk_krovak',
    name: 'S-JTSK / Krovak East North (Czechia & Slovakia)',
    country: 'Czechia & Slovakia',
    countryFlag: '🇨🇿',
    region: 'Europe',
    epsg: 'EPSG:5514',
    description: 'Official Unified Trigonometric Cadastral Network projection (ČÚZK & ÚGKK)',
  ),

  // --- Hungary ---
  hungaryHd72Eov(
    id: 'hungary_hd72_eov',
    name: 'HD72 / EOV (Uniform National Projection)',
    country: 'Hungary',
    countryFlag: '🇭🇺',
    region: 'Europe',
    epsg: 'EPSG:23700',
    description: 'Official Hungarian National Uniform Projection for cadastre and geodesy (FÖMI)',
  ),

  // --- Netherlands ---
  netherlandsRdNew(
    id: 'netherlands_rd_new',
    name: 'Amersfoort / RD New (Rijksdriehoeksstelsel)',
    country: 'Netherlands',
    countryFlag: '🇳🇱',
    region: 'Europe',
    epsg: 'EPSG:28992',
    description: 'Official Dutch National Triangulation Grid (Kadaster)',
  ),

  // --- Belgium ---
  belgiumLambert2008(
    id: 'belgium_lambert2008',
    name: 'Lambert 2008 / ETRS89 (Belgium)',
    country: 'Belgium',
    countryFlag: '🇧🇪',
    region: 'Europe',
    epsg: 'EPSG:3812',
    description: 'Official Belgian National Geographic Institute (NGI/IGN) modern coordinate system',
  ),
  belgiumLambert72(
    id: 'belgium_lambert72',
    name: 'Belgian Lambert 72 (BD72)',
    country: 'Belgium',
    countryFlag: '🇧🇪',
    region: 'Europe',
    epsg: 'EPSG:31370',
    description: 'Traditional Belgian cadastral coordinate reference system',
  ),

  // --- Serbia ---
  serbiaMgiZone7(
    id: 'serbia_mgi_zone7',
    name: 'MGI / Balkans Gauss-Kruger Zone 7 (Serbia)',
    country: 'Serbia',
    countryFlag: '🇷🇸',
    region: 'Balkans',
    epsg: 'EPSG:31277',
    description: 'Official Serbian Republic Geodetic Authority (RGZ) coordinate system',
  ),

  // --- North Macedonia ---
  macedoniaMgiZone7(
    id: 'macedonia_mgi_zone7',
    name: 'MGI / Macedonia Gauss-Kruger Zone 7',
    country: 'North Macedonia',
    countryFlag: '🇲🇰',
    region: 'Balkans',
    epsg: 'EPSG:6316',
    description: 'Official State Authority for Geodetic Works (AKN) projection',
  ),

  // --- Turkey ---
  turkeyItrf96Tm30(
    id: 'turkey_itrf96_tm30',
    name: 'ITRF96 / TM30 & TM33 (Turkey 3° Zones)',
    country: 'Turkey',
    countryFlag: '🇹🇷',
    region: 'Balkans',
    epsg: 'EPSG:5256',
    description: 'Official Turkish General Directorate of Land Registry and Cadastre (TKGM) system',
  ),

  // --- Croatia ---
  croatiaHtrs96Tm(
    id: 'croatia_htrs96_tm',
    name: 'HTRS96 / TM (Croatia Grid)',
    country: 'Croatia',
    countryFlag: '🇭🇷',
    region: 'Balkans',
    epsg: 'EPSG:3765',
    description: 'Official Croatian State Geodetic Administration (DGU) projection',
  ),

  // --- Slovenia ---
  sloveniaD96Tm(
    id: 'slovenia_d96_tm',
    name: 'D96 / TM (Slovenia Grid)',
    country: 'Slovenia',
    countryFlag: '🇸🇮',
    region: 'Balkans',
    epsg: 'EPSG:3794',
    description: 'Official Surveying and Mapping Authority of Slovenia (GURS) projection',
  ),

  // --- United States ---
  usaNad83StatePlane(
    id: 'usa_nad83_spcs',
    name: 'NAD83 / State Plane Coordinate System (SPCS)',
    country: 'United States',
    countryFlag: '🇺🇸',
    region: 'Americas',
    epsg: 'EPSG:NAD83',
    description: 'Official US National Geodetic Survey (NGS) projection for land surveying and cadastre',
  ),
  usaUtmNad83(
    id: 'usa_utm_nad83',
    name: 'NAD83 / UTM Zones 10N-19N (USA)',
    country: 'United States',
    countryFlag: '🇺🇸',
    region: 'Americas',
    epsg: 'EPSG:26910-26919',
    description: 'US Federal metric conformal projection across the North American continent',
  ),

  // --- Global & General ---
  wgs84Geo(
    id: 'wgs84_geo',
    name: 'WGS 84 (GPS Latitude / Longitude)',
    country: 'Global',
    countryFlag: '🌐',
    region: 'Global',
    epsg: 'EPSG:4326',
    description: 'Global Geographic coordinates in decimal degrees (GPS standard)',
  ),
  webMercator(
    id: 'web_mercator',
    name: 'WGS 84 / Pseudo-Mercator (Web Mercator)',
    country: 'Global',
    countryFlag: '🌐',
    region: 'Global',
    epsg: 'EPSG:3857',
    description: 'Standard projection used by Google Maps, OpenStreetMap, Bing, and GIS web portals',
  ),
  utmGeneral(
    id: 'utm_general',
    name: 'UTM (Universal Transverse Mercator - Metric)',
    country: 'Global',
    countryFlag: '🌐',
    region: 'Global',
    epsg: 'UTM Metric',
    description: 'General international metric transverse mercator grid (Zones 1N-60N)',
  ),
  localCartesian(
    id: 'local_cartesian',
    name: 'Non-projected / Local (X, Y)',
    country: 'Local',
    countryFlag: '📐',
    region: 'Global',
    epsg: 'Local / None',
    description: 'Arbitrary local Cartesian coordinates without geodetic projection',
  );

  final String id;
  final String name;
  final String country;
  final String countryFlag;
  final String region;
  final String epsg;
  final String description;
  final bool isDefault;

  const CoordinateSystem({
    required this.id,
    required this.name,
    required this.country,
    required this.countryFlag,
    required this.region,
    required this.epsg,
    required this.description,
    this.isDefault = false,
  });

  static CoordinateSystem fromId(String? id) {
    if (id == null) return CoordinateSystem.bgs2005Cadastral;
    for (final crs in CoordinateSystem.values) {
      if (crs.id == id) return crs;
    }
    return CoordinateSystem.bgs2005Cadastral;
  }

  /// Heuristic to guess coordinate system from CAD bounding box.
  static CoordinateSystem detectFromBounds(Rect bounds) {
    final double minX = bounds.left;
    final double maxX = bounds.right;
    final double minY = bounds.top;
    final double maxY = bounds.bottom;

    // Check WGS84 Geographic (Lat: -90..90, Lon: -180..180)
    if (minX >= -180 && maxX <= 180 && minY >= -90 && maxY <= 90) {
      return CoordinateSystem.wgs84Geo;
    }

    // Small numbers (0 to 2000) -> Local/Non-projected
    if (minX.abs() <= 2000 && maxX.abs() <= 2000 && minY.abs() <= 2000 && maxY.abs() <= 2000) {
      return CoordinateSystem.localCartesian;
    }

    // Check CS 1970 (Values in tens of thousands, e.g. 4000..95000, 20000..90000)
    if (minX >= 0 && maxX <= 150000 && minY >= 0 && maxY <= 150000 && (maxX > 2000 || maxY > 2000)) {
      return CoordinateSystem.cs1970;
    }

    // Check Swiss Grid LV95: Easting 2,480,000..2,840,000 & Northing 1,070,000..1,300,000
    if ((minX >= 2400000 && maxX <= 2900000 && minY >= 1000000 && maxY <= 1400000) ||
        (minY >= 2400000 && maxY <= 2900000 && minX >= 1000000 && maxX <= 1400000)) {
      return CoordinateSystem.swissLv95;
    }

    // Check BGS 2005 Cadastral: typically X ~ 4,500,000..4,900,000 and Y ~ 8,300,000..8,700,000 (or vice-versa)
    final bool isBgsCadX = (minX >= 4000000 && maxX <= 5200000 && minY >= 8000000 && maxY <= 9000000);
    final bool isBgsCadY = (minY >= 4000000 && maxY <= 5200000 && minX >= 8000000 && maxX <= 9000000);
    if (isBgsCadX || isBgsCadY) {
      return CoordinateSystem.bgs2005Cadastral;
    }

    // Check French Lambert-93: X ~ 100,000..1,300,000, Y ~ 6,000,000..7,200,000
    final bool isRgf93X = (minX >= 100000 && maxX <= 1300000 && minY >= 5900000 && maxY <= 7300000);
    final bool isRgf93Y = (minY >= 100000 && maxY <= 1300000 && minX >= 5900000 && maxX <= 7300000);
    if (isRgf93X || isRgf93Y) {
      return CoordinateSystem.franceRgf93Lambert93;
    }

    // Check Greek Grid GGRS87: Northing 3,700,000..4,550,000, Easting 100,000..900,000
    final bool isGgrsX = (minX >= 100000 && maxX <= 900000 && minY >= 3700000 && maxY < 4550000);
    final bool isGgrsY = (minY >= 100000 && maxY <= 900000 && minX >= 3700000 && maxX < 4550000);
    if (isGgrsX || isGgrsY) {
      return CoordinateSystem.greeceGgrs87;
    }

    // Check BGS 2005 UTM 35N: typically Northing ~ 4,550,000..5,000,000 and Easting ~ 200,000..800,000
    final bool isUtm35X = (minX >= 200000 && maxX <= 900000 && minY >= 4550000 && maxY <= 5200000);
    final bool isUtm35Y = (minY >= 200000 && maxY <= 900000 && minX >= 4550000 && maxX <= 5200000);
    if (isUtm35X || isUtm35Y) {
      return CoordinateSystem.bgs2005Utm35n;
    }

    // Check Romanian Stereo 70: X ~ 200,000..800,000, Y ~ 200,000..800,000
    final bool isStereo70 = (minX >= 180000 && maxX <= 820000 && minY >= 180000 && maxY <= 820000);
    if (isStereo70) {
      return CoordinateSystem.romaniaStereo70;
    }

    // Check British National Grid OSGB36: X ~ 0..700,000, Y ~ 0..1,300,000
    final bool isOsgbX = (minX >= 0 && maxX <= 700000 && minY >= 0 && maxY <= 1300000 && (maxX > 150000 || maxY > 150000));
    if (isOsgbX) {
      return CoordinateSystem.ukOsgb36Bng;
    }

    // Default to general UTM or BGS 2005
    return CoordinateSystem.bgs2005Cadastral;
  }
}
