import 'package:filesize/filesize.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oko/data.dart';
import 'package:sprintf/sprintf.dart';

class I18N {
  I18N(this.locale);

  final Locale locale;

  static I18N of(BuildContext context) {
    return Localizations.of(context, I18N);
  }

  String get appTitle => {'cs': 'OKO', 'en': 'OKO'}[locale.languageCode]!;
  String get drawerPaired => {
        'cs': 'Spárováno se serverem',
        'en': 'Paired to server'
      }[locale.languageCode]!;
  String get drawerServerChecking =>
      {'cs': 'Zjišťuji dostupnost serveru', 'en': 'Checking server availability'}[locale.languageCode]!;
  String get drawerServerAvailable =>
      {'cs': 'Server dostupný', 'en': 'Server available'}[locale.languageCode]!;
  String get drawerServerUnavailable => {
        'cs': 'Server nedostupný',
        'en': 'Server unavailable'
      }[locale.languageCode]!;
  String get zoomIn =>
      {'cs': 'Přiblížit', 'en': 'Zoom in'}[locale.languageCode]!;
  String get zoomOut =>
      {'cs': 'Oddálit', 'en': 'Zoom out'}[locale.languageCode]!;
  String get resetRotation =>
      {'cs': 'Resetovat rotaci', 'en': 'Reset rotation'}[locale.languageCode]!;
  String get serverAddressLabel =>
      {'cs': 'Adresa serveru', 'en': 'Server address'}[locale.languageCode]!;
  String get errorAddressRequired => {
        'cs': 'Adresa je vyžadována',
        'en': 'Address is required'
      }[locale.languageCode]!;
  String get stop => {'cs': 'Stop', 'en': 'Stop'}[locale.languageCode]!;
  String get scan => {'cs': 'Naskenovat', 'en': 'Scan'}[locale.languageCode]!;
  String get nameLabel => {'cs': 'Jméno', 'en': 'Name'}[locale.languageCode]!;
  String get descriptionLabel =>
      {'cs': 'Popis', 'en': 'Description'}[locale.languageCode]!;
  String get errorNameRequired => {
        'cs': 'Jméno je vyžadováno',
        'en': 'Name is required'
      }[locale.languageCode]!;
  String get dialogPair =>
      {'cs': 'Spárovat', 'en': 'Pair'}[locale.languageCode]!;
  String get handshakeExistsTitle =>
      {'cs': 'Existující jméno', 'en': 'Existing name'}[locale.languageCode]!;
  String get handshakeExistsSubtitle => {
        'cs': 'Spárovat s již existujícím jménem',
        'en': 'Pair with already existing name'
      }[locale.languageCode]!;
  String get dialogCancel =>
      {'cs': 'Zrušit', 'en': 'Cancel'}[locale.languageCode]!;
  String get dialogConfirm =>
      {'cs': 'Potvrdit', 'en': 'Confirm'}[locale.languageCode]!;
  String get dialogSave => {'cs': 'Uložit', 'en': 'Save'}[locale.languageCode]!;
  String get invalidPairFields => {
        'cs': 'Pole mají neplatné hodnoty',
        'en': 'The fields have invalid values'
      }[locale.languageCode]!;
  String get ok => {'cs': 'OK', 'en': 'OK'}[locale.languageCode]!;
  String get commErrorNameNotSupplied => {
        'cs': 'Nebylo posláno žádné jméno.',
        'en': 'No name was sent.'
      }[locale.languageCode]!;
  String get commErrorNameAlreadyExists => {
        'cs': 'Poslané jméno již existuje.',
        'en': 'The sent name already exists.'
      }[locale.languageCode]!;
  String get logPoiCurrentLocation => {
        'cs': 'Zanést bod na aktuální poloze',
        'en': 'Log point at current position'
      }[locale.languageCode]!;
  String get logPoiCrosshair => {
        'cs': 'Zanést bod na zaměřovači',
        'en': 'Log point at crosshair'
      }[locale.languageCode]!;
  String get locationContinuousButtonTooltip => {
        'cs': 'Zapnout/vypnout získávání polohy',
        'en': 'Turn location acquisition on/off',
      }[locale.languageCode]!;
  String get lockViewToLocationButtonTooltip => {
        'cs': 'Zaměřit pohled na aktuální polohu',
        'en': 'Center view to current location'
      }[locale.languageCode]!;
  String get addPoiDialogTitle =>
      {'cs': 'Vlastnosti bodu', 'en': 'Point properties'}[locale.languageCode]!;
  String get useOfflineMap => {
        'cs': 'Použít offline mapu',
        'en': 'Use offline map'
      }[locale.languageCode]!;
  String mapSizeWarning(int size) =>
      sprintf({'cs': '%s', 'en': '%s'}[locale.languageCode]!, [filesize(size)]);
  String get downloading =>
      {'cs': 'Stahování...', 'en': 'Downloading...'}[locale.languageCode]!;
  String get unpacking =>
      {'cs': 'Rozbalování...', 'en': 'Unpacking...'}[locale.languageCode]!;
  String get doneMapSnackBar =>
      {'cs': 'Hotovo!', 'en': 'Done!'}[locale.languageCode]!;
  String get download => {
        'cs': 'Stáhnout ze serveru',
        'en': 'Download from server'
      }[locale.languageCode]!;
  String get upload => {
        'cs': 'Nahrát na server',
        'en': 'Upload to server'
      }[locale.languageCode]!;
  String get sync => {
        'cs': 'Synchronizovat se serverem',
        'en': 'Synchronize with server'
      }[locale.languageCode]!;
  String get syncSuccessful => {
        'cs': 'Synchronizace úspěšná',
        'en': 'Synchronization successful'
      }[locale.languageCode]!;
  String get clearLocalPois => {
        'cs': 'Odstranit lokální body',
        'en': 'Clear local points'
      }[locale.languageCode]!;
  String get stopNavigationButton => {
        'cs': 'Zastavit navigaci',
        'en': 'Stop navigation'
      }[locale.languageCode]!;
  String get navigateToButton =>
      {'cs': 'Navigovat', 'en': 'Navigate'}[locale.languageCode]!;
  String get delete => {'cs': 'Smazat', 'en': 'Delete'}[locale.languageCode]!;
  String get undelete =>
      {'cs': 'Odsmazat', 'en': 'Undelete'}[locale.languageCode]!;
  String get distance =>
      {'cs': 'Vzdálenost', 'en': 'Distance'}[locale.languageCode]!;
  String get bearing => {'cs': 'Azimut', 'en': 'Bearing'}[locale.languageCode]!;
  String get relativeBearing =>
      {'cs': 'Rel. azimut', 'en': 'Rel. bearing'}[locale.languageCode]!;
  String get yes => {'cs': 'Ano', 'en': 'Yes'}[locale.languageCode]!;
  String get no => {'cs': 'Ne', 'en': 'No'}[locale.languageCode]!;
  String get aboutToDeleteLocalPoi => {
        'cs': 'Opravdu smazat lokální bod? Tuto operaci nelze vrátit.',
        'en': 'Really delete local point? This operation cannot be undone.'
      }[locale.languageCode]!;
  String get aboutToRevertGlobalPoi => {
        'cs':
            'Opravdu vrátit původní data k tomuto bodu? Tuto operaci nelze vrátit.',
        'en':
            'Really revert to the original data for thsi point? This operation cannot be undone.'
      }[locale.languageCode]!;
  String Function(int n) get nPois => (int n) {
        if (n < 0) {
          throw Exception('negative number');
        }
        if (n == 1) {
          return sprintf(
              {'cs': '1 bod', 'en': '1 point'}[locale.languageCode]!, [n]);
        }
        if (n < 5) {
          return sprintf(
              {'cs': '%d body', 'en': '%d points'}[locale.languageCode]!, [n]);
        }
        return sprintf(
            {'cs': '%d bodů', 'en': '%d points'}[locale.languageCode]!, [n]);
      };
  String get centerViewInfoButton =>
      {'cs': 'Vycentrovat mapu', 'en': 'Center map'}[locale.languageCode]!;
  String get poiListTitle =>
      {'cs': 'Seznam bodů', 'en': 'Point list'}[locale.languageCode]!;
  String get userListTitle =>
      {'cs': 'Seznam uživatelů', 'en': 'User list'}[locale.languageCode]!;
  String get infoOnly => {
        'cs': 'Pouze informativní',
        'en': 'Informative only'
      }[locale.languageCode]!;
  String get categoryTitle =>
      {'cs': 'Kategorie', 'en': 'Category'}[locale.languageCode]!;
  String Function(PointCategory x) get category =>
      ((PointCategory category) => {
            PointCategory.general.name: {'cs': 'Obecné', 'en': 'General'},
            PointCategory.camp.name: {'cs': 'Tábor', 'en': 'Camp'},
            PointCategory.animal.name: {'cs': 'Zvíře', 'en': 'Animal'},
            PointCategory.holySite.name: {
              'cs': 'Posvátné místo',
              'en': 'Holy site'
            },
            PointCategory.treasure.name: {'cs': 'Poklad', 'en': 'Treasure'},
            PointCategory.unknown.name: {'cs': '???', 'en': '???'}
          }[category.name]![locale.languageCode]!);
  String get edit => {'cs': 'Upravit', 'en': 'Edit'}[locale.languageCode]!;
  String get editPoint =>
      {'cs': 'Upravit bod', 'en': 'Edit point'}[locale.languageCode]!;
  String get newPoint =>
      {'cs': 'Nový bod', 'en': 'New point'}[locale.languageCode]!;
  String get revert => {'cs': 'Vrátit', 'en': 'Revert'}[locale.languageCode]!;
  String get position =>
      {'cs': 'Pozice', 'en': 'Position'}[locale.languageCode]!;
  String get metadata =>
      {'cs': 'Metadata', 'en': 'Metadata'}[locale.languageCode]!;
  String get owner => {'cs': 'Vlastník', 'en': 'Owner'}[locale.languageCode]!;
  String get me => {'cs': 'já', 'en': 'me'}[locale.languageCode]!;
  String get toFilter =>
      {'cs': 'Filtrovat', 'en': 'Filter'}[locale.languageCode]!;
  String get filterByOwner => {
        'cs': 'Filtrovat podle vlastníka',
        'en': 'Filter by owner'
      }[locale.languageCode]!;
  String get filterByCategory => {
        'cs': 'Filtrovat podle kategorie',
        'en': 'Filter by category'
      }[locale.languageCode]!;
  String get filterByAttributes => {
        'cs': 'Filtrovat podle vlastností',
        'en': 'Filter by attributes'
      }[locale.languageCode]!;
  String get filterByEditState => {
        'cs': 'Filtrovat podle stavu úprav',
        'en': 'Filter by edit state'
      }[locale.languageCode]!;
  String get downloadConfirm => {
        'cs': 'Opravdu stáhnout?',
        'en': 'Really download?'
      }[locale.languageCode]!;
  String get downloadConfirmDetail => {
        'cs':
            'Pouhé stažení nezapíše lokální změny na server. Nově vytvořené body zůstanou, ale úpravy na bodech ze serveru budou ztraceny.',
        'en':
            'Mere download does not write local changes to the server. Newly created points will be kept, but edits to points from the server will be lost.'
      }[locale.languageCode]!;
  String get downloaded =>
      {'cs': 'Staženo', 'en': 'Downloaded'}[locale.languageCode]!;
  String get dismiss => {'cs': 'Zavřít', 'en': 'Dismiss'}[locale.languageCode]!;
  String get error => {'cs': 'Chyba', 'en': 'Error'}[locale.languageCode]!;
  String get serverUnavailable => {
        'cs': 'Server nedostupný',
        'en': 'Server unavailable'
      }[locale.languageCode]!;
  String get pairing =>
      {'cs': 'Párování', 'en': 'Pairing'}[locale.languageCode]!;
  String userAlreadyExists(String user) => sprintf(
      {
        'cs': 'Uživatel "%s" již existuje.',
        'en': 'User "%s" already exists.'
      }[locale.languageCode]!,
      [user]);
  String userDoesNotExist(String user) => sprintf(
      {
        'cs': 'Uživatel "%s" neexistuje.',
        'en': 'User "%s" does not exist.'
      }[locale.languageCode]!,
      [user]);
  String get badRequest =>
      {'cs': 'Chybný dotaz', 'en': 'Bad request'}[locale.languageCode]!;
  String usernameForbidden(String username) => sprintf(
      {
        'cs': 'Uživatelské jméno "%s" je zakázané.',
        'en': 'Username "%s" is forbidden.'
      }[locale.languageCode]!,
      [username]);
  String get internalServerError => {
        'cs': 'Interní chyba serveru',
        'en': 'Internal server error'
      }[locale.languageCode]!;
  String get requestRefused => {
        'cs': 'Požadavek zamítnut.',
        'en': 'Request refused.'
      }[locale.languageCode]!;
  String unexpectedStatusCode(int code) => sprintf(
      {
        'cs': 'Neočekávaný stavový kód: %d',
        'en': 'Unexpected status code: %d'
      }[locale.languageCode]!,
      [code]);
  String get allNothing =>
      {'cs': 'Vše/nic', 'en': 'All/nothing'}[locale.languageCode]!;
  String get invert =>
      {'cs': 'Invertovat', 'en': 'Invert'}[locale.languageCode]!;
  String get reset =>
      {'cs': 'Resetovat aplikaci', 'en': 'Reset app'}[locale.languageCode]!;
  String get resetInfo => {
        'cs':
            'Zruší párování a smaže veškerá data. NEVRATNÁ OPERACE. Aktivujete dlouhým stiskem.',
        'en':
            'Breaks pairing and deletes all data. IRREVERSIBLE OPERATION. Activate by long press.'
      }[locale.languageCode]!;
  String get resetDone =>
      {'cs': 'Vyresetováno.', 'en': 'Reset done.'}[locale.languageCode]!;
  String get attributes =>
      {'cs': 'Vlastnosti', 'en': 'Attributes'}[locale.languageCode]!;
  String get noAttributes => {
        'cs': '<žádné vlastnosti>',
        'en': '<no attributes>'
      }[locale.languageCode]!;
  String Function(PointAttribute x) get attribute =>
      ((PointAttribute attribute) => {
            PointAttribute.important.name: {
              'cs': 'Důležité',
              'en': 'Important'
            },
          }[attribute.name]![locale.languageCode]!);
  String get intersection =>
      {'cs': 'průnik', 'en': 'intersection'}[locale.languageCode]!;
  String get exact => {'cs': 'shoda', 'en': 'match'}[locale.languageCode]!;
  String get close => {'cs': 'Zavřít', 'en': 'Close'}[locale.languageCode]!;
  String get renderBaseMap => {
        'cs': 'Vykreslovat podkladovou mapu',
        'en': 'Draw base map'
      }[locale.languageCode]!;
  String get newState => {'cs': 'Nový', 'en': 'New'}[locale.languageCode]!;
  String get editedState =>
      {'cs': 'Upravený', 'en': 'Edited'}[locale.languageCode]!;
  String get deletedState =>
      {'cs': 'Ke smazání', 'en': 'To be deleted'}[locale.languageCode]!;
  String get editedDeletedState => {
        'cs': 'Upravený + ke smazání',
        'en': 'Edited + to be deleted'
      }[locale.languageCode]!;
  String get pristineState =>
      {'cs': 'Nedotčený', 'en': 'Pristine'}[locale.languageCode]!;
  String get anyState =>
      {'cs': 'Jakýkoliv', 'en': 'Any state'}[locale.languageCode]!;
  String get color => {'cs': 'Barva', 'en': 'Colour'}[locale.languageCode]!;
  String get deadline => {
        'cs': 'Automaticky smazat',
        'en': 'Automatically delete'
      }[locale.languageCode]!;
  String get chooseTime =>
      {'cs': 'Vyberte čas', 'en': 'Choose a time'}[locale.languageCode]!;
  String get dialogNext => {'cs': 'Dále', 'en': 'Next'}[locale.languageCode]!;
  String get dialogBack => {'cs': 'Zpět', 'en': 'Back'}[locale.languageCode]!;
  String get managePhotos =>
      {'cs': 'Spravovat fotky', 'en': 'Manage photos'}[locale.languageCode]!;
  String get takePhoto =>
      {'cs': 'Vyfotit', 'en': 'Take a photo'}[locale.languageCode]!;
  String get pickPhoto =>
      {'cs': 'Vybrat fotku', 'en': 'Pick a photo'}[locale.languageCode]!;
  String get deletedPhoto =>
      {'cs': 'Smazaná fotka', 'en': 'Deleted photo'}[locale.languageCode]!;
  String get deletedPhotoDetail => {
        'cs': 'Bude smazána ze serveru při příští synchronizaci',
        'en': 'Will be deleted from the server upon next synchronization'
      }[locale.languageCode]!;
  String get addedPhoto =>
      {'cs': 'Přidaná fotka', 'en': 'Added photo'}[locale.languageCode]!;
  String get addedPhotoDetail => {
        'cs': 'Bude nahrána na server při příští synchronizaci',
        'en': 'Will be uploaded to server upon next synchronization'
      }[locale.languageCode]!;
  DateFormat get dateFormat => {
        'cs': DateFormat('d.M. HH:mm', 'cs'),
        'en': DateFormat('M/d HH:mm', 'en'),
      }[locale.languageCode]!;
  String get proposeImprovement => {
        'cs': 'Navrhnout vylepšení aplikace',
        'en': 'Propose app improvement'
      }[locale.languageCode]!;
  String get proposalDescriptionLabel => {
        'cs': 'Popis vylepšení',
        'en': 'Improvement description'
      }[locale.languageCode]!;
  String get errorProposalDescriptionRequired => {
        'cs': 'Popis vylepšení musí být uveden',
        'en': 'Improvement description must be stated'
      }[locale.languageCode]!;
  String get proposalHowLabel => {
        'cs': 'Jak (mi) toto vylepšení pomůže? Jednou větou.',
        'en': 'How is this improvement going to help me? With one sentence.'
      }[locale.languageCode]!;
  String get errorProposalHowRequired => {
        'cs': 'Důvod vylepšení musí být uveden',
        'en': 'The reason for improvement must be stated'
      }[locale.languageCode]!;
  String get suggestionInfo => {
        'cs':
            'Napište návrh, jak vylepšit aplikaci. Návrh bude odeslán při příští synchronizaci se serverem.',
        'en':
            'Propose an improvement of the app. The proposal will be sent with the next synchronisation with the server.'
      }[locale.languageCode]!;
  String get suggestionSaved => {
        'cs': 'Návrh uložen k odeslání.',
        'en': 'Proposal saved for sending.'
      }[locale.languageCode]!;
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
