import 'package:filesize/filesize.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oko/data.dart';
import 'package:oko/utils.dart';
import 'package:sprintf/sprintf.dart';

const cs = 'cs';
const en = 'en';

class I18N {
  I18N(this.locale);

  final Locale locale;

  static I18N of(BuildContext context) {
    return Localizations.of(context, I18N);
  }

  String get appTitle => {cs: 'OKO', en: 'OKO'}[locale.languageCode]!;

  String appTitleWithVersion(String version) => '$appTitle v$version';

  String get help => {cs: 'Nápověda', en: 'Help'}[locale.languageCode]!;

  String get noLocationService => {
        cs: 'Služba zjišťování polohy není k dispozici.',
        en: 'Location service is not available.'
      }[locale.languageCode]!;

  String get noLocationPermissions => {
        cs: 'Aplikace nemá oprávnění zjišťovat polohu.',
        en: 'The app does not have the permission to acquire the location.'
      }[locale.languageCode]!;

  String get drawerPaired => {
        cs: 'Spárováno se serverem',
        en: 'Paired to server'
      }[locale.languageCode]!;

  String get drawerServerChecking => {
        cs: 'Zjišťuji dostupnost serveru',
        en: 'Checking server availability'
      }[locale.languageCode]!;

  String get drawerServerAvailable =>
      {cs: 'Server dostupný', en: 'Server available'}[locale.languageCode]!;

  String get drawerServerUnavailable =>
      {cs: 'Server nedostupný', en: 'Server unavailable'}[locale.languageCode]!;

  String get drawerNewVersion => {
        cs: 'Novější verze k dispozici',
        en: 'Newer version available'
      }[locale.languageCode]!;

  String get newVersionNotificationTitle => {
        cs: 'Nová verze aplikace k dispozici',
        en: 'New app version available'
      }[locale.languageCode]!;

  String newVersionNotificationText(String vCurrent, String vNew) => sprintf(
      {
        cs: 'K dispozici je novější verze %s. Nyní máte verzi %s. Chcete stáhnout novou verzi?',
        en: 'Newer version %s is available. Currently you have version %s. Do you want to download new version?'
      }[locale.languageCode]!,
      [vCurrent, vNew]);

  String get newVersionDismissalInfo => {
        cs: 'Pokud budete chtít novou verzi stáhnout později, můžete klepnout na indikátor dostupnosti serveru v levém menu hlavní obrazovky.',
        en: 'If you want to download the new version later, you can tap on the server availability indicator in the left menu of the main screen.'
      }[locale.languageCode]!;

  String get newVersionNotificationDownloadButton =>
      {cs: 'Stáhnout', en: 'Download'}[locale.languageCode]!;

  String get zoomIn => {cs: 'Přiblížit', en: 'Zoom in'}[locale.languageCode]!;

  String get zoomOut => {cs: 'Oddálit', en: 'Zoom out'}[locale.languageCode]!;

  String get resetRotation =>
      {cs: 'Resetovat rotaci', en: 'Reset rotation'}[locale.languageCode]!;

  String get serverAddressLabel =>
      {cs: 'Adresa serveru', en: 'Server address'}[locale.languageCode]!;

  String get errorAddressRequired => {
        cs: 'Adresa je vyžadována',
        en: 'Address is required'
      }[locale.languageCode]!;

  String get stop => {cs: 'Stop', en: 'Stop'}[locale.languageCode]!;

  String get scan => {cs: 'Naskenovat', en: 'Scan'}[locale.languageCode]!;

  String get nameLabel => {cs: 'Jméno', en: 'Name'}[locale.languageCode]!;

  String get descriptionLabel =>
      {cs: 'Popis', en: 'Description'}[locale.languageCode]!;

  String get errorNameRequired =>
      {cs: 'Jméno je vyžadováno', en: 'Name is required'}[locale.languageCode]!;

  String get dialogPair => {cs: 'Spárovat', en: 'Pair'}[locale.languageCode]!;

  String get handshakeExistsTitle =>
      {cs: 'Existující jméno', en: 'Existing name'}[locale.languageCode]!;

