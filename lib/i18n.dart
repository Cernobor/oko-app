import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:oko/data.dart';
import 'package:sprintf/sprintf.dart';
import 'package:filesize/filesize.dart';


class I18N {
  I18N(this.locale);

  final Locale locale;

  static I18N of(BuildContext context) {
    return Localizations.of(context, I18N);
  }

  static final Map<String, Map<String, String>> _messages = {
    'appTitle': {
      'cs': 'OKO',
      'en': 'OKO'
    },
    'drawerPaired': {
      'cs': 'Spárováno se serverem',
      'en': 'Paired to server'
    },
    'drawerServerAvailable': {
      'cs': 'Server dostupný',
      'en': 'Server available'
    },
    'zoomIn': {
      'cs': 'Přiblížit',
      'en': 'Zoom in'
    },
    'zoomOut': {
      'cs': 'Oddálit',
      'en': 'Zoom out'
    },
    'resetRotation': {
      'cs': 'Resetovat rotaci',
      'en': 'Reset rotation'
    },
    'serverAddressLabel': {
      'cs': 'Adresa serveru',
      'en': 'Server address'
    },
    'errorAddressRequired': {
      'cs': 'Adresa je vyžadována',
      'en': 'Address is required'
    },
    'stop': {
      'cs': 'Stop',
      'en': 'Stop'
    },
    'scan': {
      'cs': 'Naskenovat',
      'en': 'Scan'
    },
    'nameLabel': {
      'cs': 'Jméno',
      'en': 'Name'
    },
    'descriptionLabel': {
      'cs': 'Popis',
      'en': 'Description'
    },
    'errorNameRequired': {
      'cs': 'Jméno je vyžadováno',
      'en': 'Name is required'
    },
    'dialogPair': {
      'cs': 'Spárovat',
      'en': 'Pair'
    },
    'handshakeExistsTitle': {
      'cs': 'Existující jméno',
      'en': 'Existing name'
    },
    'handshakeExistsSubtitle': {
      'cs': 'Spárovat s již existujícím jménem',
      'en': 'Pair with already existing name'
    },
    'dialogCancel': {
      'cs': 'Zrušit',
      'en': 'Cancel'
    },
    'dialogConfirm': {
      'cs': 'Potvrdit',
      'en': 'Confirm'
    },
    'dialogSave': {
      'cs': 'Uložit',
      'en': 'Save'
    },
    'invalidPairFields': {
      'cs': 'Pole mají neplatné hodnoty',
      'en': 'The fields have invalid values'
    },
    'alertErrorTitle': {
      'cs': 'Chyba',
      'en': 'Error'
    },
    'ok': {
      'cs': 'OK',
      'en': 'OK'
    },
    'commErrorNameNotSupplied': {
      'cs': 'Nebylo posláno žádné jméno.',
      'en': 'No name was sent.'
    },
    'commErrorNameAlreadyExists': {
      'cs': 'Poslané jméno již existuje.',
      'en': 'The sent name already exists.'
    },
    'logPoiCurrentLocation': {
      'cs': 'Zanést bod na aktuální poloze',
      'en': 'Log point at current position'
    },
    'logPoiCrosshair': {
      'cs': 'Zanést bod na zaměřovači',
      'en': 'Log point at crosshair'
    },
    'locationContinuousButtonTooltip': {
      'cs': 'Zapnout/vypnout získávání polohy',
      'en': 'Turn location acquisition on/off',
    },
    'toggleLockViewToLocationButtonTooltip': {
      'cs': 'Zaměřit pohled na aktuální polohu',
      'en': 'Center view to current location'
    },
    'addPoiDialogTitle': {
      'cs': 'Vlastnosti bodu',
      'en': 'Point properties'
    },
    'useOfflineMap': {
      'cs': 'Použít offline mapu',
      'en': 'Use offline map'
    },
    'mapSizeWarning': {
      'cs': '%s',
      'en': '%s'
    },
    'downloadingMapSnackBar': {
      'cs': 'Stahuji...',
      'en': 'Downloading...'
    },
    'unpackingMapSnackBar': {
      'cs': 'Rozbaluji...',
      'en': 'Unpacking...'
    },
    'doneMapSnackBar': {
      'cs': 'Hotovo!',
      'en': 'Done!'
    },
    'download': {
      'cs': 'Stáhnout ze serveru',
      'en': 'Download from server'
    },
    'upload': {
      'cs': 'Nahrát na server',
      'en': 'Upload to server'
    },
    'sync': {
      'cs': 'Synchronizovat se serverem',
      'en': 'Synchronize with server'
    },
    'clearLocalPois': {
      'cs': 'Odstranit lokální body',
      'en': 'Clear local points'
    },
    'stopNavigationButton': {
      'cs': 'Zastavit navigaci',
      'en': 'Stop navigation'
    },
    'navigateToButton': {
      'cs': 'Navigovat',
      'en': 'Navigate'
    },
    'deleteButton': {
      'cs': 'Smazat',
      'en': 'Delete'
    },
    'undeleteButton': {
      'cs': 'Odsmazat',
      'en': 'Undelete'
    },
    'distance': {
      'cs': 'Vzdálenost',
      'en': 'Distance'
    },
    'bearing': {
      'cs': 'Azimut',
      'en': 'Bearing'
    },
    'relativeBearing': {
      'cs': 'Rel. azimut',
      'en': 'Rel. bearing'
    },
    'yes': {
      'cs': 'Ano',
      'en': 'Yes'
    },
    'no': {
      'cs': 'Ne',
      'en': 'No'
    },
    'aboutToDeleteLocalPoi': {
      'cs': 'Opravdu smazat lokální bod? Tuto operaci nelze vrátit.',
      'en': 'Really delete local point? This operation cannot be undone.'
    },
    'aboutToRevertGlobalPoi': {
      'cs': 'Opravdu vrátit původní data k tomuto bodu? Tuto operaci nelze vrátit.',
      'en': 'Really revert to the original data for thsi point? This operation cannot be undone.'
    },
    'nPois1': {
      'cs': '1 bod',
      'en': '1 point'
    },
    'nPois2-4': {
      'cs': '%d body',
      'en': '%d points'
    },
    'nPois5+': {
      'cs': '%d bodů',
      'en': '%d points'
    },
    'centerViewInfoButton': {
      'cs': 'Vycentrovat mapu',
      'en': 'Center map'
    },
    'poiListTitle': {
      'cs': 'Seznam bodů',
      'en': 'Point list'
    },
    'userListTitle': {
      'cs': 'Seznam uživatelů',
      'en': 'User list'
    },
    'infoOnly': {
      'cs': 'Pouze informativní',
      'en': 'Informative only'
    },
    'category': {
      'cs': 'Kategorie',
      'en': 'Category'
    },
    'category-${PointCategory.general.name}': {
      'cs': 'obecné',
      'en': 'general'
    },
    'category-${PointCategory.camp.name}': {
      'cs': 'tábor',
      'en': 'camp'
    },
    'category-${PointCategory.animal.name}': {
      'cs': 'zvíře',
      'en': 'animal'
    },
    'category-${PointCategory.holySite.name}': {
      'cs': 'posvátné místo',
      'en': 'holy site'
    },
    'category-${PointCategory.treasure.name}': {
      'cs': 'poklad',
      'en': 'treasure'
    },
    'category-${PointCategory.important.name}': {
      'cs': 'důležité',
      'en': 'important'
    },
    'category-${PointCategory.unknown.name}': {
      'cs': '???',
      'en': '???'
    },
    'edit': {
      'cs': 'Upravit',
      'en': 'Edit'
    },
    'revert': {
      'cs': 'Vrátit',
      'en': 'Revert'
    },
    'location': {
      'cs': 'Pozice',
      'en': 'Position'
    },
    'metadata': {
      'cs': 'Metadata',
      'en': 'Metadata'
    },
    'owner': {
      'cs': 'Vlastník',
      'en': 'Owner'
    },
    'me': {
      'cs': 'já',
      'en': 'me'
    },
    'toFilter': {
      'cs': 'Filtrovat',
      'en': 'Filter'
    },
    'filterByOwner': {
      'cs': 'Filtrovat podle vlastníka',
      'en': 'Filter by owner'
    },
    'filterByCategory': {
      'cs': 'Filtrovat podle kategorie',
      'en': 'Filter by category'
    },
    'downloadConfirm': {
      'cs': 'Opravdu stáhnout?',
      'en': 'Really download?'
    },
    'downloadConfirmDetail': {
      'cs': 'Pouhé stažení nezapíše lokální změny na server. Stav serveru nahradí lokální stav, čímž dojde ke smazání všech změn a nových bodů.',
      'en': 'Mere download does not write local changes to the server. The server state will replace the local state, causing deletion of all changes and new points.'
    },
    'downloaded': {
      'cs': 'Staženo',
      'en': 'Downloaded'
    }
  };

