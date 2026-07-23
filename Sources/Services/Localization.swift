import Foundation
import Combine

/// Customer-facing language toggle for the kiosk. The form defaults to
/// English; a button in the top bar lets the customer switch to Mexican
/// Spanish for the duration of their sign-in. The language resets back to
/// English whenever the form returns to the Select Category screen so the
/// next customer always starts in English.
@MainActor
final class Localization: ObservableObject {

    // Singleton — used from non-View contexts (model display-name accessors,
    // Bootstrap, etc.). SwiftUI views should still pull it from the env via
    // `@EnvironmentObject` so they re-render on language changes.
    static let shared = Localization()

    /// Mirror of `language` for callers in non-MainActor contexts (Codable
    /// model display-name accessors). Updated by the published setter, so it
    /// always reflects the latest user choice. Reads/writes are single-word
    /// enum assignments and only occur on the main thread in practice, so
    /// `nonisolated(unsafe)` is sufficient.
    nonisolated(unsafe) private static var _currentLanguage: Language = .english

    @Published private(set) var language: Language = .english {
        didSet { Self._currentLanguage = language }
    }

    enum Language { case english, spanish }

    /// Toggle to the opposite language.
    func toggle() {
        language = (language == .english) ? .spanish : .english
    }

    /// Reset to English. Called when the form resets between customers.
    func reset() {
        if language != .english { language = .english }
    }

    /// Look up the translated string for a given key.
    func t(_ key: LocKey) -> String {
        switch language {
        case .english: return key.en
        case .spanish: return key.es
        }
    }

    /// Static, nonisolated accessor for non-View contexts (model display
    /// names, Codable conformances, etc.). Reads the mirrored static.
    nonisolated static func t(_ key: LocKey) -> String {
        switch _currentLanguage {
        case .english: return key.en
        case .spanish: return key.es
        }
    }

    /// "Uploading consent {n} of {m}…" / "Subiendo consentimiento {n} de {m}…"
    func tUploadingConsent(_ n: Int, of m: Int) -> String {
        switch language {
        case .english: return "Uploading consent \(n) of \(m)…"
        case .spanish: return "Subiendo consentimiento \(n) de \(m)…"
        }
    }
}

// MARK: - Translation Keys

/// Every translatable user-facing string lives here. Adding a new string is
/// a four-step process: declare a case, give it `en` and `es` translations,
/// and reference it from the call site via `loc.t(.theKey)`.
enum LocKey {

    // ── Navigation / common buttons ──
    case back
    case next
    case continueAction
    case done
    case skip
    case saveAndSend
    case submitting
    case checking
    case loading
    case clear

    // ── SelectCategoryPage ──
    case howCanWeHelp
    case tapService
    case vitaminInjection
    case drugOrAlcoholScreen
    case dnaTest
    case labTest

    // ── PersonInfoPage ──
    case tellUsAboutYourself
    case phoneNumber
    case dateOfBirth
    case tapToSelectDate
    case offlineNoticeShort

    // ── FullPersonInfoPage ──
    case welcomeFewDetails
    case firstName
    case middleOptional
    case lastName
    case email
    case gender
    case male
    case female

    // ── AddressPage ──
    case yourAddress
    case streetAddress
    case zipCode

    // ── Choose pages ──
    case chooseInjection
    case chooseDnaTests
    case chooseLabTest
    case chooseSpecimenTypes
    case tellUsMore
    case whoSentYou
    case enterName
    case chainOfCustody
    case haveCocForm
    case dontHaveCocForm
    case notSure

    // ── StdPage ──
    case stdHivTesting
    case plans
    case individualOptions

    // ── ConsentPage ──
    case optional
    case required
    case signHereToAgree
    case optionalConsentHint
    case offlineWillSync
    case pleaseSignBeforeContinuing
    case couldNotReadSignature
    case consentPDFUnavailable
    case missingCustomerDetails
    case consentCustomerInfo
    case consentEmail
    case consentMarketing
    case consentPhone
    case consentVitamin
    case ofCounter   // "X of Y" → "X de Y"

    // ── ConsentPage submit phase labels (shown on the disabled button) ──
    case submitPhaseCreatingAccount
    case submitPhaseUploadingConsentTemplate   // "Uploading consent {n} of {m}…" — see tUploadingConsent
    case submitPhaseSavingPrefs
    case submitPhaseSavingAppointment

    // ── FinishPage ──
    case allSet
    case signedInSeat
    case offlineQueuedNotice    // appended " (N pending)" by the call site

    // ── EmptyCatalogNotice ──
    case catalogUnavailable
    case catalogUnavailableDetail
    case catalogAuthFailure
    case catalogAuthFailureDetail
    case catalogServerError
    case catalogServerErrorDetail
    case catalogRetry

    // ── Top bar language-toggle button ──
    // The button label always names the OTHER language (the one you'd switch
    // TO), so when English is active we display "Español", and vice versa.
    case languageToggleLabel

    // MARK: - English

