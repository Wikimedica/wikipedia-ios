#import <XCTest/XCTest.h>
#import "MWKLanguageLinkController_Private.h"
#import "MWKLanguageLink.h"
#import "MWKDataStore+TemporaryDataStore.h"
#import "NSString+WMFExtras.h"
#import "NSUserDefaults+WMFReset.h"

@interface MWKLanguageLinkControllerTests : XCTestCase
@property (strong, nonatomic) MWKLanguageLinkController *controller;
@property (strong, nonatomic) MWKLanguageFilter *filter;

@end

@implementation MWKLanguageLinkControllerTests

- (void)setUp {
    [super setUp];

    // force language link controller to grab device language, not previous values set by another test
    [[NSUserDefaults standardUserDefaults] wmf_resetToDefaultValues];

    NSAssert([[NSLocale preferredLanguages] containsObject:@"en-US"] || [[NSLocale preferredLanguages] containsObject:@"en"],
             @"For simplicity these tests assume the simulator has 'English' has one of its preferred languages."
              " Instead, these were the preferred languages: %@",
             [NSLocale preferredLanguages]);

    // all tests must start w/ a clean slate
    self.controller = MWKDataStore.temporaryDataStore.languageLinkController;
    self.filter = [[MWKLanguageFilter alloc] initWithLanguageDataSource:self.controller];
    [self.controller resetPreferredLanguages];
}

- (void)testReadPreviouslySelectedLanguagesReturnsEmpty {
    XCTAssertEqual([[self.controller readSavedPreferredLanguageCodes] count], 0);
}

- (void)testDefaultsToDevicePreferredLanguages {
    /*
       since we've asserted above that "en" or "en-US" is one of the OS preferred languages, we can assert that our
       controller contains a language link for "en"
     */
    XCTAssert([[self preferredLanguageCodes] containsObject:@"en"]);
    [self verifyAllLanguageArrayProperties];
}

- (void)testSaveSelectedLanguageUpdatesTheControllersFilteredPreferredLanguages {
    //    NSAssert(![[self preferredLanguageCodes] containsObject:@"test"],
    //             @"'test' shouldn't be a default member of preferred languages!");

    MWKLanguageLink *link = [[MWKLanguageLink alloc] initWithLanguageCode:@"test" pageTitleText:@"test" name:@"test" localizedName:@"test" languageVariantCode:@"test"];
    [self.controller appendPreferredLanguage:link];

    XCTAssert([[self preferredLanguageCodes] containsObject:@"test"]);
    [self verifyAllLanguageArrayProperties];
}

- (void)testUniqueAppendToPreferredLanguages {
    MWKLanguageLink *link = [[MWKLanguageLink alloc] initWithLanguageCode:@"test" pageTitleText:@"test" name:@"test" localizedName:@"test" languageVariantCode:@"test"];
    [self.controller appendPreferredLanguage:link];
    NSArray *firstAppend = [self.controller.preferredLanguages copy];

    [self.controller appendPreferredLanguage:link];
    NSArray *secondAppend = [self.controller.preferredLanguages copy];

    XCTAssertEqualObjects(firstAppend, secondAppend);

    [self verifyAllLanguageArrayProperties];
}

- (void)testLanguagesPropertiesAreNonnull {
    self.controller = MWKDataStore.temporaryDataStore.languageLinkController;
    XCTAssertTrue(self.controller.allLanguages.count > 0);
    XCTAssertTrue(self.controller.otherLanguages.count > 0);
    XCTAssertTrue(self.controller.preferredLanguages.count > 0);
    [self verifyAllLanguageArrayProperties];
}

- (void)testBasicFiltering {
    self.filter.languageFilter = @"en";
    
    XCTAssert([self.filter.filteredLanguages wmf_reject:^BOOL(MWKLanguageLink *langLink) {
                   return [langLink.name wmf_caseInsensitiveContainsString:@"en"] || [langLink.localizedName wmf_caseInsensitiveContainsString:@"en"];
               }].count == 0, @"All filtered languages have a name or localized name containing filter ignoring case");
    [self verifyAllLanguageArrayProperties];
}

