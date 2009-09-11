#* Website User Plugin
#
# Records users' IP address and language
#
# @package KISSmetrics
#/
#*
# @see KMCore
#/
require 'kissmetrics'
# A class that records the source IP address of incoming requests and tries to determine the user's language.
#
# Global properties:
# <ul>
#  <li><kbd>ip</kbd> (string) - the IP address from which the current request originates</li>
#  <li><kbd>langauge</kbd> (string) - the user's language as determined by the HTTP_ACCEPT_LANGUAGE request header</li>
# </ul>
# @uses KMCore
# @package KISSmetrics
#/
class KMWebsiteUser
  class << self
    def init
      begin
        km = KMCore.instance
      
        if KMServer['REMOTE_ADDR']
          km.assign('ip', KMServer['REMOTE_ADDR'], KM_IP_ADDRESS)
        end
        if KMServer['HTTP_ACCEPT_LANGUAGE']
          km.assign('language', KMWebsiteUser::language_name(KMServer['HTTP_ACCEPT_LANGUAGE']), KM_STRING)
        end
      rescue Exception => e
        if KMCore.instance
          begin; KMCore.instance.log_error(e.message); rescue; end
        end
      end
    end

    #*
    # Returns the name of a language based on a two letter country code.
    # @param string $code A two letter country code
    # @return string  country name
    #/
    def language_name(code)
      return nil unless code
      # Get everything before the first semi-colon
      parts = code.split ';'
      return nil unless parts.first
      # Get the first item in a comma-separated list
      parts = parts.first.split ','
      return nil unless code = parts.first

      code.gsub! '_', '-'

      languages = {
        'aa' => 'Afar',
        'ab' => 'Abkhazian',
        'ae' => 'Avestan',
        'af' => 'Afrikaans',
        'ak' => 'Akan',
        'am' => 'Amharic',
        'an' => 'Aragonese',
        'ar' => 'Arabic',
        'as' => 'Assamese',
        'av' => 'Avaric',
        'ay' => 'Aymara',
        'az' => 'Azerbaijani',
        'az' => 'Azeri',
        'ba' => 'Bashkir',
        'be' => 'Belarusian',
        'bg' => 'Bulgarian',
        'bh' => 'Bihari',
        'bi' => 'Bislama',
        'bm' => 'Bambara',
        'bn' => 'Bengali',
        'bo' => 'Tibetan',
        'br' => 'Breton',
        'bs' => 'Bosnian',
        'ca' => 'Catalan',
        'ca' => 'Catalan; Valencian',
        'ce' => 'Chechen',
        'ch' => 'Chamorro',
        'co' => 'Corsican',
        'cr' => 'Cree',
        'cs' => 'Czech',
        'cu' => 'Church Slavic; Old Slavonic; Church Slavonic; Old Bulgarian; Old Church Slavonic',
        'cv' => 'Chuvash',
        'cy' => 'Welsh',
        'da' => 'Danish',
        'de' => 'German (Germany)',
        'de' => 'German',
        'div' => 'Divehi',
        'dv' => 'Divehi; Dhivehi; Maldivian',
        'dz' => 'Dzongkha',
        'ee' => 'Ewe',
        'el' => 'Greek',
        'el' => 'Greek, Modern (1453-)',
        'en' => 'English',
        'eo' => 'Esperanto',
        'es' => 'Spanish (Traditional Sort)',
        'es' => 'Spanish; Castilian',
        'et' => 'Estonian',
        'eu' => 'Basque',
        'fa' => 'Farsi',
        'fa' => 'Persian',
        'ff' => 'Fulah',
        'fi' => 'Finnish',
        'fj' => 'Fijian',
        'fo' => 'Faeroese',
        'fo' => 'Faroese',
        'fr' => 'French',
        'fy' => 'Western Frisian',
        'ga' => 'Irish',
        'gd' => 'Gaelic',
        'gd' => 'Gaelic; Scottish Gaelic',
        'gl' => 'Galician',
        'gn' => 'Guarani',
        'gu' => 'Gujarati',
        'gv' => 'Manx',
        'ha' => 'Hausa',
        'he' => 'Hebrew',
        'hi' => 'Hindi',
        'ho' => 'Hiri Motu',
        'hr' => 'Croatian',
        'ht' => 'Haitian; Haitian Creole',
        'hu' => 'Hungarian',
        'hy' => 'Armenian',
        'hz' => 'Herero',
        'ia' => 'Interlingua (International Auxiliary Language Association)',
        'id' => 'Indonesian',
        'ie' => 'Interlingue; Occidental',
        'ig' => 'Igbo',
        'ii' => 'Sichuan Yi; Nuosu',
        'ik' => 'Inupiaq',
        'io' => 'Ido',
        'is' => 'Icelandic',
        'it' => 'Italian (Italy)',
        'it' => 'Italian',
        'iu' => 'Inuktitut',
        'ja' => 'Japanese',
        'jv' => 'Javanese',
        'ka' => 'Georgian',
        'kg' => 'Kongo',
        'ki' => 'Kikuyu; Gikuyu',
        'kj' => 'Kuanyama; Kwanyama',
        'kk' => 'Kazakh',
        'kl' => 'Kalaallisut; Greenlandic',
        'km' => 'Central Khmer',
        'kn' => 'Kannada',
        'ko' => 'Korean',
        'kok' => 'Konkani',
        'kr' => 'Kanuri',
        'ks' => 'Kashmiri',
        'ku' => 'Kurdish',
        'kv' => 'Komi',
        'kw' => 'Cornish',
        'ky' => 'Kirghiz; Kyrgyz',
        'kz' => 'Kyrgyz',
        'la' => 'Latin',
        'lb' => 'Luxembourgish; Letzeburgesch',
        'lg' => 'Ganda',
        'li' => 'Limburgan; Limburger; Limburgish',
        'ln' => 'Lingala',
        'lo' => 'Lao',
        'ls' => 'Slovenian',
        'lt' => 'Lithuanian',
        'lu' => 'Luba-Katanga',
        'lv' => 'Latvian',
        'mg' => 'Malagasy',
        'mh' => 'Marshallese',
        'mi' => 'Maori',
        'mk' => 'FYRO Macedonian',
        'mk' => 'Macedonian',
        'ml' => 'Malayalam',
        'mn' => 'Mongolian (Cyrillic)',
        'mn' => 'Mongolian',
        'mr' => 'Marathi',
        'ms' => 'Malay',
        'mt' => 'Maltese',
        'my' => 'Burmese',
        'na' => 'Nauru',
        'nb' => 'Bokmål, Norwegian; Norwegian Bokmål',
        'nd' => 'Ndebele, North; North Ndebele',
        'ne' => 'Nepali (India)',
        'ne' => 'Nepali',
        'ng' => 'Ndonga',
        'nl' => 'Dutch; Flemish',
        'nn' => 'Norwegian Nynorsk; Nynorsk, Norwegian',
        'no' => 'Norwegian (Bokmal)',
        'no' => 'Norwegian',
        'nr' => 'Ndebele, South; South Ndebele',
        'nv' => 'Navajo; Navaho',
        'ny' => 'Chichewa; Chewa; Nyanja',
        'oc' => 'Occitan (post 1500); Provençal',
        'oj' => 'Ojibwa',
        'om' => 'Oromo',
        'or' => 'Oriya',
        'os' => 'Ossetian; Ossetic',
        'pa' => 'Panjabi; Punjabi',
        'pa' => 'Punjabi',
        'pi' => 'Pali',
        'pl' => 'Polish',
        'ps' => 'Pushto; Pashto',
        'pt' => 'Portuguese (Portugal)',
        'pt' => 'Portuguese',
        'qu' => 'Quechua',
        'rm' => 'Rhaeto-Romanic',
        'rm' => 'Romansh',
        'rn' => 'Rundi',
        'ro' => 'Romanian',
        'ro' => 'Romanian; Moldavian; Moldovan',
        'ru' => 'Russian',
        'rw' => 'Kinyarwanda',
        'sa' => 'Sanskrit',
        'sb' => 'Sorbian',
        'sc' => 'Sardinian',
        'sd' => 'Sindhi',
        'se' => 'Northern Sami',
        'sg' => 'Sango',
        'si' => 'Sinhala; Sinhalese',
        'sk' => 'Slovak',
        'sl' => 'Slovenian',
        'sm' => 'Samoan',
        'sn' => 'Shona',
        'so' => 'Somali',
        'sq' => 'Albanian',
        'sr' => 'Serbian',
        'ss' => 'Swati',
        'st' => 'Sotho, Southern',
        'su' => 'Sundanese',
        'sv' => 'Swedish',
        'sw' => 'Swahili',
        'sx' => 'Sutu',
        'syr' => 'Syriac',
        'ta' => 'Tamil',
        'te' => 'Telugu',
        'tg' => 'Tajik',
        'th' => 'Thai',
        'ti' => 'Tigrinya',
        'tk' => 'Turkmen',
        'tl' => 'Tagalog',
        'tn' => 'Tswana',
        'to' => 'Tonga (Tonga Islands)',
        'tr' => 'Turkish',
        'ts' => 'Tsonga',
        'tt' => 'Tatar',
        'tw' => 'Twi',
        'ty' => 'Tahitian',
        'ug' => 'Uighur; Uyghur',
        'uk' => 'Ukrainian',
        'ur' => 'Urdu',
        'us' => 'English (United States)',
        'uz' => 'Uzbek',
        've' => 'Venda',
        'vi' => 'Vietnamese',
        'vo' => 'Volapük',
        'wa' => 'Walloon',
        'wo' => 'Wolof',
        'xh' => 'Xhosa',
        'yi' => 'Yiddish',
        'yo' => 'Yoruba',
        'za' => 'Zhuang; Chuang',
        'zh' => 'Chinese',
        'zu' => 'Zulu',
        'sz' => 'Sami',
        'ji' => 'Yiddish',
        'in' => 'Indonesian'
      }

      dialects = {
        'ar' => {
          'ae' => 'Arabic (U.A.E.)',
          'bh' => 'Arabic (Bahrain)',
          'dz' => 'Arabic (Algeria)',
          'eg' => 'Arabic (Egypt)',
          'iq' => 'Arabic (Iraq)',
          'jo' => 'Arabic (Jordan)',
          'kw' => 'Arabic (Kuwait)',
          'lb' => 'Arabic (Lebanon)',
          'ly' => 'Arabic (libya)',
          'ma' => 'Arabic (Morocco)',
          'om' => 'Arabic (Oman)',
          'qa' => 'Arabic (Qatar)',
          'sa' => 'Arabic (Saudi Arabia)',
          'sy' => 'Arabic (Syria)',
          'tn' => 'Arabic (Tunisia)',
          'ye' => 'Arabic (Yemen)'
      },
        'de' => {
          'at' => 'German (Austria)',
          'ch' => 'German (Switzerland)',
          'li' => 'German (Liechtenstein)',
          'lu' => 'German (Luxembourg)'
      },
        'en' => {
          'au' => 'English (Australia)',
          'bz' => 'English (Belize)',
          'ca' => 'English (Canada)',
          'gb' => 'English (United Kingdom)',
          'ie' => 'English (Ireland)',
          'jm' => 'English (Jamaica)',
          'nz' => 'English (New Zealand)',
          'ph' => 'English (Philippines)',
          'tt' => 'English (Trinidad)',
          'us' => 'English (United States)',
          'za' => 'English (South Africa)',
          'zw' => 'English (Zimbabwe)'
      },
        'es' => {
          'ar' => 'Spanish (Argentina)',
          'bo' => 'Spanish (Bolivia)',
          'cl' => 'Spanish (Chile)',
          'co' => 'Spanish (Colombia)',
          'cr' => 'Spanish (Costa Rica)',
          'do' => 'Spanish (Dominican Republic)',
          'ec' => 'Spanish (Ecuador)',
          'gt' => 'Spanish (Guatemala)',
          'hn' => 'Spanish (Honduras)',
          'mx' => 'Spanish (Mexico)',
          'ni' => 'Spanish (Nicaragua)',
          'pa' => 'Spanish (Panama)',
          'pe' => 'Spanish (Peru)',
          'pr' => 'Spanish (Puerto Rico)',
          'py' => 'Spanish (Paraguay)',
          'sv' => 'Spanish (El Salvador)',
          'us' => 'Spanish (United States)',
          'uy' => 'Spanish (Uruguay)',
          've' => 'Spanish (Venezuela)'
      },
        'fr' => {
          'be' => 'French (Belgium)',
          'ca' => 'French (Canada)',
          'ch' => 'French (Switzerland)',
          'lu' => 'French (Luxembourg)',
          'mc' => 'French (Monaco)'
      },
        'it' => {
          'ch' => 'Italian (Switzerland}'
      },
        'nb' => {
          'no' => 'Norwegian (Bokmal}'
      },
        'nl' => {
          'be' => 'Dutch (Belgium}'
      },
        'nn' => {
          'no' => 'Norwegian (Nynorsk}'
      },
        'pt' => {
          'br' => 'Portuguese (Brazil}'
      },
        'ro' => {
          'md' => 'Romanian (Moldova}'
      },
        'ru' => {
          'md' => 'Russian (Moldova}'
      },
        'sv' => {
          'fi' => 'Swedish (Finland}'
      },
        'zh' => {
          'cn' => 'Chinese (China}',
          'hk' => 'Chinese (Hong Kong SAR}',
          'mo' => 'Chinese (Macau SAR}',
          'sg' => 'Chinese (Singapore}',
          'tw' => 'Chinese (Taiwan}'
      }
      }

      # Check for exact match on language
      return languages[code] if languages[code]

      # Check for known dialect
      parts = code.split '-'
      if parts.size >=2
        language = parts[0]
        dialect = parts[1]

        if dialects[language] and dialects[language][dialect]
          return dialects[language][dialect]
        end

      end

      # Check for unknown dialect ( e.g. "fr-xx", which we assume to be a dialect of "French")
      shortened_code  = code[0,2]
      return languages[shortened_code] if languages[shortened_code]
      # Check for dialect with no language prefix (e.g "gb" for "English (United Kingdom)")
      dialects.each do |language,sub_dialects|
        return sub_dialects[code] if sub_dialects[code]
      end
      # Check for shortened dialect (e.g "gb-xx" for "English (United Kingdom)")
      dialects.each do |language,sub_dialects|
        return sub_dialects[shortened_code] if sub_dialects[shortened_code]
      end

      return nil
    end

    def verify
      return true
    end
  end
end
$__km_plugins__ << 'KMWebsiteUser'