  String get handshakeExistsSubtitle => {
        cs: 'Spárovat s již existujícím jménem',
        en: 'Pair with already existing name'
      }[locale.languageCode]!;

  String get dialogCancel => {cs: 'Zrušit', en: 'Cancel'}[locale.languageCode]!;

  String get dialogConfirm =>
      {cs: 'Potvrdit', en: 'Confirm'}[locale.languageCode]!;

  String get dialogSave => {cs: 'Uložit', en: 'Save'}[locale.languageCode]!;

  String get invalidPairFields => {
        cs: 'Pole mají neplatné hodnoty',
        en: 'The fields have invalid values'
      }[locale.languageCode]!;

  String get ok => {cs: 'OK', en: 'OK'}[locale.languageCode]!;

  String get commErrorNameNotSupplied => {
        cs: 'Nebylo posláno žádné jméno.',
        en: 'No name was sent.'
      }[locale.languageCode]!;

  String get commErrorNameAlreadyExists => {
        cs: 'Poslané jméno již existuje.',
        en: 'The sent name already exists.'
      }[locale.languageCode]!;

  String get logPoiCurrentLocation => {
        cs: 'Zanést bod na aktuální poloze',
        en: 'Log point at current position'
      }[locale.languageCode]!;

  String get logPoiCrosshair => {
        cs: 'Zanést bod na zaměřovači',
        en: 'Log point at crosshair'
      }[locale.languageCode]!;

  String get locationContinuousButtonTooltip => {
        cs: 'Zapnout/vypnout získávání polohy',
        en: 'Turn location acquisition on/off',
      }[locale.languageCode]!;

  String get lockViewToLocationButtonTooltip => {
        cs: 'Zaměřit pohled na aktuální polohu',
        en: 'Center view to current location'
      }[locale.languageCode]!;

  String get addPoiDialogTitle =>
      {cs: 'Vlastnosti bodu', en: 'Point properties'}[locale.languageCode]!;

  String get useOfflineMap =>
      {cs: 'Použít offline mapu', en: 'Use offline map'}[locale.languageCode]!;

  String mapSizeWarning(int size) =>
      sprintf({cs: '%s', en: '%s'}[locale.languageCode]!, [filesize(size)]);

  String get downloading =>
      {cs: 'Stahování...', en: 'Downloading...'}[locale.languageCode]!;

  String get unpacking =>
      {cs: 'Rozbalování...', en: 'Unpacking...'}[locale.languageCode]!;

  String get doneMapSnackBar =>
      {cs: 'Hotovo!', en: 'Done!'}[locale.languageCode]!;

  String get download => {
        cs: 'Stáhnout ze serveru',
        en: 'Download from server'
      }[locale.languageCode]!;

  String get upload =>
      {cs: 'Nahrát na server', en: 'Upload to server'}[locale.languageCode]!;

  String get sync => {
        cs: 'Synchronizovat se serverem',
        en: 'Synchronize with server'
      }[locale.languageCode]!;

  String get syncSuccessful => {
        cs: 'Synchronizace úspěšná',
        en: 'Synchronization successful'
      }[locale.languageCode]!;

  String get pointCreated =>
      {cs: 'Bod vytvořen', en: 'Point created'}[locale.languageCode]!;

  String get pointCreatedFiltered => {
        cs: 'Bod vytvořen - skrytý kvůli aktivnímu filtru',
        en: 'Point created - hidden due to active filter'
      }[locale.languageCode]!;

  String get stopNavigationButton =>
      {cs: 'Zastavit navigaci', en: 'Stop navigation'}[locale.languageCode]!;

  String get navigateToButton =>
      {cs: 'Navigovat', en: 'Navigate'}[locale.languageCode]!;

  String get delete => {cs: 'Smazat', en: 'Delete'}[locale.languageCode]!;

  String get undelete => {cs: 'Odsmazat', en: 'Undelete'}[locale.languageCode]!;

  String get distance =>
      {cs: 'Vzdálenost', en: 'Distance'}[locale.languageCode]!;