    var en: String {
        switch self {
        case .back:                       return "Back"
        case .next:                       return "Next"
        case .continueAction:             return "Continue"
        case .done:                       return "Done"
        case .skip:                       return "Skip"
        case .saveAndSend:                return "Save & Send"
        case .submitting:                 return "Submitting…"
        case .checking:                   return "Checking…"
        case .loading:                    return "Loading…"
        case .clear:                      return "Clear"

        case .howCanWeHelp:               return "How can we help today?"
        case .tapService:                 return "Tap the service you're here for."
        case .vitaminInjection:           return "Vitamin Injection"
        case .drugOrAlcoholScreen:        return "Drug or Alcohol Screen"
        case .dnaTest:                    return "DNA Test"
        case .labTest:                    return "Lab Test"

        case .tellUsAboutYourself:        return "Tell us about yourself"
        case .phoneNumber:                return "Phone number"
        case .dateOfBirth:                return "Date of birth"
        case .tapToSelectDate:            return "Tap to select your date of birth"
        case .offlineNoticeShort:
            return "You're offline — your sign-in will be saved and sent automatically when internet returns."

        case .welcomeFewDetails:          return "Welcome! A few details"
        case .firstName:                  return "First name"
        case .middleOptional:             return "Middle (optional)"
        case .lastName:                   return "Last name"
        case .email:                      return "Email"
        case .gender:                     return "Gender"
        case .male:                       return "Male"
        case .female:                     return "Female"

        case .yourAddress:                return "Your address"
        case .streetAddress:              return "Street address"
        case .zipCode:                    return "ZIP code"

        case .chooseInjection:            return "Choose an injection"
        case .chooseDnaTests:             return "Choose DNA test(s)"
        case .chooseLabTest:              return "Choose a lab test"
        case .chooseSpecimenTypes:        return "Choose specimen type(s)"
        case .tellUsMore:                 return "Tell us more"
        case .whoSentYou:                 return "Who sent you? (Employer / School / Court)"
        case .enterName:                  return "Enter name"
        case .chainOfCustody:             return "Chain-of-custody paperwork"
        case .haveCocForm:                return "I have a chain-of-custody form"
        case .dontHaveCocForm:            return "I do not have a chain-of-custody form"
        case .notSure:                    return "I'm not sure"

        case .stdHivTesting:              return "STD / HIV Testing"
        case .plans:                      return "Plans"
        case .individualOptions:          return "Individual Options"

        case .optional:                   return "Optional"
        case .required:                   return "Required"
        case .signHereToAgree:            return "Sign here to agree"
        case .optionalConsentHint:
            return "This consent is optional. Sign to accept, or tap \"Skip\" to decline."
        case .offlineWillSync:            return "Offline — will sync automatically"
        case .pleaseSignBeforeContinuing: return "Please sign before continuing."
        case .couldNotReadSignature:      return "Could not read signature."
        case .consentPDFUnavailable:
            return "Consent PDF not available. Reconnect briefly to download it."
        case .missingCustomerDetails:     return "Missing customer details."
        case .consentCustomerInfo:        return "Customer Info Release and Consent"
        case .consentEmail:               return "Email Consent"
        case .consentMarketing:           return "Marketing Consent"
        case .consentPhone:               return "Phone & SMS Consent"
        case .consentVitamin:             return "Vitamin Injection Consent"
        case .ofCounter:                  return "of"

        case .submitPhaseCreatingAccount:        return "Creating account…"
        case .submitPhaseUploadingConsentTemplate: return "Uploading consent…"
        case .submitPhaseSavingPrefs:            return "Saving preferences…"
        case .submitPhaseSavingAppointment:      return "Saving sign-in…"

        case .allSet:                     return "All set!"
        case .signedInSeat:               return "You're signed in — please have a seat."
        case .offlineQueuedNotice:
            return "Your sign-in is saved and will sync automatically when the network returns"

        case .catalogUnavailable:         return "Service catalog unavailable"
        case .catalogUnavailableDetail:
            return "Connect this iPad to the Internet at least once to load the service list. The sign-in app stays usable afterward — even offline."
        case .catalogAuthFailure:         return "App update required"
        case .catalogAuthFailureDetail:
            return "The server rejected this app's access key — this build is out of date. Please ask staff to update the ALTN Sign-in app on this iPad."
        case .catalogServerError:         return "Couldn't load the service list"
        case .catalogServerErrorDetail:
            return "The server had a problem answering. Please try again in a moment."
        case .catalogRetry:               return "Retry"

        case .languageToggleLabel:        return "Español"
        }
    }

    // MARK: - Spanish (Mexican)

