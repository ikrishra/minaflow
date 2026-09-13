import Foundation

public struct AppLanguages {
    public static let all: [String] = [
        "English", "Hinglish", "Hindi", "Spanish", "French", "German", "Italian", "Portuguese",
        "Dutch", "Japanese", "Chinese", "Korean", "Russian", "Arabic", "Turkish", "Polish",
        "Swedish", "Norwegian", "Danish", "Finnish", "Greek", "Czech", "Romanian", "Hungarian",
        "Ukrainian", "Vietnamese", "Indonesian", "Thai", "Hebrew",
        "Bengali", "Tamil", "Telugu", "Marathi", "Urdu", "Gujarati", "Kannada", "Malayalam",
        "Punjabi", "Nepali", "Sanskrit", "Assamese", "Sinhala", "Sindhi",
        "Albanian", "Basque", "Belarusian", "Bosnian", "Breton", "Bulgarian", "Catalan",
        "Croatian", "Estonian", "Faroese", "Galician", "Icelandic", "Irish", "Latin",
        "Latvian", "Lithuanian", "Luxembourgish", "Macedonian", "Maltese", "Serbian",
        "Slovak", "Slovenian", "Welsh", "Yiddish",
        "Armenian", "Azerbaijani", "Georgian", "Kazakh", "Pashto", "Persian", "Tajik",
        "Tatar", "Turkmen", "Uzbek",
        "Burmese", "Cebuano", "Hawaiian", "Javanese", "Khmer", "Lao", "Malay", "Mongolian",
        "Sundanese", "Tagalog", "Tibetan",
        "Afrikaans", "Amharic", "Hausa", "Lingala", "Malagasy", "Maori", "Shona",
        "Somali", "Swahili", "Yoruba", "Zulu"
    ]

    public static func code(for languageName: String) -> String {
        switch languageName.lowercased() {
        case "auto": return ""
        case "hinglish": return ""
        case "english": return "en"
        case "hindi": return "hi"
        case "spanish": return "es"
        case "french": return "fr"
        case "german": return "de"
        case "italian": return "it"
        case "portuguese": return "pt"
        case "dutch": return "nl"
        case "japanese": return "ja"
        case "chinese": return "zh"
        case "korean": return "ko"
        case "russian": return "ru"
        case "arabic": return "ar"
        case "turkish": return "tr"
        case "polish": return "pl"
        case "swedish": return "sv"
        case "norwegian": return "no"
        case "danish": return "da"
        case "finnish": return "fi"
        case "greek": return "el"
        case "czech": return "cs"
        case "romanian": return "ro"
        case "hungarian": return "hu"
        case "ukrainian": return "uk"
        case "vietnamese": return "vi"
        case "indonesian": return "id"
        case "thai": return "th"
        case "hebrew": return "he"
        case "bengali": return "bn"
        case "tamil": return "ta"
        case "telugu": return "te"
        case "marathi": return "mr"
        case "urdu": return "ur"
        case "gujarati": return "gu"
        case "kannada": return "kn"
        case "malayalam": return "ml"
        case "punjabi": return "pa"
        case "nepali": return "ne"
        case "sanskrit": return "sa"
        case "assamese": return "as"
        case "sinhala": return "si"
        case "sindhi": return "sd"
        case "albanian": return "sq"
        case "basque": return "eu"
        case "belarusian": return "be"
        case "bosnian": return "bs"
        case "breton": return "br"
        case "bulgarian": return "bg"
        case "catalan": return "ca"
        case "croatian": return "hr"
        case "estonian": return "et"
        case "faroese": return "fo"
        case "galician": return "gl"
        case "icelandic": return "is"
        case "irish": return "ga"
        case "latin": return "la"
        case "latvian": return "lv"
        case "lithuanian": return "lt"
        case "luxembourgish": return "lb"
        case "macedonian": return "mk"
        case "maltese": return "mt"
        case "serbian": return "sr"
        case "slovak": return "sk"
        case "slovenian": return "sl"
        case "welsh": return "cy"
        case "yiddish": return "yi"
        case "armenian": return "hy"
        case "azerbaijani": return "az"
        case "georgian": return "ka"
        case "kazakh": return "kk"
        case "pashto": return "ps"
        case "persian": return "fa"
        case "tajik": return "tg"
        case "tatar": return "tt"
        case "turkmen": return "tk"
        case "uzbek": return "uz"
        case "burmese": return "my"
        case "cebuano": return "ceb"
        case "hawaiian": return "haw"
        case "javanese": return "jw"
        case "khmer": return "km"
        case "lao": return "lo"
        case "malay": return "ms"
        case "mongolian": return "mn"
        case "sundanese": return "su"
        case "tagalog": return "tl"
        case "tibetan": return "bo"
        case "afrikaans": return "af"
        case "amharic": return "am"
        case "hausa": return "ha"
        case "lingala": return "ln"
        case "malagasy": return "mg"
        case "maori": return "mi"
        case "shona": return "sn"
        case "somali": return "so"
        case "swahili": return "sw"
        case "yoruba": return "yo"
        case "zulu": return "zu"
        default: return "en"
        }
    }