  String get bearing => {cs: 'Azimut', en: 'Bearing'}[locale.languageCode]!;

  String get relativeBearing =>
      {cs: 'Rel. azimut', en: 'Rel. bearing'}[locale.languageCode]!;

  String get yes => {cs: 'Ano', en: 'Yes'}[locale.languageCode]!;

  String get no => {cs: 'Ne', en: 'No'}[locale.languageCode]!;

  String get aboutToDeleteLocalFeature => {
        cs: 'Opravdu smazat lokální objekt? Tuto operaci nelze vrátit.',
        en: 'Really delete local feature? This operation cannot be undone.'
      }[locale.languageCode]!;

  String get aboutToRevertGlobalFeature => {
        cs: 'Opravdu vrátit původní data k tomuto objektu? Tuto operaci nelze vrátit.',
        en: 'Really revert to the original data for this feature? This operation cannot be undone.'
      }[locale.languageCode]!;

  String Function(int n) get nPois => (int n) {
        if (n < 0) {
          throw Exception('negative number');
        }
        if (n == 1) {
          return sprintf(
              {cs: '1 bod', en: '1 point'}[locale.languageCode]!, [n]);
        }
        if (n < 5) {
          return sprintf(
              {cs: '%d body', en: '%d points'}[locale.languageCode]!, [n]);
        }
        return sprintf(
            {cs: '%d bodů', en: '%d points'}[locale.languageCode]!, [n]);
      };

  String get centerViewInfoButton =>
      {cs: 'Vycentrovat mapu', en: 'Center map'}[locale.languageCode]!;

  String get poiListTitle =>
      {cs: 'Seznam bodů', en: 'Point list'}[locale.languageCode]!;

  String get userListTitle =>
      {cs: 'Seznam uživatelů', en: 'User list'}[locale.languageCode]!;

  String get infoOnly =>
      {cs: 'Pouze informativní', en: 'Informative only'}[locale.languageCode]!;

  String get categoryTitle =>
      {cs: 'Kategorie', en: 'Category'}[locale.languageCode]!;

  String Function(PointCategory x) get category =>
      ((PointCategory category) => {
            PointCategory.general.name: {cs: 'Obecné', en: 'General'},
            PointCategory.camp.name: {cs: 'Tábor', en: 'Camp'},
            PointCategory.animal.name: {cs: 'Zvíře', en: 'Animal'},
            PointCategory.holySite.name: {
              cs: 'Posvátné místo',
              en: 'Holy site'
            },
            PointCategory.treasure.name: {cs: 'Poklad', en: 'Treasure'},
            PointCategory.unknown.name: {cs: '???', en: '???'}
          }[category.name]![locale.languageCode]!);

  String get edit => {cs: 'Upravit', en: 'Edit'}[locale.languageCode]!;

  String get editPoint =>
      {cs: 'Upravit bod', en: 'Edit point'}[locale.languageCode]!;

  String get newPoint =>
      {cs: 'Nový bod', en: 'New point'}[locale.languageCode]!;

  String get revert => {cs: 'Vrátit', en: 'Revert'}[locale.languageCode]!;

  String get position => {cs: 'Pozice', en: 'Position'}[locale.languageCode]!;

  String get metadata => {cs: 'Metadata', en: 'Metadata'}[locale.languageCode]!;

  String get owner => {cs: 'Vlastník', en: 'Owner'}[locale.languageCode]!;

  String get me => {cs: 'já', en: 'me'}[locale.languageCode]!;

  String get toFilter => {cs: 'Filtrovat', en: 'Filter'}[locale.languageCode]!;

  String get applyFilterToMap => {
        cs: 'Použít současný filtr na mapě',
        en: 'Use current filter on map'
      }[locale.languageCode]!;

  String get filterByOwner => {
        cs: 'Filtrovat podle vlastníka',
        en: 'Filter by owner'
      }[locale.languageCode]!;

  String get filterByCategory => {
        cs: 'Filtrovat podle kategorie',
        en: 'Filter by category'
      }[locale.languageCode]!;

