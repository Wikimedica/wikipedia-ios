#import <WMF/MWKLanguageLinkController_Private.h>
#import <WMF/WMF-Swift.h>
#import <WMF/MWKDataStore.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const WMFPreferredLanguagesDidChangeNotification = @"WMFPreferredLanguagesDidChangeNotification";

NSString *const WMFAppLanguageDidChangeNotification = @"WMFAppLanguageDidChangeNotification";

NSString *const WMFPreferredLanguagesChangeTypeKey = @"WMFPreferredLanguagesChangeTypeKey";
NSString *const WMFPreferredLanguagesLastChangedLanguageKey = @"WMFPreferredLanguagesLastChangedLanguageKey";

static NSString *const WMFPreviousLanguagesKey = @"WMFPreviousSelectedLanguagesKey";

@interface MWKLanguageLinkController ()

@property (weak, nonatomic) NSManagedObjectContext *moc;

@end

@implementation MWKLanguageLinkController

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)moc {
    if (self = [super init]) {
        self.moc = moc;
    }
    return self;
}

#pragma mark - Getters & Setters

+ (NSDictionary<NSString *, NSArray<MWKLanguageLink *> *> *)allLanguageVariantsBySiteLanguageCode {
    /// Separate static dictionary here so the dictionary is only bridged once
    static dispatch_once_t onceToken;
    static NSDictionary<NSString *, NSArray<MWKLanguageLink *> *> *allLanguageVariantsBySiteLanguageCode;
    dispatch_once(&onceToken, ^{
        allLanguageVariantsBySiteLanguageCode = WikipediaLookup.allLanguageVariantsByWikipediaLanguageCode;
    });
    return allLanguageVariantsBySiteLanguageCode;
}

+ (NSArray<MWKLanguageLink *> *)allLanguages {
    /// Separate static array here so the array is only bridged once and variant substitution happens once
    static dispatch_once_t onceToken;
    static NSArray<MWKLanguageLink *> *allLanguages;
    dispatch_once(&onceToken, ^{
        allLanguages = [MWKLanguageLinkController languagesReplacingSiteLanguagesWithVariants:WikipediaLookup.allLanguageLinks];
    });
    return allLanguages;
}

/// Since MWKLanguageLink instances represent a language choice in the user-interface, language variants must be included.
/// The autogenerated all languages list and the list of languges for an article both include only site languages, not variants.
/// This method takes an array of site language links and replaces the site language with the language variants for sites with variants.
+ (NSArray<MWKLanguageLink *> *)languagesReplacingSiteLanguagesWithVariants:(NSArray<MWKLanguageLink *> *)languages {
    NSMutableArray *tempResult = [[NSMutableArray alloc] init];
    for (MWKLanguageLink *language in languages) {
        NSAssert((language.languageVariantCode == nil && ![language.languageVariantCode isEqualToString:@""]), @"The method %s should only be called with MWKLanguageLink objects with a nil or empty-string languageVariantCode", __PRETTY_FUNCTION__);
        NSArray<MWKLanguageLink *> *variants = [MWKLanguageLinkController allLanguageVariantsBySiteLanguageCode][language.languageCode];
        if (variants) {
            [tempResult addObjectsFromArray:variants];
        } else {
            [tempResult addObject:language];
        }
    }
    return [tempResult copy];
}

- (NSArray<MWKLanguageLink *> *)allLanguages {
    return [MWKLanguageLinkController allLanguages];
}

- (nullable MWKLanguageLink *)languageForSiteURL:(NSURL *)siteURL {
    return [self.allLanguages wmf_match:^BOOL(MWKLanguageLink *obj) {
        return [obj.siteURL isEqual:siteURL];
    }];
}

- (nullable MWKLanguageLink *)appLanguage {
    return [self.preferredLanguages firstObject];
}

- (NSArray<MWKLanguageLink *> *)preferredLanguages {
    NSArray *preferredLanguageCodes = [self readPreferredLanguageCodes];
    return [preferredLanguageCodes wmf_mapAndRejectNil:^id(NSString *langString) {
        return [self.allLanguages wmf_match:^BOOL(MWKLanguageLink *langLink) {
            return [langLink.contentLanguageCode isEqualToString:langString];
        }];
    }];
}

- (NSArray<NSURL *> *)preferredSiteURLs {
    return [[self preferredLanguages] wmf_mapAndRejectNil:^NSURL *_Nullable(MWKLanguageLink *_Nonnull obj) {
        return [obj siteURL];
    }];
}

- (NSArray<MWKLanguageLink *> *)otherLanguages {
    return [self.allLanguages wmf_select:^BOOL(MWKLanguageLink *langLink) {
        return ![self.preferredLanguages containsObject:langLink];
    }];
}

#pragma mark - Preferred Language Management

- (void)appendPreferredLanguage:(MWKLanguageLink *)language {
    NSParameterAssert(language);
    NSMutableArray<NSString *> *langCodes = [[self readPreferredLanguageCodes] mutableCopy];
    [langCodes removeObject:language.contentLanguageCode];
    [langCodes addObject:language.contentLanguageCode];
    [self savePreferredLanguageCodes:langCodes changeType:WMFPreferredLanguagesChangeTypeAdd changedLanguage:language];
}