    /// Native script acoustic priming prompts.
    /// Anchors Whisper's autoregressive decoder into the target alphabet/script,
    /// eliminating cross-language script hallucinations (e.g. Arabic/Urdu when speaking Hindi).
    public static func nativePrompt(for languageName: String) -> String {
        switch languageName.lowercased() {
        case "hi", "hindi":
            return "नमस्ते, कैसे हैं आप? आपसे मिलकर अच्छा लगा।"
        case "hinglish":
            return "Hinglish: नमस्ते, main theek hoon, aap kaise ho bhai?"
        case "es", "spanish":
            return "¡Hola, ¿cómo estás? Encantado de conocerte."
        case "fr", "french":
            return "Bonjour, comment allez-vous? Ravi de vous rencontrer."
        case "de", "german":
            return "Hallo, wie geht es dir? Schön dich kennenzulernen."
        case "it", "italian":
            return "Ciao, come stai? Piacere di conoscerti."
        case "pt", "portuguese":
            return "Olá, como você está? Prazer em conhecê-lo."
        case "ru", "russian":
            return "Здравствуйте, как ваши дела? Приятно познакомиться."
        case "ja", "japanese":
            return "こんにちは、お元気ですか？お会いできて嬉しいです。"
        case "zh", "chinese":
            return "你好，最近好吗？见到你很高兴。"
        case "ko", "korean":
            return "안녕하세요, 잘 지내시나요? 만나서 반갑습니다."
        case "ar", "arabic":
            return "مرحباً، كيف حالك؟ سعيد بلقائك."
        case "bn", "bengali":
            return "নমস্কার, কেমন আছেন? আপনার সাথে দেখা হয়ে ভালো লাগলো।"
        case "ta", "tamil":
            return "வணக்கம், எப்படி இருக்கிறீர்கள்? உங்களை சந்தித்ததில் மகிழ்ச்சி."
        case "te", "telugu":
            return "నమస్కారం, ఎలా ఉన్నారు? కలవడం చాలా సంతోషం."
        case "mr", "marathi":
            return "नमस्कार, तुम्ही कसे आहात? तुम्हाला भेटून आनंद झाला."
        case "gu", "gujarati":
            return "નમસ્તે, તમે કેમ છો? તમને મળીને આનંદ થયો."
        case "pa", "punjabi":
            return "ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ, ਤੁਸੀਂ ਕਿਵੇਂ ਹੋ?"
        case "nl", "dutch":
            return "Hallo, hoe gaat het? Aangenaam kennis te maken."
        case "tr", "turkish":
            return "Merhaba, nasılsın? Tanıştığımıza memnun oldum."
        case "pl", "polish":
            return "Cześć, jak się masz? Miło cię poznać."
        case "sv", "swedish":
            return "Hej, hur mår du? Trevligt att träffas."
        case "ur", "urdu":
            return "السلام علیکم، کیسے ہیں آپ؟ آپ سے مل کر خوشی ہوئی۔"
        default:
            return ""
        }
    }
}