  String get filterByAttributes => {
        cs: 'Filtrovat podle vlastností',
        en: 'Filter by attributes'
      }[locale.languageCode]!;

  String get filterByEditState => {
        cs: 'Filtrovat podle stavu úprav',
        en: 'Filter by edit state'
      }[locale.languageCode]!;

  String get filterByText =>
      {cs: 'Filtrovat podle textu', en: 'Filter by text'}[locale.languageCode]!;

  String get clearFilter =>
      {cs: 'Zrušit filtr', en: 'Clear filter'}[locale.languageCode]!;

  String get filteredOut =>
      {cs: 'skryto filtrem', en: 'hidden by filter'}[locale.languageCode]!;

  String get downloadConfirm =>
      {cs: 'Opravdu stáhnout?', en: 'Really download?'}[locale.languageCode]!;

  String get downloadConfirmDetail => {
        cs: 'Pouhé stažení nezapíše lokální změny na server. Nově vytvořené body zůstanou, ale úpravy na bodech ze serveru budou ztraceny.',
        en: 'Mere download does not write local changes to the server. Newly created points will be kept, but edits to points from the server will be lost.'
      }[locale.languageCode]!;

  String get downloaded =>
      {cs: 'Staženo', en: 'Downloaded'}[locale.languageCode]!;

  String get dismiss => {cs: 'Zavřít', en: 'Dismiss'}[locale.languageCode]!;

  String get error => {cs: 'Chyba', en: 'Error'}[locale.languageCode]!;

  String get serverUnavailable =>
      {cs: 'Server nedostupný', en: 'Server unavailable'}[locale.languageCode]!;

  String get pairing => {cs: 'Párování', en: 'Pairing'}[locale.languageCode]!;

  String userAlreadyExists(String user) => sprintf(
      {
        cs: 'Uživatel "%s" již existuje.',
        en: 'User "%s" already exists.'
      }[locale.languageCode]!,
      [user]);

  String userDoesNotExist(String user) => sprintf(
      {
        cs: 'Uživatel "%s" neexistuje.',
        en: 'User "%s" does not exist.'
      }[locale.languageCode]!,
      [user]);

  String get badRequest =>
      {cs: 'Chybný dotaz', en: 'Bad request'}[locale.languageCode]!;

  String usernameForbidden(String username) => sprintf(
      {
        cs: 'Uživatelské jméno "%s" je zakázané.',
        en: 'Username "%s" is forbidden.'
      }[locale.languageCode]!,
      [username]);

  String get internalServerError => {
        cs: 'Interní chyba serveru',
        en: 'Internal server error'
      }[locale.languageCode]!;

  String get requestRefused =>
      {cs: 'Požadavek zamítnut.', en: 'Request refused.'}[locale.languageCode]!;

  String unexpectedStatusCode(int code) => sprintf(
      {
        cs: 'Neočekávaný stavový kód: %d',
        en: 'Unexpected status code: %d'
      }[locale.languageCode]!,
      [code]);

  String get allNothing =>
      {cs: 'Vše/nic', en: 'All/nothing'}[locale.languageCode]!;

  String get invert => {cs: 'Invertovat', en: 'Invert'}[locale.languageCode]!;

  String get reset =>
      {cs: 'Resetovat aplikaci', en: 'Reset app'}[locale.languageCode]!;

  String get resetInfo => {
        cs: 'Zruší párování a smaže veškerá data. NEVRATNÁ OPERACE. Aktivujete dlouhým stiskem.',
        en: 'Breaks pairing and deletes all data. IRREVERSIBLE OPERATION. Activate by long press.'
      }[locale.languageCode]!;

  String get resetConfirm => {
        cs: 'Opravdu resetovat aplikaci?',
        en: 'Really reset the app?'
      }[locale.languageCode]!;

  String get resetDone =>
      {cs: 'Vyresetováno.', en: 'Reset done.'}[locale.languageCode]!;

  String get attributes =>
      {cs: 'Vlastnosti', en: 'Attributes'}[locale.languageCode]!;