    var es: String {
        switch self {
        case .back:                       return "Atrás"
        case .next:                       return "Siguiente"
        case .continueAction:             return "Continuar"
        case .done:                       return "Listo"
        case .skip:                       return "Omitir"
        case .saveAndSend:                return "Guardar y enviar"
        case .submitting:                 return "Enviando…"
        case .checking:                   return "Verificando…"
        case .loading:                    return "Cargando…"
        case .clear:                      return "Borrar"

        case .howCanWeHelp:               return "¿En qué podemos ayudarle hoy?"
        case .tapService:                 return "Toque el servicio que necesita."
        case .vitaminInjection:           return "Inyección de Vitaminas"
        case .drugOrAlcoholScreen:        return "Prueba de Drogas o Alcohol"
        case .dnaTest:                    return "Prueba de ADN"
        case .labTest:                    return "Examen de Laboratorio"

        case .tellUsAboutYourself:        return "Cuéntenos sobre usted"
        case .phoneNumber:                return "Número de teléfono"
        case .dateOfBirth:                return "Fecha de nacimiento"
        case .tapToSelectDate:            return "Toque para seleccionar su fecha de nacimiento"
        case .offlineNoticeShort:
            return "Está sin conexión — su registro se guardará y se enviará automáticamente cuando regrese el internet."

        case .welcomeFewDetails:          return "¡Bienvenido! Unos cuantos datos"
        case .firstName:                  return "Nombre"
        case .middleOptional:             return "Segundo nombre (opcional)"
        case .lastName:                   return "Apellido"
        case .email:                      return "Correo electrónico"
        case .gender:                     return "Género"
        case .male:                       return "Hombre"
        case .female:                     return "Mujer"

        case .yourAddress:                return "Su dirección"
        case .streetAddress:              return "Calle y número"
        case .zipCode:                    return "Código postal"

        case .chooseInjection:            return "Elija una inyección"
        case .chooseDnaTests:             return "Elija prueba(s) de ADN"
        case .chooseLabTest:              return "Elija un examen de laboratorio"
        case .chooseSpecimenTypes:        return "Elija tipo(s) de muestra"
        case .tellUsMore:                 return "Cuéntenos más"
        case .whoSentYou:                 return "¿Quién lo envió? (Empleador / Escuela / Corte)"
        case .enterName:                  return "Escriba el nombre"
        case .chainOfCustody:             return "Documento de cadena de custodia"
        case .haveCocForm:                return "Tengo formulario de cadena de custodia"
        case .dontHaveCocForm:            return "No tengo formulario de cadena de custodia"
        case .notSure:                    return "No estoy seguro"

        case .stdHivTesting:              return "Pruebas de ETS / VIH"
        case .plans:                      return "Planes"
        case .individualOptions:          return "Opciones individuales"

        case .optional:                   return "Opcional"
        case .required:                   return "Requerido"
        case .signHereToAgree:            return "Firme aquí para aceptar"
        case .optionalConsentHint:
            return "Este consentimiento es opcional. Firme para aceptar, o toque \"Omitir\" para rechazarlo."
        case .offlineWillSync:            return "Sin conexión — se sincronizará automáticamente"
        case .pleaseSignBeforeContinuing: return "Por favor firme antes de continuar."
        case .couldNotReadSignature:      return "No se pudo leer la firma."
        case .consentPDFUnavailable:
            return "El documento de consentimiento no está disponible. Conéctese brevemente para descargarlo."
        case .missingCustomerDetails:     return "Faltan datos del cliente."
        case .consentCustomerInfo:        return "Consentimiento y Divulgación de Información del Cliente"
        case .consentEmail:               return "Consentimiento de Correo Electrónico"
        case .consentMarketing:           return "Consentimiento de Mercadotecnia"
        case .consentPhone:               return "Consentimiento de Teléfono y SMS"
        case .consentVitamin:             return "Consentimiento de Inyección de Vitaminas"
        case .ofCounter:                  return "de"

        case .submitPhaseCreatingAccount:        return "Creando cuenta…"
        case .submitPhaseUploadingConsentTemplate: return "Subiendo consentimiento…"
        case .submitPhaseSavingPrefs:            return "Guardando preferencias…"
        case .submitPhaseSavingAppointment:      return "Guardando registro…"

        case .allSet:                     return "¡Todo listo!"
        case .signedInSeat:               return "Ya está registrado — por favor tome asiento."
        case .offlineQueuedNotice:
            return "Su registro se guardó y se sincronizará automáticamente cuando regrese el internet"

        case .catalogUnavailable:         return "Catálogo de servicios no disponible"
        case .catalogUnavailableDetail:
            return "Conecte este iPad a Internet al menos una vez para cargar la lista de servicios. La app de registro seguirá funcionando después — incluso sin conexión."
        case .catalogAuthFailure:         return "Se requiere actualizar la app"
        case .catalogAuthFailureDetail:
            return "El servidor rechazó la clave de acceso de esta app — esta versión está desactualizada. Pida al personal que actualice la app de registro ALTN en este iPad."
        case .catalogServerError:         return "No se pudo cargar la lista de servicios"
        case .catalogServerErrorDetail:
            return "El servidor tuvo un problema al responder. Por favor intente de nuevo en un momento."
        case .catalogRetry:               return "Reintentar"

        case .languageToggleLabel:        return "English"
        }
    }
}
