### Updating languages

Inside the main project, there's a `languages` target that is a Mac command line tool. You can edit the swift files used by this target (inside `Command Line Tools/Update Languages/`) to update the languages script. 

When translations for a new language are added to the app:
1. Run the `Update Languages` scheme in XCode. This will create all of the needed config files for any new Wikipedia languages detected.
2. If the new language is not seen in the `Localizable.strings` and/or `Localizable.stringsdict` files, the actual language files may need to be added to the XCode project manually. Select the `Localizable.strings` file in the the Project Navigator, then `File` -> `Add Files to Wikipedia`. Select all the files in the `Wikipedia/iOS Native Localizations/[lang code].lproj` folder (`Localizable.strings`, `Localizable.stringsdict`, and/or `InfoPlist.strings`). Add them only to the `WMF` target. (Ideally this step can be incoporated into the script run in the first step, but given how rarely new languages are added, for the time being this is manual.) 
3. If the new language is still not seen in both the `Localizable.strings` and `Localizable.stringsdict` files, add an `InfoPlist.string` file in the language's folder with the line `"CFBundleDisplayName" = "Wikipedia";`. Add this file to the project (see step 2).  
4. Submit a PR with the changes. 

### Updating language variants
At present there is no automated process for adding language variants to the app. When a new language variant or set of language variants is added to the app there are two files that need to be updated:

1. The language variant definition file (`wikipedia-language-variants.json`).
2. The language variant mapping file (`MediaWikiAcceptLanguageMapping.json`).

#### Language variant definition file
The `wikipedia-language-variants.json` file is maintained manually. The file is keyed by Wikipedia language code with the value for each key being an array of language variants for that language. It is in this format because at runtime the Wikipedia language needs to be replaced by its variants.

For a language with existing language variants, add new variants to the existing array for that language.

For a language that has not had language variants before, add a new top-level key with the Wikipedia language code for the language with variants with the value being an array of the variants. Follow the pattern already established in the file.

_Troubleshooting: Variants missing from this file will not appear in the user's choices of langugages._ 

#### Language variant mapping file
During onboarding, the app uses the user's OS langauge preferences to suggest the primary app language. If the language is one with variants, the variant specified by the user should be used.

However, the codes used by the OS to represent variants is different than the codes used by Wikipedia sites. The mapping from OS Locale for a given language to the Wikipedia language variant code is defined in the  `MediaWikiAcceptLanguageMapping.json` file.

The `MediaWikiAcceptLanguageMapping.json` file is a set of nested dictionaries. The keys in these dictionaries are the `languageCode`, `scriptCode`, and `regionCode` of the Locale corresponding to an OS preferred language. Each dictionary also has a `default` key in case no matching value is found.

When adding a new variant, the correct mapping from the OS language / Locale to that variant should be added to this file.

_Troubleshooting: Variants missing from this file cause onboarding to fail to identify a variant to suggest to the user ._ 

Note: Historically this mapping file was used to determine the user's language variant preference in Chinese and Serbian based on the user's OS language settings. The new language variant feature allows the user to choose variants explicitly.