  String get noAttributes =>
      {cs: '<žádné vlastnosti>', en: '<no attributes>'}[locale.languageCode]!;

  String Function(PointAttribute x) get attribute =>
      ((PointAttribute attribute) => {
            PointAttribute.important.name: {cs: 'Důležité', en: 'Important'},
            PointAttribute.cleaned.name: {cs: 'Uklizeno', en: 'Cleaned up'},
          }[attribute.name]![locale.languageCode]!);

  String get intersection =>
      {cs: 'průnik', en: 'intersection'}[locale.languageCode]!;

  String get exact => {cs: 'shoda', en: 'match'}[locale.languageCode]!;

  String get close => {cs: 'Zavřít', en: 'Close'}[locale.languageCode]!;

  String get renderBaseMap => {
        cs: 'Vykreslovat podkladovou mapu',
        en: 'Draw base map'
      }[locale.languageCode]!;

  String get newState => {cs: 'Nový', en: 'New'}[locale.languageCode]!;

  String get editedState =>
      {cs: 'Upravený', en: 'Edited'}[locale.languageCode]!;

  String get deletedState =>
      {cs: 'Ke smazání', en: 'To be deleted'}[locale.languageCode]!;

  String get editedDeletedState => {
        cs: 'Upravený + ke smazání',
        en: 'Edited + to be deleted'
      }[locale.languageCode]!;

  String get pristineState =>
      {cs: 'Nedotčený', en: 'Pristine'}[locale.languageCode]!;

  String get anyState =>
      {cs: 'Jakýkoliv', en: 'Any state'}[locale.languageCode]!;

  String get color => {cs: 'Barva', en: 'Colour'}[locale.languageCode]!;

  String get colorFill =>
      {cs: 'Barva výplně', en: 'Fill colour'}[locale.languageCode]!;

  String get deadline => {
        cs: 'Automaticky smazat',
        en: 'Automatically delete'
      }[locale.languageCode]!;

  String get chooseTime =>
      {cs: 'Vyberte čas', en: 'Choose a time'}[locale.languageCode]!;

  String get dialogNext => {cs: 'Dále', en: 'Next'}[locale.languageCode]!;

  String get dialogBack => {cs: 'Zpět', en: 'Back'}[locale.languageCode]!;

  String get managePhotos =>
      {cs: 'Spravovat fotky', en: 'Manage photos'}[locale.languageCode]!;

  String get takePhoto =>
      {cs: 'Vyfotit', en: 'Take a photo'}[locale.languageCode]!;

  String get pickPhoto =>
      {cs: 'Vybrat fotku', en: 'Pick a photo'}[locale.languageCode]!;

  String get deletedPhoto =>
      {cs: 'Smazaná fotka', en: 'Deleted photo'}[locale.languageCode]!;

  String get deletedPhotoDetail => {
        cs: 'Bude smazána ze serveru při příští synchronizaci',
        en: 'Will be deleted from the server upon next synchronization'
      }[locale.languageCode]!;

  String get addedPhoto =>
      {cs: 'Přidaná fotka', en: 'Added photo'}[locale.languageCode]!;

  String get addedPhotoDetail => {
        cs: 'Bude nahrána na server při příští synchronizaci',
        en: 'Will be uploaded to server upon next synchronization'
      }[locale.languageCode]!;

  DateFormat get dateFormat => {
        cs: DateFormat('d.M. HH:mm', cs),
        en: DateFormat('M/d HH:mm', en),
      }[locale.languageCode]!;

  String get proposeImprovement => {
        cs: 'Navrhnout vylepšení aplikace',
        en: 'Propose app improvement'
      }[locale.languageCode]!;

  String get proposalDescriptionLabel => {
        cs: 'Popis vylepšení',
        en: 'Improvement description'
      }[locale.languageCode]!;

  String get errorProposalDescriptionRequired => {
        cs: 'Popis vylepšení musí být uveden',
        en: 'Improvement description must be stated'
      }[locale.languageCode]!;