- (void)reorderPreferredLanguage:(MWKLanguageLink *)language toIndex:(NSInteger)newIndex {
    NSMutableArray<NSString *> *langCodes = [[self readPreferredLanguageCodes] mutableCopy];
    NSAssert(newIndex < (NSInteger)[langCodes count], @"new language index is out of range");
    if (newIndex >= (NSInteger)[langCodes count]) {
        return;
    }
    NSInteger oldIndex = (NSInteger)[langCodes indexOfObject:language.contentLanguageCode];
    NSAssert(oldIndex != NSNotFound, @"Language is not a preferred language");
    if (oldIndex == NSNotFound) {
        return;
    }
    [langCodes removeObject:language.contentLanguageCode];
    [langCodes insertObject:language.contentLanguageCode atIndex:(NSUInteger)newIndex];
    [self savePreferredLanguageCodes:langCodes changeType:WMFPreferredLanguagesChangeTypeReorder changedLanguage:language];
}

- (void)removePreferredLanguage:(MWKLanguageLink *)language {
    NSMutableArray<NSString *> *langCodes = [[self readPreferredLanguageCodes] mutableCopy];
    [langCodes removeObject:language.contentLanguageCode];
    [self savePreferredLanguageCodes:langCodes changeType:WMFPreferredLanguagesChangeTypeRemove changedLanguage:language];
}

#pragma mark - Reading/Saving Preferred Language Codes

- (NSArray<NSString *> *)readSavedPreferredLanguageCodes {
    __block NSArray<NSString *> *preferredLanguages = nil;
    [self.moc performBlockAndWait:^{
        preferredLanguages = [self.moc wmf_arrayValueForKey:WMFPreviousLanguagesKey] ?: @[];
    }];
    return preferredLanguages;
}

- (NSArray<NSString *> *)readPreferredLanguageCodes {
    NSMutableArray<NSString *> *preferredLanguages = [[self readSavedPreferredLanguageCodes] mutableCopy];

    if (preferredLanguages.count == 0) {
        NSArray<NSString *> *osLanguages = NSLocale.wmf_preferredLocaleLanguageCodes;
        [osLanguages enumerateObjectsWithOptions:0
                                      usingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
                                          if (![preferredLanguages containsObject:obj]) {
                                              [preferredLanguages addObject:obj];
                                          }
                                      }];
    }
    return [preferredLanguages wmf_reject:^BOOL(id obj) {
        return [obj isEqual:[NSNull null]];
    }];
}

- (void)savePreferredLanguageCodes:(NSArray<NSString *> *)languageCodes changeType:(WMFPreferredLanguagesChangeType)changeType changedLanguage:(MWKLanguageLink *)changedLanguage {
    NSString *previousAppContentLanguageCode = self.appLanguage.contentLanguageCode;
    [self willChangeValueForKey:WMF_SAFE_KEYPATH(self, allLanguages)];
    [self.moc performBlockAndWait:^{
        [self.moc wmf_setValue:languageCodes forKey:WMFPreviousLanguagesKey];
        NSError *preferredLanguageCodeSaveError = nil;
        if (![self.moc save:&preferredLanguageCodeSaveError]) {
            DDLogError(@"Error saving preferred languages: %@", preferredLanguageCodeSaveError);
        }
    }];
    [self didChangeValueForKey:WMF_SAFE_KEYPATH(self, allLanguages)];
    NSDictionary *userInfo = @{WMFPreferredLanguagesChangeTypeKey: @(changeType), WMFPreferredLanguagesLastChangedLanguageKey: changedLanguage};
    [[NSNotificationCenter defaultCenter] postNotificationName:WMFPreferredLanguagesDidChangeNotification object:self userInfo:userInfo];
    if (self.appLanguage.contentLanguageCode && ![self.appLanguage.contentLanguageCode isEqualToString:previousAppContentLanguageCode]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:WMFAppLanguageDidChangeNotification object:self];
    }
}

// Reminder: "resetPreferredLanguages" is for testing only!
- (void)resetPreferredLanguages {
    [self willChangeValueForKey:WMF_SAFE_KEYPATH(self, allLanguages)];
    [self.moc performBlockAndWait:^{
        [self.moc wmf_setValue:nil forKey:WMFPreviousLanguagesKey];
    }];
    [self didChangeValueForKey:WMF_SAFE_KEYPATH(self, allLanguages)];
    [[NSNotificationCenter defaultCenter] postNotificationName:WMFPreferredLanguagesDidChangeNotification object:self];
}

- (void)getPreferredLanguageCodes:(void (^)(NSArray<NSString *> *))completion {
    [self.moc performBlock:^{
        completion([self readPreferredLanguageCodes]);
    }];
}

// This method can only be safely called from the main app target, as an extension's standard `NSUserDefaults` are independent from the main app and other targets.
+ (void)migratePreferredLanguagesToManagedObjectContext:(NSManagedObjectContext *)moc {
    NSArray *preferredLanguages = [[NSUserDefaults standardUserDefaults] arrayForKey:WMFPreviousLanguagesKey];
    [moc wmf_setValue:preferredLanguages forKey:WMFPreviousLanguagesKey];
}

@end

NS_ASSUME_NONNULL_END