- (void)testEmptyAfterFiltering {
    self.filter.languageFilter = @"$";
    XCTAssert(self.filter.filteredLanguages.count == 0);
}

- (void)testContentLanguageCodeProperty {
    NSString *languageCode = @"zh";
    NSString *languageVariantCode = @"zh-hans";
    
    // If languageVariantCode is non-nil and non-empty string, contentLanguageCode returns languageVariantCode
    MWKLanguageLink *link = [[MWKLanguageLink alloc] initWithLanguageCode:languageCode pageTitleText:@"test" name:@"test" localizedName:@"test" languageVariantCode:languageVariantCode];
    XCTAssertEqualObjects(link.contentLanguageCode, languageVariantCode);
    
    // If languageVariantCode is nil, contentLanguageCode returns languageCode
    link = [[MWKLanguageLink alloc] initWithLanguageCode:languageCode pageTitleText:@"test" name:@"test" localizedName:@"test" languageVariantCode:nil];
    XCTAssertEqualObjects(link.contentLanguageCode, languageCode);
    
    // If languageVariantCode is an empty string, contentLanguageCode returns languageCode
    link = [[MWKLanguageLink alloc] initWithLanguageCode:languageCode pageTitleText:@"test" name:@"test" localizedName:@"test" languageVariantCode:@""];
    XCTAssertEqualObjects(link.contentLanguageCode, languageCode);
}

- (void)testLanguageVariantCodeURLPropagation {
    NSString *languageCode = @"sr";
    NSString *languageVariantCode = @"sr-el";
    
    // The languageVariantCode property should propagate to the siteURL.
    MWKLanguageLink *link = [[MWKLanguageLink alloc] initWithLanguageCode:languageCode pageTitleText:@"test" name:@"test" localizedName:@"test" languageVariantCode:languageVariantCode];
    NSURL *siteURL = link.siteURL;
    XCTAssertEqualObjects(siteURL.wmf_languageVariantCode, languageVariantCode);
    
    // The languageVariantCode property should propagate to the articleURL.
    link = [[MWKLanguageLink alloc] initWithLanguageCode:languageCode pageTitleText:@"PageTitle" name:@"test" localizedName:@"test" languageVariantCode:languageVariantCode];
    NSURL *articleURL = link.articleURL;
    XCTAssertEqualObjects(articleURL.wmf_languageVariantCode, languageVariantCode);
}


#pragma mark - Utils

- (void)verifyAllLanguageArrayProperties {
    [self verifyPreferredAndOtherSumIsAllLanguages];
    [self verifyPreferredAndOtherAreDisjoint];
}

- (void)verifyPreferredAndOtherAreDisjoint {
    XCTAssertFalse([[NSSet setWithArray:self.controller.preferredLanguages]
                       intersectsSet:
                           [NSSet setWithArray:self.controller.otherLanguages]],
                   @"'preferred' and 'other' languages shouldn't intersect: \n preferred: %@ \nother: %@",
                   self.controller.preferredLanguages, self.controller.otherLanguages);
}

- (void)verifyPreferredAndOtherSumIsAllLanguages {
    NSSet *joinedLanguages = [NSSet setWithArray:
                                        [self.controller.preferredLanguages
                                            arrayByAddingObjectsFromArray:self.controller.otherLanguages]];

    XCTAssert(joinedLanguages.count ==  self.controller.otherLanguages.count + self.controller.preferredLanguages.count);

    XCTAssertEqualObjects([NSSet setWithArray:self.controller.allLanguages], joinedLanguages);
}

- (NSArray<NSString *> *)preferredLanguageCodes {
    return [self.controller.preferredLanguages valueForKey:WMF_SAFE_KEYPATH(MWKLanguageLink.new, languageCode)];
}

- (NSArray *)allLanguageCodes {
    return [self.controller.allLanguages valueForKey:WMF_SAFE_KEYPATH(MWKLanguageLink.new, languageCode)];
}

@end