  String get proposalHowLabel => {
        cs: 'Jak (mi) toto vylepšení pomůže? Jednou větou.',
        en: 'How is this improvement going to help me? With one sentence.'
      }[locale.languageCode]!;

  String get errorProposalHowRequired => {
        cs: 'Důvod vylepšení musí být uveden',
        en: 'The reason for improvement must be stated'
      }[locale.languageCode]!;

  String get suggestionInfo => {
        cs: 'Napište návrh, jak vylepšit aplikaci. Návrh bude odeslán při příští synchronizaci se serverem.',
        en: 'Propose an improvement of the app. The proposal will be sent with the next synchronisation with the server.'
      }[locale.languageCode]!;

  String get suggestionSaved => {
        cs: 'Návrh uložen k odeslání.',
        en: 'Proposal saved for sending.'
      }[locale.languageCode]!;

  String get clearButtonTooltip =>
      {cs: 'Vymazat', en: 'Clear'}[locale.languageCode]!;

  String get addToPathCreation => {
        cs: 'Zařadit bod do vytváření cesty',
        en: 'Add point to path creation'
      }[locale.languageCode]!;

  String get removeFromPathCreation => {
        cs: 'Odebrat bod zz vytváření cesty',
        en: 'Remove point to path creation'
      }[locale.languageCode]!;

  String get goPathCreation => {
        cs: 'Přejít k vytvoření cesty',
        en: 'Go to path creation'
      }[locale.languageCode]!;

  String get creatingPath => {
        cs: 'Tvoření/úprava cesty',
        en: 'Creating/editing path'
      }[locale.languageCode]!;

  String get creatingPathHelpAddingNodes => {
        cs: 'Klepnutím do mapy nebo na existující bod přidáte uzel cesty/polygonu.',
        en: 'You can add a node to the path/polygon by tapping on map or an existing point.'
      }[locale.languageCode]!;

  String get creatingPathHelpNodes => {
        cs: 'Toto je uzel ("roh" cesty). Přemístíte ho tažením. Dlouhým podržením ho smažete.',
        en: 'This is a node (a "corner" of the path). Move it by dragging. Long press on it deletes it.'
      }[locale.languageCode]!;

  String get creatingPathHelpMidpoints => {
        cs: 'Klepnutím do mapy nebo na existující bod přidáte uzel cesty/polygonu.',
        en: 'This is a midpoint of a path segment. Dragging it creates a new node in between the adjacent nodes.'
      }[locale.languageCode]!;

  String get creatingPathHelpClosePath => {
        cs: 'Toto cestu uzavře, čímž se z ní stane polygon.',
        en: 'This closes the path which turns it into a polygon.'
      }[locale.languageCode]!;

  String get creatingPathHelpSettings => {
        cs: 'Toto cestu uzavře, čímž se z ní stane polygon.',
        en: 'This opens the settings of the path/polygon. You can finish path/polygon creation (save it) there.'
      }[locale.languageCode]!;

  String get createPoly => {
        cs: 'Vytvořit cestu/polygon',
        en: 'Create path/polygon'
      }[locale.languageCode]!;

  String get createPathSubtitle =>
      {cs: 'z bodů', en: 'out of points'}[locale.languageCode]!;

  String get pickAPoint =>
      {cs: 'Vyberte bod', en: 'Pick a point'}[locale.languageCode]!;

  String get pathSettings =>
      {cs: 'Nastavení', en: 'Settings'}[locale.languageCode]!;

  String get orderPointsByName =>
      {cs: 'Seřadit dle názvu', en: 'Order by name'}[locale.languageCode]!;

  String get closePath =>
      {cs: 'Uzavřít cestu', en: 'Close path'}[locale.languageCode]!;

  String get closePathSubtitle => {
        cs: 'Propojit první a poslední bod => polygon',
        en: 'Connect first and last point => polygon'
      }[locale.languageCode]!;

  String get pathCreationConfirm =>
      {cs: 'Vytvořit', en: 'Create'}[locale.languageCode]!;

  String get pathCreateCheckTitle =>
      {cs: 'Vytvořit?', en: 'Create?'}[locale.languageCode]!;