  String get appTitle => _messages['appTitle']![locale.languageCode]!;
  String get drawerPaired => _messages['drawerPaired']![locale.languageCode]!;
  String get drawerServerAvailable => _messages['drawerServerAvailable']![locale.languageCode]!;
  String get zoomIn => _messages['zoomIn']![locale.languageCode]!;
  String get zoomOut => _messages['zoomOut']![locale.languageCode]!;
  String get resetRotation => _messages['resetRotation']![locale.languageCode]!;
  String get serverAddressLabel => _messages['serverAddressLabel']![locale.languageCode]!;
  String get errorAddressRequired => _messages['errorAddressRequired']![locale.languageCode]!;
  String get stop => _messages['stop']![locale.languageCode]!;
  String get scan => _messages['scan']![locale.languageCode]!;
  String get nameLabel => _messages['nameLabel']![locale.languageCode]!;
  String get descriptionLabel => _messages['descriptionLabel']![locale.languageCode]!;
  String get errorNameRequired => _messages['errorNameRequired']![locale.languageCode]!;
  String get dialogPair => _messages['dialogPair']![locale.languageCode]!;
  String get handshakeExistsTitle => _messages['handshakeExistsTitle']![locale.languageCode]!;
  String get handshakeExistsSubtitle => _messages['handshakeExistsSubtitle']![locale.languageCode]!;
  String get dialogCancel => _messages['dialogCancel']![locale.languageCode]!;
  String get dialogConfirm => _messages['dialogConfirm']![locale.languageCode]!;
  String get dialogSave => _messages['dialogSave']![locale.languageCode]!;
  String get invalidPairFields => _messages['invalidPairFields']![locale.languageCode]!;
  String get alertErrorTitle => _messages['alertErrorTitle']![locale.languageCode]!;
  String get ok => _messages['ok']![locale.languageCode]!;
  String get commErrorNameNotSupplied => _messages['commErrorNameNotSupplied']![locale.languageCode]!;
  String get commErrorNameAlreadyExists => _messages['commErrorNameAlreadyExists']![locale.languageCode]!;
  String get logPoiCurrentLocation => _messages['logPoiCurrentLocation']![locale.languageCode]!;
  String get logPoiCrosshair => _messages['logPoiCrosshair']![locale.languageCode]!;
  String get locationContinuousButtonTooltip => _messages['locationContinuousButtonTooltip']![locale.languageCode]!;
  String get lockViewToLocationButtonTooltip => _messages['toggleLockViewToLocationButtonTooltip']![locale.languageCode]!;
  String get addPoiDialogTitle => _messages['addPoiDialogTitle']![locale.languageCode]!;
  String get useOfflineMap => _messages['useOfflineMap']![locale.languageCode]!;
  String mapSizeWarning(int size) => sprintf(_messages['mapSizeWarning']![locale.languageCode]!, [filesize(size)]);
  String get downloadingMapSnackBar => _messages['downloadingMapSnackBar']![locale.languageCode]!;
  String get unpackingMapSnackBar => _messages['unpackingMapSnackBar']![locale.languageCode]!;
  String get doneMapSnackBar => _messages['doneMapSnackBar']![locale.languageCode]!;
  String get download => _messages['download']![locale.languageCode]!;
  String get upload => _messages['upload']![locale.languageCode]!;
  String get sync => _messages['sync']![locale.languageCode]!;
  String get clearLocalPois => _messages['clearLocalPois']![locale.languageCode]!;
  String get stopNavigationButton => _messages['stopNavigationButton']![locale.languageCode]!;
  String get navigateToButton => _messages['navigateToButton']![locale.languageCode]!;
  String get deleteButton => _messages['deleteButton']![locale.languageCode]!;
  String get undeleteButton => _messages['undeleteButton']![locale.languageCode]!;
  String get distance => _messages['distance']![locale.languageCode]!;
  String get bearing => _messages['bearing']![locale.languageCode]!;
  String get relativeBearing => _messages['relativeBearing']![locale.languageCode]!;
  String get yes => _messages['yes']![locale.languageCode]!;
  String get no => _messages['no']![locale.languageCode]!;
  String get aboutToDeleteLocalPoi => _messages['aboutToDeleteLocalPoi']![locale.languageCode]!;
  String get aboutToRevertGlobalPoi => _messages['aboutToRevertGlobalPoi']![locale.languageCode]!;
  String Function(int n) get nPois => (int n) {
    if (n < 0) {
      throw Exception('negative number');
    }
    if (n == 1) {
      return sprintf(_messages['nPois1']![locale.languageCode]!, [n]);
    }
    if (n < 5) {
      return sprintf(_messages['nPois2-4']![locale.languageCode]!, [n]);
    }
    return sprintf(_messages['nPois5+']![locale.languageCode]!, [n]);
  };
  String get centerViewInfoButton => _messages['centerViewInfoButton']![locale.languageCode]!;
  String get poiListTitle => _messages['poiListTitle']![locale.languageCode]!;
  String get userListTitle => _messages['userListTitle']![locale.languageCode]!;
  String get infoOnly => _messages['infoOnly']![locale.languageCode]!;
  String get category => _messages['category']![locale.languageCode]!;
  String Function(PointCategory x) get categories => ((PointCategory category) => _messages['category-${category.name}']![locale.languageCode]!);
  String get edit => _messages['edit']![locale.languageCode]!;
  String get revert => _messages['revert']![locale.languageCode]!;
  String get position => _messages['location']![locale.languageCode]!;
  String get metadata => _messages['metadata']![locale.languageCode]!;
  String get owner => _messages['owner']![locale.languageCode]!;
  String get me => _messages['me']![locale.languageCode]!;
  String get toFilter => _messages['toFilter']![locale.languageCode]!;
  String get filterByOwner => _messages['filterByOwner']![locale.languageCode]!;
  String get filterByCategory => _messages['filterByCategory']![locale.languageCode]!;
  String get downloadConfirm => _messages['downloadConfirm']![locale.languageCode]!;
  String get downloadConfirmDetail => _messages['downloadConfirmDetail']![locale.languageCode]!;
  String get downloaded => _messages['downloaded']![locale.languageCode]!;
}

class I18NDelegate extends LocalizationsDelegate<I18N> {
  const I18NDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'cs'].contains(locale.languageCode);

  @override
  Future<I18N> load(Locale locale) => SynchronousFuture<I18N>(I18N(locale));

  @override
  bool shouldReload(LocalizationsDelegate<I18N> old) => false;


}