  String Function(int n) get pathCreatedFrom => ((int n) {
        switch (locale.languageCode) {
          case cs:
            return 'Cesta bude vytvořena z $n bodů.';
          case en:
            return 'The path will be created from $n points.';
        }
        throw IllegalStateException(
            'Invalid language code: ${locale.languageCode}');
      });

  String Function(int total) get allPointsToBeDeleted => ((int total) {
        switch (locale.languageCode) {
          case cs:
            if (total == 0) {
              return 'Žádný bod nebude označen ke smazání.';
            } else if (total < 5) {
              return 'Všechny $total body budou označeny ke smazání';
            } else {
              return 'Všech $total bodů bude označeno ke smazání';
            }
          case en:
            if (total == 0) {
              return 'No point will be marked for deletion.';
            } else {
              return 'All $total points will be marked for deletion';
            }
        }
        throw IllegalStateException(
            'Invalid language code: ${locale.languageCode}');
      });

  String Function(int total) get checkedPointsToBeDeleted => ((int total) {
        switch (locale.languageCode) {
          case cs:
            if (total == 0) {
              return 'Žádný bod nebude označen ke smazání.';
            } else if (total < 5) {
              return '$total body budou označeny ke smazání';
            } else {
              return '$total bodů bude označeno ke smazání';
            }
          case en:
            if (total == 0) {
              return 'No point will be marked for deletion.';
            } else {
              return '$total points will be marked for deletion';
            }
        }
        throw IllegalStateException(
            'Invalid language code: ${locale.languageCode}');
      });

  String get ofWhich =>
      {cs: ', z toho', en: ', of which'}[locale.languageCode]!;

  String Function(int n) get pathOfWhichLocal => ((int n) {
        switch (locale.languageCode) {
          case cs:
            if (n == 0) {
              return 'žádný bod není lokální';
            } else if (n < 5) {
              return '$n jsou lokální a tedy budou smazány zcela';
            } else {
              return '$n je lokálních a tedy budou smazány zcela';
            }
          case en:
            if (n == 0) {
              return 'no point is local';
            } else if (n == 1) {
              return '$n is local and therefore will be deleted completely';
            } else {
              return '$n are local and therefore will be deleted completely';
            }
        }
        throw IllegalStateException(
            'Invalid language code: ${locale.languageCode}');
      });

  String Function(int n) get pathOfWhichSystem => ((int n) {
        switch (locale.languageCode) {
          case cs:
            if (n == 0) {
              return 'žádný bod není systémový';
            } else if (n < 5) {
              return '$n jsou systémové a tedy nebudou smazány';
            } else {
              return '$n je systémových a tedy nebudou smazány';
            }
          case en:
            if (n == 0) {
              return 'no point is system';
            } else if (n == 1) {
              return '$n is system and therefore will not be deleted';
            } else {
              return '$n are system and therefore will not be deleted';
            }
        }
        throw IllegalStateException(
            'Invalid language code: ${locale.languageCode}');
      });

  String get polyCreated => {
        cs: 'Cesta/polygon vytvořen(a)',
        en: 'Path/polygon created'
      }[locale.languageCode]!;

  String get pickPolyNavTarget => {
    cs: 'Vyberte bod pro navigaci',
    en: 'Pick a point for navigation'
  }[locale.languageCode]!;

  String get centroid => {
    cs: 'Vyberte bod pro navigaci',
    en: 'Centroid (average)'
  }[locale.languageCode]!;

  String get nodeNo => {
    cs: 'Vyberte bod pro navigaci',
    en: 'Node No.:'
  }[locale.languageCode]!;
}

class I18NDelegate extends LocalizationsDelegate<I18N> {
  const I18NDelegate();

  @override
  bool isSupported(Locale locale) => [en, cs].contains(locale.languageCode);

  @override
  Future<I18N> load(Locale locale) => SynchronousFuture<I18N>(I18N(locale));

  @override
  bool shouldReload(LocalizationsDelegate<I18N> old) => false;
}
