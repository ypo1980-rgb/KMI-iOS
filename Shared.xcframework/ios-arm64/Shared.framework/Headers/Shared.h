#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

@class SharedAppStrings, SharedAppStringsLang, SharedKotlinEnumCompanion, SharedKotlinEnum<E>, SharedKotlinArray<T>, SharedKmiSettingsFactory, SharedPlatform, SharedPlatformFile, SharedBeltDto, SharedExerciseContentDto, SharedExerciseDto, SharedInMemoryCatalog, SharedSubTopicDto, SharedTopicDto, SharedKmiCatalogFacade, SharedBeltCompanion, SharedBelt, SharedCoachRegistry, SharedContentRepo, SharedContentRepoSubTopic, SharedContentRepoResolvedItem, SharedContentRepoSearchHit, SharedContentRepoBeltContent, SharedContentRepoTopic, SharedExplanations, SharedExplanationsExplanationAuditRow, SharedSubTopicRegistry, SharedSubjectTopic, SharedTopicsEngine, SharedTopicsEngineTopicDetails, SharedUserRoleCompanion, SharedUserRole, SharedCatalogRepo, SharedCatalogTopic, SharedCatalogRepoBuilder, SharedCatalogSubTopic, SharedCanonical, SharedCanonicalParsedItem, SharedExerciseExplanationsEn, SharedExerciseTitlesEnAliases, SharedExerciseTitlesEnItems, SharedExerciseTitlesEnTopics, SharedExerciseIdentityRegistry, SharedExerciseIdentityRegistryExerciseIdentity, SharedExerciseIdentityRegistryAuditReport, SharedExerciseIdentityRegistryResolvedExerciseIdentity, SharedExerciseIdentityRegistryAuditRow, SharedExerciseTitlesEn, SharedHardSectionsCatalog, SharedKotlinPair<__covariant A, __covariant B>, SharedHardSectionsCatalogSection, SharedHardSectionsCatalogBeltGroup, SharedHardSectionsResolver, SharedHardSectionsResolverBeltItems, SharedHardSectionsResolverNodeResultBeltGroups, SharedHardSectionsResolverSectionEntry, SharedHardSectionsResolverNodeResultSections, SharedSharedExerciseExplanationResolver, SharedSubjectItemsResolver, SharedSubjectItemsResolverUiSection, SharedSubjectItemsResolverUiItem, SharedAttackType, SharedDefenseKind, SharedExamFacade, SharedKotlinx_datetimeInstant, SharedForumMessage, SharedFreeSessionsPaths, SharedParticipantState, SharedFreeSession, SharedFreeSessionPart, SharedParticipantStateCompanion, SharedAppLanguageCompanion, SharedAppLanguage, SharedLanguageKeys, SharedLanguageStrings, SharedLocalizationRuntime, SharedKmiBelt, SharedKmiTopic, SharedKmiBeltContent, SharedKmiSubTopic, SharedPracticeFacade, SharedPracticeItem, SharedPracticeRequest, SharedPracticeFilters, SharedKmiPrefsFacadeCompanion, SharedKmiPrefsFacade, SharedKmiPrefsFactory, SharedKmiPrefs, SharedSharedSettings, SharedSharedSettingsFactoryProvider, SharedProgressFacade, SharedProgressFacadeBeltProgressRow, SharedProgressStoreCompanion, SharedProgressStore, SharedBeltRef, SharedQuestionItem, SharedTopicBucket, SharedSubTopicRef, SharedSubTopicBucket, SharedTopicRef, SharedSharedRegistryQuestionsSource, SharedExerciseTitleFormatter, SharedSearchKeyParser, SharedDailyExerciseItem, SharedBeltProgress, SharedProgressCalc, SharedProgressCalcCounts, SharedProgressReport, SharedKmiSearch, SharedSearchHit, SharedKmiTtsManager, SharedPlatformContext, SharedPlatformCache, SharedPlatformFile_, SharedKotlinByteArray, SharedPlatformClock, SharedPlatformCoroutines, SharedPlatformEnv, SharedPlatformFormat, SharedPlatformHttp, SharedPlatformJson, SharedPlatformPrefs, SharedLogBridge, SharedKotlinThrowable, SharedKotlinx_datetimeInstantCompanion, SharedKotlinException, SharedKotlinRuntimeException, SharedKotlinIllegalStateException, SharedKotlinByteIterator, SharedKotlinx_serialization_coreSerializersModule, SharedKotlinx_serialization_coreSerialKind, SharedKotlinNothing;

@protocol SharedKotlinComparable, SharedMultiplatform_settingsSettings, SharedHardSectionsResolverNodeResult, SharedExamFacadeTopicTitlesProvider, SharedExamFacadeItemsProvider, SharedKotlinx_coroutines_coreFlow, SharedLanguageStore, SharedPracticeFacadeTopicTitlesProvider, SharedPracticeFacadeItemsProvider, SharedPracticeFacadeSetProvider, SharedPracticeFacadeExcludedProvider, SharedMultiplatform_settingsSettingsFactory, SharedUserPrefsRepository, SharedProgressFacadeExcludedProvider, SharedProgressFacadeStatusProvider, SharedQuestionsContentSource, SharedKotlinSuspendFunction0, SharedFreeSessionsRepository, SharedKotlinIterator, SharedKotlinx_coroutines_coreFlowCollector, SharedKotlinFunction, SharedKotlinx_datetimeDateTimeFormat, SharedKotlinx_serialization_coreKSerializer, SharedKotlinAppendable, SharedKotlinx_serialization_coreEncoder, SharedKotlinx_serialization_coreSerialDescriptor, SharedKotlinx_serialization_coreSerializationStrategy, SharedKotlinx_serialization_coreDecoder, SharedKotlinx_serialization_coreDeserializationStrategy, SharedKotlinx_serialization_coreCompositeEncoder, SharedKotlinAnnotation, SharedKotlinx_serialization_coreCompositeDecoder, SharedKotlinx_serialization_coreSerializersModuleCollector, SharedKotlinKClass, SharedKotlinKDeclarationContainer, SharedKotlinKAnnotatedElement, SharedKotlinKClassifier;

NS_ASSUME_NONNULL_BEGIN
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunknown-warning-option"
#pragma clang diagnostic ignored "-Wincompatible-property-type"
#pragma clang diagnostic ignored "-Wnullability"

#pragma push_macro("_Nullable_result")
#if !__has_feature(nullability_nullable_result)
#undef _Nullable_result
#define _Nullable_result _Nullable
#endif

__attribute__((swift_name("KotlinBase")))
@interface SharedBase : NSObject
- (instancetype)init __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
+ (void)initialize __attribute__((objc_requires_super));
@end

@interface SharedBase (SharedBaseCopying) <NSCopying>
@end

__attribute__((swift_name("KotlinMutableSet")))
@interface SharedMutableSet<ObjectType> : NSMutableSet<ObjectType>
@end

__attribute__((swift_name("KotlinMutableDictionary")))
@interface SharedMutableDictionary<KeyType, ObjectType> : NSMutableDictionary<KeyType, ObjectType>
@end

@interface NSError (NSErrorSharedKotlinException)
@property (readonly) id _Nullable kotlinException;
@end

__attribute__((swift_name("KotlinNumber")))
@interface SharedNumber : NSNumber
- (instancetype)initWithChar:(char)value __attribute__((unavailable));
- (instancetype)initWithUnsignedChar:(unsigned char)value __attribute__((unavailable));
- (instancetype)initWithShort:(short)value __attribute__((unavailable));
- (instancetype)initWithUnsignedShort:(unsigned short)value __attribute__((unavailable));
- (instancetype)initWithInt:(int)value __attribute__((unavailable));
- (instancetype)initWithUnsignedInt:(unsigned int)value __attribute__((unavailable));
- (instancetype)initWithLong:(long)value __attribute__((unavailable));
- (instancetype)initWithUnsignedLong:(unsigned long)value __attribute__((unavailable));
- (instancetype)initWithLongLong:(long long)value __attribute__((unavailable));
- (instancetype)initWithUnsignedLongLong:(unsigned long long)value __attribute__((unavailable));
- (instancetype)initWithFloat:(float)value __attribute__((unavailable));
- (instancetype)initWithDouble:(double)value __attribute__((unavailable));
- (instancetype)initWithBool:(BOOL)value __attribute__((unavailable));
- (instancetype)initWithInteger:(NSInteger)value __attribute__((unavailable));
- (instancetype)initWithUnsignedInteger:(NSUInteger)value __attribute__((unavailable));
+ (instancetype)numberWithChar:(char)value __attribute__((unavailable));
+ (instancetype)numberWithUnsignedChar:(unsigned char)value __attribute__((unavailable));
+ (instancetype)numberWithShort:(short)value __attribute__((unavailable));
+ (instancetype)numberWithUnsignedShort:(unsigned short)value __attribute__((unavailable));
+ (instancetype)numberWithInt:(int)value __attribute__((unavailable));
+ (instancetype)numberWithUnsignedInt:(unsigned int)value __attribute__((unavailable));
+ (instancetype)numberWithLong:(long)value __attribute__((unavailable));
+ (instancetype)numberWithUnsignedLong:(unsigned long)value __attribute__((unavailable));
+ (instancetype)numberWithLongLong:(long long)value __attribute__((unavailable));
+ (instancetype)numberWithUnsignedLongLong:(unsigned long long)value __attribute__((unavailable));
+ (instancetype)numberWithFloat:(float)value __attribute__((unavailable));
+ (instancetype)numberWithDouble:(double)value __attribute__((unavailable));
+ (instancetype)numberWithBool:(BOOL)value __attribute__((unavailable));
+ (instancetype)numberWithInteger:(NSInteger)value __attribute__((unavailable));
+ (instancetype)numberWithUnsignedInteger:(NSUInteger)value __attribute__((unavailable));
@end

__attribute__((swift_name("KotlinByte")))
@interface SharedByte : SharedNumber
- (instancetype)initWithChar:(char)value;
+ (instancetype)numberWithChar:(char)value;
@end

__attribute__((swift_name("KotlinUByte")))
@interface SharedUByte : SharedNumber
- (instancetype)initWithUnsignedChar:(unsigned char)value;
+ (instancetype)numberWithUnsignedChar:(unsigned char)value;
@end

__attribute__((swift_name("KotlinShort")))
@interface SharedShort : SharedNumber
- (instancetype)initWithShort:(short)value;
+ (instancetype)numberWithShort:(short)value;
@end

__attribute__((swift_name("KotlinUShort")))
@interface SharedUShort : SharedNumber
- (instancetype)initWithUnsignedShort:(unsigned short)value;
+ (instancetype)numberWithUnsignedShort:(unsigned short)value;
@end

__attribute__((swift_name("KotlinInt")))
@interface SharedInt : SharedNumber
- (instancetype)initWithInt:(int)value;
+ (instancetype)numberWithInt:(int)value;
@end

__attribute__((swift_name("KotlinUInt")))
@interface SharedUInt : SharedNumber
- (instancetype)initWithUnsignedInt:(unsigned int)value;
+ (instancetype)numberWithUnsignedInt:(unsigned int)value;
@end

__attribute__((swift_name("KotlinLong")))
@interface SharedLong : SharedNumber
- (instancetype)initWithLongLong:(long long)value;
+ (instancetype)numberWithLongLong:(long long)value;
@end

__attribute__((swift_name("KotlinULong")))
@interface SharedULong : SharedNumber
- (instancetype)initWithUnsignedLongLong:(unsigned long long)value;
+ (instancetype)numberWithUnsignedLongLong:(unsigned long long)value;
@end

__attribute__((swift_name("KotlinFloat")))
@interface SharedFloat : SharedNumber
- (instancetype)initWithFloat:(float)value;
+ (instancetype)numberWithFloat:(float)value;
@end

__attribute__((swift_name("KotlinDouble")))
@interface SharedDouble : SharedNumber
- (instancetype)initWithDouble:(double)value;
+ (instancetype)numberWithDouble:(double)value;
@end

__attribute__((swift_name("KotlinBoolean")))
@interface SharedBoolean : SharedNumber
- (instancetype)initWithBool:(BOOL)value;
+ (instancetype)numberWithBool:(BOOL)value;
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AppStrings")))
@interface SharedAppStrings : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)appStrings __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedAppStrings *shared __attribute__((swift_name("shared")));
- (NSString *)tKey:(NSString *)key __attribute__((swift_name("t(key:)")));
@property SharedAppStringsLang *currentLang __attribute__((swift_name("currentLang")));
@end

__attribute__((swift_name("KotlinComparable")))
@protocol SharedKotlinComparable
@required
- (int32_t)compareToOther:(id _Nullable)other __attribute__((swift_name("compareTo(other:)")));
@end

__attribute__((swift_name("KotlinEnum")))
@interface SharedKotlinEnum<E> : SharedBase <SharedKotlinComparable>
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SharedKotlinEnumCompanion *companion __attribute__((swift_name("companion")));
- (int32_t)compareToOther:(E)other __attribute__((swift_name("compareTo(other:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@property (readonly) int32_t ordinal __attribute__((swift_name("ordinal")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AppStrings.Lang")))
@interface SharedAppStringsLang : SharedKotlinEnum<SharedAppStringsLang *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) SharedAppStringsLang *he __attribute__((swift_name("he")));
@property (class, readonly) SharedAppStringsLang *en __attribute__((swift_name("en")));
+ (SharedKotlinArray<SharedAppStringsLang *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<SharedAppStringsLang *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KmiSettings")))
@interface SharedKmiSettings : SharedBase
- (instancetype)initWithSettings:(id<SharedMultiplatform_settingsSettings>)settings __attribute__((swift_name("init(settings:)"))) __attribute__((objc_designated_initializer));
- (void)clearAll __attribute__((swift_name("clearAll()")));
- (int32_t)incLaunchCount __attribute__((swift_name("incLaunchCount()")));
@property NSString * _Nullable branch __attribute__((swift_name("branch")));
@property NSString * _Nullable email __attribute__((swift_name("email")));
@property NSString * _Nullable fullName __attribute__((swift_name("fullName")));
@property int32_t launchCount __attribute__((swift_name("launchCount")));
@property NSString * _Nullable phone __attribute__((swift_name("phone")));
@property NSString * _Nullable region __attribute__((swift_name("region")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KmiSettingsFactory")))
@interface SharedKmiSettingsFactory : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)kmiSettingsFactory __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedKmiSettingsFactory *shared __attribute__((swift_name("shared")));
- (id<SharedMultiplatform_settingsSettings>)ofName:(NSString *)name context:(id _Nullable)context __attribute__((swift_name("of(name:context:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Platform")))
@interface SharedPlatform : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)platform __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedPlatform *shared __attribute__((swift_name("shared")));
- (void)cancelWeeklyTrainingAlarms __attribute__((swift_name("cancelWeeklyTrainingAlarms()")));
- (void)doInitAppContext:(id _Nullable)appContext __attribute__((swift_name("doInit(appContext:)")));
- (SharedPlatformFile *)saveTextAsFileFilename:(NSString *)filename mimeType:(NSString *)mimeType contents:(NSString *)contents __attribute__((swift_name("saveTextAsFile(filename:mimeType:contents:)")));
- (void)scheduleWeeklyTrainingAlarmsLeadMinutes:(int32_t)leadMinutes __attribute__((swift_name("scheduleWeeklyTrainingAlarms(leadMinutes:)")));
- (void)setClickSoundsEnabledEnabled:(BOOL)enabled __attribute__((swift_name("setClickSoundsEnabled(enabled:)")));
- (void)setHapticsEnabledEnabled:(BOOL)enabled __attribute__((swift_name("setHapticsEnabled(enabled:)")));
@property (readonly) id _Nullable appContextOrNull __attribute__((swift_name("appContextOrNull")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PlatformFile")))
@interface SharedPlatformFile : SharedBase
- (instancetype)initWithPath:(NSString *)path mimeType:(NSString *)mimeType __attribute__((swift_name("init(path:mimeType:)"))) __attribute__((objc_designated_initializer));
- (SharedPlatformFile *)doCopyPath:(NSString *)path mimeType:(NSString *)mimeType __attribute__((swift_name("doCopy(path:mimeType:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *mimeType __attribute__((swift_name("mimeType")));
@property (readonly) NSString *path __attribute__((swift_name("path")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("BeltDto")))
@interface SharedBeltDto : SharedBase
- (instancetype)initWithId:(NSString *)id title:(NSString *)title order:(int32_t)order __attribute__((swift_name("init(id:title:order:)"))) __attribute__((objc_designated_initializer));
- (SharedBeltDto *)doCopyId:(NSString *)id title:(NSString *)title order:(int32_t)order __attribute__((swift_name("doCopy(id:title:order:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) int32_t order __attribute__((swift_name("order")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExerciseContentDto")))
@interface SharedExerciseContentDto : SharedBase
- (instancetype)initWithId:(NSString *)id title:(NSString *)title mimeType:(NSString *)mimeType contents:(NSString *)contents __attribute__((swift_name("init(id:title:mimeType:contents:)"))) __attribute__((objc_designated_initializer));
- (SharedExerciseContentDto *)doCopyId:(NSString *)id title:(NSString *)title mimeType:(NSString *)mimeType contents:(NSString *)contents __attribute__((swift_name("doCopy(id:title:mimeType:contents:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *contents __attribute__((swift_name("contents")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSString *mimeType __attribute__((swift_name("mimeType")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExerciseDto")))
@interface SharedExerciseDto : SharedBase
- (instancetype)initWithId:(NSString *)id title:(NSString *)title subtitle:(NSString * _Nullable)subtitle __attribute__((swift_name("init(id:title:subtitle:)"))) __attribute__((objc_designated_initializer));
- (SharedExerciseDto *)doCopyId:(NSString *)id title:(NSString *)title subtitle:(NSString * _Nullable)subtitle __attribute__((swift_name("doCopy(id:title:subtitle:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSString * _Nullable subtitle __attribute__((swift_name("subtitle")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("InMemoryCatalog")))
@interface SharedInMemoryCatalog : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)inMemoryCatalog __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedInMemoryCatalog *shared __attribute__((swift_name("shared")));
- (void)clear __attribute__((swift_name("clear()")));
- (NSArray<SharedBeltDto *> *)getBelts __attribute__((swift_name("getBelts()")));
- (SharedExerciseContentDto * _Nullable)getExerciseContentExerciseId:(NSString *)exerciseId __attribute__((swift_name("getExerciseContent(exerciseId:)")));
- (NSArray<SharedExerciseDto *> *)getExercisesBeltId:(NSString *)beltId topicId:(NSString *)topicId subTopicId:(NSString * _Nullable)subTopicId __attribute__((swift_name("getExercises(beltId:topicId:subTopicId:)")));
- (NSArray<SharedSubTopicDto *> *)getSubTopicsBeltId:(NSString *)beltId topicId:(NSString *)topicId __attribute__((swift_name("getSubTopics(beltId:topicId:)")));
- (NSArray<SharedTopicDto *> *)getTopicsBeltId:(NSString *)beltId __attribute__((swift_name("getTopics(beltId:)")));
- (void)setBeltsList:(NSArray<SharedBeltDto *> *)list __attribute__((swift_name("setBelts(list:)")));
- (void)setExerciseContentContent:(SharedExerciseContentDto *)content __attribute__((swift_name("setExerciseContent(content:)")));
- (void)setExercisesBeltId:(NSString *)beltId topicId:(NSString *)topicId subTopicId:(NSString * _Nullable)subTopicId list:(NSArray<SharedExerciseDto *> *)list __attribute__((swift_name("setExercises(beltId:topicId:subTopicId:list:)")));
- (void)setSubTopicsBeltId:(NSString *)beltId topicId:(NSString *)topicId list:(NSArray<SharedSubTopicDto *> *)list __attribute__((swift_name("setSubTopics(beltId:topicId:list:)")));
- (void)setTopicsBeltId:(NSString *)beltId list:(NSArray<SharedTopicDto *> *)list __attribute__((swift_name("setTopics(beltId:list:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KmiCatalogFacade")))
@interface SharedKmiCatalogFacade : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)kmiCatalogFacade __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedKmiCatalogFacade *shared __attribute__((swift_name("shared")));
- (int32_t)countExercisesBeltId:(NSString *)beltId topicId:(NSString *)topicId subTopicId:(NSString * _Nullable)subTopicId __attribute__((swift_name("countExercises(beltId:topicId:subTopicId:)")));
- (SharedExerciseContentDto * _Nullable)getExerciseContentExerciseId:(NSString *)exerciseId __attribute__((swift_name("getExerciseContent(exerciseId:)")));
- (NSString *)getExerciseHtmlExerciseId:(NSString *)exerciseId __attribute__((swift_name("getExerciseHtml(exerciseId:)")));
- (BOOL)hasSubTopicsBeltId:(NSString *)beltId topicId:(NSString *)topicId __attribute__((swift_name("hasSubTopics(beltId:topicId:)")));
- (NSArray<SharedBeltDto *> *)listBelts __attribute__((swift_name("listBelts()")));
- (NSArray<SharedExerciseDto *> *)listExercisesBeltId:(NSString *)beltId topicId:(NSString *)topicId subTopicId:(NSString * _Nullable)subTopicId __attribute__((swift_name("listExercises(beltId:topicId:subTopicId:)")));
- (NSArray<SharedSubTopicDto *> *)listSubTopicsBeltId:(NSString *)beltId topicId:(NSString *)topicId __attribute__((swift_name("listSubTopics(beltId:topicId:)")));
- (NSArray<SharedTopicDto *> *)listTopicsBeltId:(NSString *)beltId __attribute__((swift_name("listTopics(beltId:)")));
- (NSArray<SharedExerciseDto *> *)searchExercisesQuery:(NSString *)query beltId:(NSString * _Nullable)beltId __attribute__((swift_name("searchExercises(query:beltId:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubTopicDto")))
@interface SharedSubTopicDto : SharedBase
- (instancetype)initWithId:(NSString *)id title:(NSString *)title __attribute__((swift_name("init(id:title:)"))) __attribute__((objc_designated_initializer));
- (SharedSubTopicDto *)doCopyId:(NSString *)id title:(NSString *)title __attribute__((swift_name("doCopy(id:title:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TopicDto")))
@interface SharedTopicDto : SharedBase
- (instancetype)initWithId:(NSString *)id title:(NSString *)title __attribute__((swift_name("init(id:title:)"))) __attribute__((objc_designated_initializer));
- (SharedTopicDto *)doCopyId:(NSString *)id title:(NSString *)title __attribute__((swift_name("doCopy(id:title:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Belt")))
@interface SharedBelt : SharedKotlinEnum<SharedBelt *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) SharedBeltCompanion *companion __attribute__((swift_name("companion")));
@property (class, readonly) SharedBelt *white __attribute__((swift_name("white")));
@property (class, readonly) SharedBelt *yellow __attribute__((swift_name("yellow")));
@property (class, readonly) SharedBelt *orange __attribute__((swift_name("orange")));
@property (class, readonly) SharedBelt *green __attribute__((swift_name("green")));
@property (class, readonly) SharedBelt *blue __attribute__((swift_name("blue")));
@property (class, readonly) SharedBelt *brown __attribute__((swift_name("brown")));
@property (class, readonly) SharedBelt *black __attribute__((swift_name("black")));
+ (SharedKotlinArray<SharedBelt *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<SharedBelt *> *entries __attribute__((swift_name("entries")));
@property (readonly) int64_t colorArgb __attribute__((swift_name("colorArgb")));
@property (readonly) NSString *en __attribute__((swift_name("en")));
@property (readonly) NSString *heb __attribute__((swift_name("heb")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) int64_t lightColorArgb __attribute__((swift_name("lightColorArgb")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Belt.Companion")))
@interface SharedBeltCompanion : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedBeltCompanion *shared __attribute__((swift_name("shared")));
- (SharedBelt * _Nullable)fromAnyV:(NSString * _Nullable)v __attribute__((swift_name("fromAny(v:)")));
- (SharedBelt * _Nullable)fromHebHeb:(NSString * _Nullable)heb __attribute__((swift_name("fromHeb(heb:)")));
- (SharedBelt * _Nullable)fromIdId:(id _Nullable)id __attribute__((swift_name("fromId(id:)")));
- (int32_t)indexOfB:(SharedBelt * _Nullable)b __attribute__((swift_name("indexOf(b:)")));
- (BOOL)isLastB:(SharedBelt *)b __attribute__((swift_name("isLast(b:)")));
- (SharedBelt * _Nullable)nextOfBelt:(SharedBelt *)belt __attribute__((swift_name("nextOf(belt:)")));
- (SharedBelt * _Nullable)nextOfAnyV:(NSString * _Nullable)v __attribute__((swift_name("nextOfAny(v:)")));
@property (readonly) NSArray<SharedBelt *> *order __attribute__((swift_name("order")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("CoachRegistry")))
@interface SharedCoachRegistry : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)coachRegistry __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedCoachRegistry *shared __attribute__((swift_name("shared")));
- (NSDictionary<NSString *, NSString *> *)allCoaches __attribute__((swift_name("allCoaches()")));
- (NSString * _Nullable)coachNameCode:(NSString * _Nullable)code __attribute__((swift_name("coachName(code:)")));
- (BOOL)isValidCode:(NSString * _Nullable)code __attribute__((swift_name("isValid(code:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ContentRepo")))
@interface SharedContentRepo : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)contentRepo __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedContentRepo *shared __attribute__((swift_name("shared")));
- (NSString * _Nullable)findExerciseByNameName:(NSString *)name __attribute__((swift_name("findExerciseByName(name:)")));
- (NSString * _Nullable)findSubTopicTitleForItemBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle itemTitle:(NSString *)itemTitle __attribute__((swift_name("findSubTopicTitleForItem(belt:topicTitle:itemTitle:)")));
- (NSArray<NSString *> *)getAllItemsForBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle subTopicTitle:(NSString * _Nullable)subTopicTitle __attribute__((swift_name("getAllItemsFor(belt:topicTitle:subTopicTitle:)")));
- (NSArray<NSString *> *)getNestedItemsForBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle subTopicTitle:(NSString *)subTopicTitle nestedSubTopicTitle:(NSString *)nestedSubTopicTitle __attribute__((swift_name("getNestedItemsFor(belt:topicTitle:subTopicTitle:nestedSubTopicTitle:)")));
- (NSArray<NSString *> *)getNestedSubTopicTitlesBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle subTopicTitle:(NSString *)subTopicTitle __attribute__((swift_name("getNestedSubTopicTitles(belt:topicTitle:subTopicTitle:)")));
- (NSArray<SharedContentRepoSubTopic *> *)getNestedSubTopicsForBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle subTopicTitle:(NSString *)subTopicTitle __attribute__((swift_name("getNestedSubTopicsFor(belt:topicTitle:subTopicTitle:)")));
- (NSArray<NSString *> *)getSubTopicTitlesBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle __attribute__((swift_name("getSubTopicTitles(belt:topicTitle:)")));
- (NSArray<SharedContentRepoSubTopic *> *)getSubTopicsForBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle __attribute__((swift_name("getSubTopicsFor(belt:topicTitle:)")));
- (NSString *)makeItemKeyBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle subTopicTitle:(NSString * _Nullable)subTopicTitle itemTitle:(NSString *)itemTitle __attribute__((swift_name("makeItemKey(belt:topicTitle:subTopicTitle:itemTitle:)")));
- (SharedContentRepoResolvedItem * _Nullable)resolveItemKeyKey:(NSString *)key __attribute__((swift_name("resolveItemKey(key:)")));
- (NSArray<SharedContentRepoSearchHit *> *)searchExercisesQuery:(NSString *)query __attribute__((swift_name("searchExercises(query:)")));
@property (readonly) NSDictionary<SharedBelt *, SharedContentRepoBeltContent *> *data __attribute__((swift_name("data")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ContentRepo.BeltContent")))
@interface SharedContentRepoBeltContent : SharedBase
- (instancetype)initWithBelt:(SharedBelt *)belt topics:(NSArray<SharedContentRepoTopic *> *)topics __attribute__((swift_name("init(belt:topics:)"))) __attribute__((objc_designated_initializer));
- (SharedContentRepoBeltContent *)doCopyBelt:(SharedBelt *)belt topics:(NSArray<SharedContentRepoTopic *> *)topics __attribute__((swift_name("doCopy(belt:topics:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SharedBelt *belt __attribute__((swift_name("belt")));
@property (readonly) NSArray<SharedContentRepoTopic *> *topics __attribute__((swift_name("topics")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ContentRepo.ResolvedItem")))
@interface SharedContentRepoResolvedItem : SharedBase
- (instancetype)initWithBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle subTopicTitle:(NSString * _Nullable)subTopicTitle itemTitle:(NSString *)itemTitle __attribute__((swift_name("init(belt:topicTitle:subTopicTitle:itemTitle:)"))) __attribute__((objc_designated_initializer));
- (SharedContentRepoResolvedItem *)doCopyBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle subTopicTitle:(NSString * _Nullable)subTopicTitle itemTitle:(NSString *)itemTitle __attribute__((swift_name("doCopy(belt:topicTitle:subTopicTitle:itemTitle:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SharedBelt *belt __attribute__((swift_name("belt")));
@property (readonly) NSString *itemTitle __attribute__((swift_name("itemTitle")));
@property (readonly) NSString * _Nullable subTopicTitle __attribute__((swift_name("subTopicTitle")));
@property (readonly) NSString *topicTitle __attribute__((swift_name("topicTitle")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ContentRepo.SearchHit")))
@interface SharedContentRepoSearchHit : SharedBase
- (instancetype)initWithId:(NSString * _Nullable)id title:(NSString *)title subtitle:(NSString * _Nullable)subtitle __attribute__((swift_name("init(id:title:subtitle:)"))) __attribute__((objc_designated_initializer));
- (SharedContentRepoSearchHit *)doCopyId:(NSString * _Nullable)id title:(NSString *)title subtitle:(NSString * _Nullable)subtitle __attribute__((swift_name("doCopy(id:title:subtitle:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable id __attribute__((swift_name("id")));
@property (readonly) NSString * _Nullable subtitle __attribute__((swift_name("subtitle")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ContentRepo.SubTopic")))
@interface SharedContentRepoSubTopic : SharedBase
- (instancetype)initWithTitle:(NSString *)title items:(NSArray<NSString *> *)items subTopics:(NSArray<SharedContentRepoSubTopic *> *)subTopics __attribute__((swift_name("init(title:items:subTopics:)"))) __attribute__((objc_designated_initializer));
- (SharedContentRepoSubTopic *)doCopyTitle:(NSString *)title items:(NSArray<NSString *> *)items subTopics:(NSArray<SharedContentRepoSubTopic *> *)subTopics __attribute__((swift_name("doCopy(title:items:subTopics:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<NSString *> *items __attribute__((swift_name("items")));
@property (readonly) NSArray<SharedContentRepoSubTopic *> *subTopics __attribute__((swift_name("subTopics")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ContentRepo.Topic")))
@interface SharedContentRepoTopic : SharedBase
- (instancetype)initWithTitle:(NSString *)title items:(NSArray<NSString *> *)items subTopics:(NSArray<SharedContentRepoSubTopic *> *)subTopics __attribute__((swift_name("init(title:items:subTopics:)"))) __attribute__((objc_designated_initializer));
- (SharedContentRepoTopic *)doCopyTitle:(NSString *)title items:(NSArray<NSString *> *)items subTopics:(NSArray<SharedContentRepoSubTopic *> *)subTopics __attribute__((swift_name("doCopy(title:items:subTopics:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<NSString *> *items __attribute__((swift_name("items")));
@property (readonly) NSArray<SharedContentRepoSubTopic *> *subTopics __attribute__((swift_name("subTopics")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Explanations")))
@interface SharedExplanations : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)explanations __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedExplanations *shared __attribute__((swift_name("shared")));
- (NSArray<SharedExplanationsExplanationAuditRow *> *)auditKnownExerciseExplanations __attribute__((swift_name("auditKnownExerciseExplanations()")));
- (NSArray<NSArray<SharedExplanationsExplanationAuditRow *> *> *)duplicateKnownExplanationGroups __attribute__((swift_name("duplicateKnownExplanationGroups()")));
- (NSString *)getBelt:(SharedBelt *)belt item:(NSString *)item __attribute__((swift_name("get(belt:item:)")));
- (NSString *)getBelt:(SharedBelt *)belt item:(NSString *)item exerciseId:(NSString * _Nullable)exerciseId __attribute__((swift_name("get(belt:item:exerciseId:)")));
- (NSString *)getByExerciseIdExerciseId:(NSString *)exerciseId fallbackBelt:(SharedBelt *)fallbackBelt fallbackItem:(NSString *)fallbackItem __attribute__((swift_name("getByExerciseId(exerciseId:fallbackBelt:fallbackItem:)")));
- (void)logKnownExerciseExplanationsAuditTag:(NSString *)tag maxRows:(int32_t)maxRows __attribute__((swift_name("logKnownExerciseExplanationsAudit(tag:maxRows:)")));
- (NSArray<SharedExplanationsExplanationAuditRow *> *)missingKnownExerciseExplanations __attribute__((swift_name("missingKnownExerciseExplanations()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Explanations.ExplanationAuditRow")))
@interface SharedExplanationsExplanationAuditRow : SharedBase
- (instancetype)initWithExerciseId:(NSString *)exerciseId belt:(SharedBelt *)belt title:(NSString *)title hasExplanation:(BOOL)hasExplanation explanationPreview:(NSString *)explanationPreview __attribute__((swift_name("init(exerciseId:belt:title:hasExplanation:explanationPreview:)"))) __attribute__((objc_designated_initializer));
- (SharedExplanationsExplanationAuditRow *)doCopyExerciseId:(NSString *)exerciseId belt:(SharedBelt *)belt title:(NSString *)title hasExplanation:(BOOL)hasExplanation explanationPreview:(NSString *)explanationPreview __attribute__((swift_name("doCopy(exerciseId:belt:title:hasExplanation:explanationPreview:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SharedBelt *belt __attribute__((swift_name("belt")));
@property (readonly) NSString *exerciseId __attribute__((swift_name("exerciseId")));
@property (readonly) NSString *explanationPreview __attribute__((swift_name("explanationPreview")));
@property (readonly) BOOL hasExplanation __attribute__((swift_name("hasExplanation")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubTopicRegistry")))
@interface SharedSubTopicRegistry : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)subTopicRegistry __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedSubTopicRegistry *shared __attribute__((swift_name("shared")));
- (NSDictionary<NSString *, NSArray<NSString *> *> *)allForBeltBelt:(SharedBelt *)belt __attribute__((swift_name("allForBelt(belt:)")));
- (NSArray<NSString *> *)getItemsForBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle subTopicTitle:(NSString *)subTopicTitle __attribute__((swift_name("getItemsFor(belt:topicTitle:subTopicTitle:)")));
- (NSArray<NSString *> *)getSubTopicsForBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle __attribute__((swift_name("getSubTopicsFor(belt:topicTitle:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubjectTopic")))
@interface SharedSubjectTopic : SharedBase
- (instancetype)initWithId:(NSString *)id titleHeb:(NSString *)titleHeb topicsByBelt:(NSDictionary<SharedBelt *, NSArray<NSString *> *> *)topicsByBelt subTopicHint:(NSString * _Nullable)subTopicHint includeItemKeywords:(NSArray<NSString *> *)includeItemKeywords requireAllItemKeywords:(NSArray<NSString *> *)requireAllItemKeywords excludeItemKeywords:(NSArray<NSString *> *)excludeItemKeywords __attribute__((swift_name("init(id:titleHeb:topicsByBelt:subTopicHint:includeItemKeywords:requireAllItemKeywords:excludeItemKeywords:)"))) __attribute__((objc_designated_initializer));
- (SharedSubjectTopic *)doCopyId:(NSString *)id titleHeb:(NSString *)titleHeb topicsByBelt:(NSDictionary<SharedBelt *, NSArray<NSString *> *> *)topicsByBelt subTopicHint:(NSString * _Nullable)subTopicHint includeItemKeywords:(NSArray<NSString *> *)includeItemKeywords requireAllItemKeywords:(NSArray<NSString *> *)requireAllItemKeywords excludeItemKeywords:(NSArray<NSString *> *)excludeItemKeywords __attribute__((swift_name("doCopy(id:titleHeb:topicsByBelt:subTopicHint:includeItemKeywords:requireAllItemKeywords:excludeItemKeywords:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<NSString *> *excludeItemKeywords __attribute__((swift_name("excludeItemKeywords")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSArray<NSString *> *includeItemKeywords __attribute__((swift_name("includeItemKeywords")));
@property (readonly) NSArray<NSString *> *requireAllItemKeywords __attribute__((swift_name("requireAllItemKeywords")));
@property (readonly) NSString * _Nullable subTopicHint __attribute__((swift_name("subTopicHint")));
@property (readonly) NSString *titleHeb __attribute__((swift_name("titleHeb")));
@property (readonly) NSDictionary<SharedBelt *, NSArray<NSString *> *> *topicsByBelt __attribute__((swift_name("topicsByBelt")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TopicsEngine")))
@interface SharedTopicsEngine : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)topicsEngine __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedTopicsEngine *shared __attribute__((swift_name("shared")));
- (NSArray<NSString *> *)subTopicTitlesForBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle __attribute__((swift_name("subTopicTitlesFor(belt:topicTitle:)")));
- (SharedTopicsEngineTopicDetails *)topicDetailsForBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle __attribute__((swift_name("topicDetailsFor(belt:topicTitle:)")));
- (NSArray<NSString *> *)topicTitlesForBelt:(SharedBelt *)belt __attribute__((swift_name("topicTitlesFor(belt:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TopicsEngine.TopicDetails")))
@interface SharedTopicsEngineTopicDetails : SharedBase
- (instancetype)initWithItemCount:(int32_t)itemCount subTitles:(NSArray<NSString *> *)subTitles __attribute__((swift_name("init(itemCount:subTitles:)"))) __attribute__((objc_designated_initializer));
- (SharedTopicsEngineTopicDetails *)doCopyItemCount:(int32_t)itemCount subTitles:(NSArray<NSString *> *)subTitles __attribute__((swift_name("doCopy(itemCount:subTitles:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int32_t itemCount __attribute__((swift_name("itemCount")));
@property (readonly) NSArray<NSString *> *subTitles __attribute__((swift_name("subTitles")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("UserRole")))
@interface SharedUserRole : SharedKotlinEnum<SharedUserRole *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) SharedUserRoleCompanion *companion __attribute__((swift_name("companion")));
@property (class, readonly) SharedUserRole *coach __attribute__((swift_name("coach")));
@property (class, readonly) SharedUserRole *trainee __attribute__((swift_name("trainee")));
+ (SharedKotlinArray<SharedUserRole *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<SharedUserRole *> *entries __attribute__((swift_name("entries")));
@property (readonly) NSString *heb __attribute__((swift_name("heb")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("UserRole.Companion")))
@interface SharedUserRoleCompanion : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedUserRoleCompanion *shared __attribute__((swift_name("shared")));
- (SharedUserRole * _Nullable)fromIdId:(NSString * _Nullable)id __attribute__((swift_name("fromId(id:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("CatalogRepo")))
@interface SharedCatalogRepo : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)catalogRepo __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedCatalogRepo *shared __attribute__((swift_name("shared")));
- (SharedCatalogTopic * _Nullable)findTopicBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle __attribute__((swift_name("findTopic(belt:topicTitle:)")));
- (BOOL)hasTopicBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle __attribute__((swift_name("hasTopic(belt:topicTitle:)")));
- (NSArray<NSString *> *)listItemsBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle subTopicTitle:(NSString * _Nullable)subTopicTitle __attribute__((swift_name("listItems(belt:topicTitle:subTopicTitle:)")));
- (NSArray<NSString *> *)listSubTopicTitlesBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle __attribute__((swift_name("listSubTopicTitles(belt:topicTitle:)")));
- (NSArray<NSString *> *)listTopicTitlesBelt:(SharedBelt *)belt __attribute__((swift_name("listTopicTitles(belt:)")));
- (void)warmUp __attribute__((swift_name("warmUp()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("CatalogRepoBuilder")))
@interface SharedCatalogRepoBuilder : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)catalogRepoBuilder __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedCatalogRepoBuilder *shared __attribute__((swift_name("shared")));
- (NSArray<SharedCatalogTopic *> *)buildTopicsForBeltBelt:(SharedBelt *)belt __attribute__((swift_name("buildTopicsForBelt(belt:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("CatalogSubTopic")))
@interface SharedCatalogSubTopic : SharedBase
- (instancetype)initWithTitle:(NSString *)title items:(NSArray<NSString *> *)items __attribute__((swift_name("init(title:items:)"))) __attribute__((objc_designated_initializer));
- (SharedCatalogSubTopic *)doCopyTitle:(NSString *)title items:(NSArray<NSString *> *)items __attribute__((swift_name("doCopy(title:items:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<NSString *> *items __attribute__((swift_name("items")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("CatalogTopic")))
@interface SharedCatalogTopic : SharedBase
- (instancetype)initWithTitle:(NSString *)title items:(NSArray<NSString *> *)items subTopics:(NSArray<SharedCatalogSubTopic *> *)subTopics __attribute__((swift_name("init(title:items:subTopics:)"))) __attribute__((objc_designated_initializer));
- (SharedCatalogTopic *)doCopyTitle:(NSString *)title items:(NSArray<NSString *> *)items subTopics:(NSArray<SharedCatalogSubTopic *> *)subTopics __attribute__((swift_name("doCopy(title:items:subTopics:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<NSString *> *items __attribute__((swift_name("items")));
@property (readonly) NSArray<SharedCatalogSubTopic *> *subTopics __attribute__((swift_name("subTopics")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Canonical")))
@interface SharedCanonical : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)canonical __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedCanonical *shared __attribute__((swift_name("shared")));
- (NSString *)canonicalItemIdBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle subTopicTitle:(NSString * _Nullable)subTopicTitle rawItem:(NSString *)rawItem __attribute__((swift_name("canonicalItemId(belt:topicTitle:subTopicTitle:rawItem:)")));
- (NSString *)normHeb:(NSString *)receiver __attribute__((swift_name("normHeb(_:)")));
- (SharedCanonicalParsedItem *)parseDefenseTagAndNameRaw:(NSString *)raw __attribute__((swift_name("parseDefenseTagAndName(raw:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Canonical.ParsedItem")))
@interface SharedCanonicalParsedItem : SharedBase
- (instancetype)initWithRaw:(NSString *)raw displayName:(NSString *)displayName tag:(NSString *)tag __attribute__((swift_name("init(raw:displayName:tag:)"))) __attribute__((objc_designated_initializer));
- (SharedCanonicalParsedItem *)doCopyRaw:(NSString *)raw displayName:(NSString *)displayName tag:(NSString *)tag __attribute__((swift_name("doCopy(raw:displayName:tag:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *displayName __attribute__((swift_name("displayName")));
@property (readonly) NSString *raw __attribute__((swift_name("raw")));
@property (readonly) NSString *tag __attribute__((swift_name("tag")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExerciseExplanationsEn")))
@interface SharedExerciseExplanationsEn : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)exerciseExplanationsEn __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedExerciseExplanationsEn *shared __attribute__((swift_name("shared")));
- (NSString *)getBelt:(SharedBelt *)belt item:(NSString *)item __attribute__((swift_name("get(belt:item:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExerciseTitlesEnAliases")))
@interface SharedExerciseTitlesEnAliases : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)exerciseTitlesEnAliases __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedExerciseTitlesEnAliases *shared __attribute__((swift_name("shared")));
@property (readonly) NSDictionary<NSString *, NSString *> *map __attribute__((swift_name("map")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExerciseTitlesEnItems")))
@interface SharedExerciseTitlesEnItems : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)exerciseTitlesEnItems __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedExerciseTitlesEnItems *shared __attribute__((swift_name("shared")));
@property (readonly) NSDictionary<NSString *, NSString *> *map __attribute__((swift_name("map")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExerciseTitlesEnTopics")))
@interface SharedExerciseTitlesEnTopics : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)exerciseTitlesEnTopics __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedExerciseTitlesEnTopics *shared __attribute__((swift_name("shared")));
@property (readonly) NSDictionary<NSString *, NSString *> *map __attribute__((swift_name("map")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExerciseIdentityRegistry")))
@interface SharedExerciseIdentityRegistry : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)exerciseIdentityRegistry __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedExerciseIdentityRegistry *shared __attribute__((swift_name("shared")));
- (NSArray<SharedExerciseIdentityRegistryExerciseIdentity *> *)allKnown __attribute__((swift_name("allKnown()")));
- (NSSet<NSString *> *)allKnownIds __attribute__((swift_name("allKnownIds()")));
- (SharedExerciseIdentityRegistryAuditReport *)auditAgainstContentRepo __attribute__((swift_name("auditAgainstContentRepo()")));
- (NSString *)favoritePrefsKeyExerciseId:(NSString *)exerciseId __attribute__((swift_name("favoritePrefsKey(exerciseId:)")));
- (NSString *)idForBelt:(SharedBelt *)belt hebrewTitle:(NSString *)hebrewTitle topicKey:(NSString * _Nullable)topicKey __attribute__((swift_name("idFor(belt:hebrewTitle:topicKey:)")));
- (BOOL)isKnownIdId:(NSString *)id __attribute__((swift_name("isKnownId(id:)")));
- (SharedExerciseIdentityRegistryExerciseIdentity * _Nullable)knownByIdId:(NSString *)id __attribute__((swift_name("knownById(id:)")));
- (NSString *)normalizeRaw:(NSString *)raw __attribute__((swift_name("normalize(raw:)")));
- (NSString *)notePrefsKeyExerciseId:(NSString *)exerciseId __attribute__((swift_name("notePrefsKey(exerciseId:)")));
- (SharedExerciseIdentityRegistryResolvedExerciseIdentity *)resolveBelt:(SharedBelt *)belt hebrewTitle:(NSString *)hebrewTitle topicKey:(NSString * _Nullable)topicKey __attribute__((swift_name("resolve(belt:hebrewTitle:topicKey:)")));
- (NSString *)statusPrefsKeyExerciseId:(NSString *)exerciseId __attribute__((swift_name("statusPrefsKey(exerciseId:)")));
@property (readonly) NSArray<SharedExerciseIdentityRegistryExerciseIdentity *> *knownExercises __attribute__((swift_name("knownExercises")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExerciseIdentityRegistry.AuditReport")))
@interface SharedExerciseIdentityRegistryAuditReport : SharedBase
- (instancetype)initWithTotalRows:(int32_t)totalRows knownRows:(int32_t)knownRows legacyRows:(NSArray<SharedExerciseIdentityRegistryAuditRow *> *)legacyRows duplicateIds:(NSDictionary<NSString *, SharedInt *> *)duplicateIds knownIdsCount:(int32_t)knownIdsCount __attribute__((swift_name("init(totalRows:knownRows:legacyRows:duplicateIds:knownIdsCount:)"))) __attribute__((objc_designated_initializer));
- (SharedExerciseIdentityRegistryAuditReport *)doCopyTotalRows:(int32_t)totalRows knownRows:(int32_t)knownRows legacyRows:(NSArray<SharedExerciseIdentityRegistryAuditRow *> *)legacyRows duplicateIds:(NSDictionary<NSString *, SharedInt *> *)duplicateIds knownIdsCount:(int32_t)knownIdsCount __attribute__((swift_name("doCopy(totalRows:knownRows:legacyRows:duplicateIds:knownIdsCount:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSArray<NSString *> *)toLogLinesLimit:(int32_t)limit __attribute__((swift_name("toLogLines(limit:)")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSDictionary<NSString *, SharedInt *> *duplicateIds __attribute__((swift_name("duplicateIds")));
@property (readonly) int32_t knownIdsCount __attribute__((swift_name("knownIdsCount")));
@property (readonly) int32_t knownRows __attribute__((swift_name("knownRows")));
@property (readonly) NSArray<SharedExerciseIdentityRegistryAuditRow *> *legacyRows __attribute__((swift_name("legacyRows")));
@property (readonly) int32_t totalRows __attribute__((swift_name("totalRows")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExerciseIdentityRegistry.AuditRow")))
@interface SharedExerciseIdentityRegistryAuditRow : SharedBase
- (instancetype)initWithBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle subTopicTitle:(NSString * _Nullable)subTopicTitle index:(int32_t)index rawTitle:(NSString *)rawTitle resolvedId:(NSString *)resolvedId isKnown:(BOOL)isKnown __attribute__((swift_name("init(belt:topicTitle:subTopicTitle:index:rawTitle:resolvedId:isKnown:)"))) __attribute__((objc_designated_initializer));
- (SharedExerciseIdentityRegistryAuditRow *)doCopyBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle subTopicTitle:(NSString * _Nullable)subTopicTitle index:(int32_t)index rawTitle:(NSString *)rawTitle resolvedId:(NSString *)resolvedId isKnown:(BOOL)isKnown __attribute__((swift_name("doCopy(belt:topicTitle:subTopicTitle:index:rawTitle:resolvedId:isKnown:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SharedBelt *belt __attribute__((swift_name("belt")));
@property (readonly) int32_t index __attribute__((swift_name("index")));
@property (readonly) BOOL isKnown __attribute__((swift_name("isKnown")));
@property (readonly) NSString *rawTitle __attribute__((swift_name("rawTitle")));
@property (readonly) NSString *resolvedId __attribute__((swift_name("resolvedId")));
@property (readonly) NSString * _Nullable subTopicTitle __attribute__((swift_name("subTopicTitle")));
@property (readonly) NSString *topicTitle __attribute__((swift_name("topicTitle")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExerciseIdentityRegistry.ExerciseIdentity")))
@interface SharedExerciseIdentityRegistryExerciseIdentity : SharedBase
- (instancetype)initWithId:(NSString *)id belt:(SharedBelt *)belt hebrewTitle:(NSString *)hebrewTitle topicKeys:(NSSet<NSString *> *)topicKeys aliases:(NSSet<NSString *> *)aliases __attribute__((swift_name("init(id:belt:hebrewTitle:topicKeys:aliases:)"))) __attribute__((objc_designated_initializer));
- (SharedExerciseIdentityRegistryExerciseIdentity *)doCopyId:(NSString *)id belt:(SharedBelt *)belt hebrewTitle:(NSString *)hebrewTitle topicKeys:(NSSet<NSString *> *)topicKeys aliases:(NSSet<NSString *> *)aliases __attribute__((swift_name("doCopy(id:belt:hebrewTitle:topicKeys:aliases:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSSet<NSString *> *aliases __attribute__((swift_name("aliases")));
@property (readonly) SharedBelt *belt __attribute__((swift_name("belt")));
@property (readonly) NSString *hebrewTitle __attribute__((swift_name("hebrewTitle")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSSet<NSString *> *topicKeys __attribute__((swift_name("topicKeys")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExerciseIdentityRegistry.ResolvedExerciseIdentity")))
@interface SharedExerciseIdentityRegistryResolvedExerciseIdentity : SharedBase
- (instancetype)initWithId:(NSString *)id isKnown:(BOOL)isKnown belt:(SharedBelt *)belt hebrewTitle:(NSString *)hebrewTitle topicKey:(NSString * _Nullable)topicKey __attribute__((swift_name("init(id:isKnown:belt:hebrewTitle:topicKey:)"))) __attribute__((objc_designated_initializer));
- (SharedExerciseIdentityRegistryResolvedExerciseIdentity *)doCopyId:(NSString *)id isKnown:(BOOL)isKnown belt:(SharedBelt *)belt hebrewTitle:(NSString *)hebrewTitle topicKey:(NSString * _Nullable)topicKey __attribute__((swift_name("doCopy(id:isKnown:belt:hebrewTitle:topicKey:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SharedBelt *belt __attribute__((swift_name("belt")));
@property (readonly) NSString *hebrewTitle __attribute__((swift_name("hebrewTitle")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) BOOL isKnown __attribute__((swift_name("isKnown")));
@property (readonly) NSString * _Nullable topicKey __attribute__((swift_name("topicKey")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExerciseTitlesEn")))
@interface SharedExerciseTitlesEn : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)exerciseTitlesEn __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedExerciseTitlesEn *shared __attribute__((swift_name("shared")));
- (NSString *)displayNameText:(NSString *)text isEnglish:(BOOL)isEnglish __attribute__((swift_name("displayName(text:isEnglish:)")));
- (NSString * _Nullable)getHebrew:(NSString *)hebrew __attribute__((swift_name("get(hebrew:)")));
- (NSString *)getOrSameText:(NSString *)text __attribute__((swift_name("getOrSame(text:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HardSectionsCatalog")))
@interface SharedHardSectionsCatalog : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)hardSectionsCatalog __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedHardSectionsCatalog *shared __attribute__((swift_name("shared")));
- (NSString *)canonicalDefenseKindRaw:(NSString *)raw __attribute__((swift_name("canonicalDefenseKind(raw:)")));
- (NSString *)canonicalDefensePickRaw:(NSString *)raw __attribute__((swift_name("canonicalDefensePick(raw:)")));
- (int32_t)defenseCountKindRaw:(NSString *)kindRaw pickRaw:(NSString *)pickRaw __attribute__((swift_name("defenseCount(kindRaw:pickRaw:)")));
- (NSDictionary<NSString *, SharedInt *> *)defenseDialogCounts __attribute__((swift_name("defenseDialogCounts()")));
- (NSArray<SharedKotlinPair<SharedBelt *, NSArray<NSString *> *> *> *)defenseItemsForKindRaw:(NSString *)kindRaw pickRaw:(NSString *)pickRaw __attribute__((swift_name("defenseItemsFor(kindRaw:pickRaw:)")));
- (NSArray<SharedKotlinPair<SharedBelt *, NSArray<SharedKotlinPair<NSString *, NSString *> *> *> *> *)defenseItemsForDisplayKindRaw:(NSString *)kindRaw pickRaw:(NSString *)pickRaw isEnglish:(BOOL)isEnglish __attribute__((swift_name("defenseItemsForDisplay(kindRaw:pickRaw:isEnglish:)")));
- (NSString *)defenseScreenTitleKindRaw:(NSString *)kindRaw pickRaw:(NSString *)pickRaw __attribute__((swift_name("defenseScreenTitle(kindRaw:pickRaw:)")));
- (int32_t)directItemsCount:(SharedHardSectionsCatalogSection *)receiver __attribute__((swift_name("directItemsCount(_:)")));
- (SharedHardSectionsCatalogSection * _Nullable)findAnySectionByIdSectionId:(NSString *)sectionId __attribute__((swift_name("findAnySectionById(sectionId:)")));
- (SharedHardSectionsCatalogSection * _Nullable)findSectionByIdSubjectId:(NSString *)subjectId sectionId:(NSString *)sectionId __attribute__((swift_name("findSectionById(subjectId:sectionId:)")));
- (NSArray<SharedHardSectionsCatalogSection *> *)findSectionPathSubjectId:(NSString *)subjectId sectionId:(NSString *)sectionId __attribute__((swift_name("findSectionPath(subjectId:sectionId:)")));
- (BOOL)hasItems:(SharedHardSectionsCatalogSection *)receiver __attribute__((swift_name("hasItems(_:)")));
- (BOOL)isLeaf:(SharedHardSectionsCatalogSection *)receiver __attribute__((swift_name("isLeaf(_:)")));
- (NSArray<NSString *> *)itemsFor:(SharedHardSectionsCatalogSection *)receiver belt:(SharedBelt *)belt __attribute__((swift_name("itemsFor(_:belt:)")));
- (NSDictionary<NSString *, SharedInt *> *)kicksHardSubCounts __attribute__((swift_name("kicksHardSubCounts()")));
- (NSArray<SharedHardSectionsCatalogSection *> * _Nullable)sectionsForSubjectSubjectId:(NSString *)subjectId __attribute__((swift_name("sectionsForSubject(subjectId:)")));
- (NSString *)stripDefenseItemPrefixKindRaw:(NSString *)kindRaw pickRaw:(NSString *)pickRaw full:(NSString *)full __attribute__((swift_name("stripDefenseItemPrefix(kindRaw:pickRaw:full:)")));
- (NSString * _Nullable)subjectDisplayTitleSubjectId:(NSString *)subjectId __attribute__((swift_name("subjectDisplayTitle(subjectId:)")));
- (NSArray<NSString *> *)subjectItemsForSubjectId:(NSString *)subjectId belt:(SharedBelt *)belt __attribute__((swift_name("subjectItemsFor(subjectId:belt:)")));
- (NSArray<SharedKotlinPair<NSString *, NSString *> *> *)subjectItemsForDisplaySubjectId:(NSString *)subjectId belt:(SharedBelt *)belt isEnglish:(BOOL)isEnglish __attribute__((swift_name("subjectItemsForDisplay(subjectId:belt:isEnglish:)")));
- (NSArray<NSString *> *)subjectSubSectionItemsForSubjectId:(NSString *)subjectId subSectionId:(NSString *)subSectionId belt:(SharedBelt *)belt __attribute__((swift_name("subjectSubSectionItemsFor(subjectId:subSectionId:belt:)")));
- (NSArray<SharedKotlinPair<NSString *, NSString *> *> *)subjectSubSectionItemsForDisplaySubjectId:(NSString *)subjectId subSectionId:(NSString *)subSectionId belt:(SharedBelt *)belt isEnglish:(BOOL)isEnglish __attribute__((swift_name("subjectSubSectionItemsForDisplay(subjectId:subSectionId:belt:isEnglish:)")));
- (NSArray<SharedHardSectionsCatalogSection *> *)subjectSubSectionsForSubjectId:(NSString *)subjectId __attribute__((swift_name("subjectSubSectionsFor(subjectId:)")));
- (BOOL)supportsSubjectSubjectId:(NSString *)subjectId __attribute__((swift_name("supportsSubject(subjectId:)")));
- (int32_t)totalDefenseCount __attribute__((swift_name("totalDefenseCount()")));
- (int32_t)totalItemsCount:(SharedHardSectionsCatalogSection *)receiver __attribute__((swift_name("totalItemsCount(_:)")));
@property (readonly) NSArray<SharedBelt *> *beltOrder __attribute__((swift_name("beltOrder")));
@property (readonly) NSArray<SharedHardSectionsCatalogSection *> *defensesExternalPunch __attribute__((swift_name("defensesExternalPunch")));
@property (readonly) NSArray<SharedHardSectionsCatalogSection *> *defensesGunThreat __attribute__((swift_name("defensesGunThreat")));
@property (readonly) NSArray<SharedHardSectionsCatalogSection *> *defensesInternalPunch __attribute__((swift_name("defensesInternalPunch")));
@property (readonly) NSArray<SharedHardSectionsCatalogSection *> *defensesKicks __attribute__((swift_name("defensesKicks")));
@property (readonly) NSArray<SharedHardSectionsCatalogSection *> *defensesKnife __attribute__((swift_name("defensesKnife")));
@property (readonly) NSArray<SharedHardSectionsCatalogSection *> *defensesMultipleAttackers __attribute__((swift_name("defensesMultipleAttackers")));
@property (readonly) NSArray<SharedHardSectionsCatalogSection *> *defensesRoot __attribute__((swift_name("defensesRoot")));
@property (readonly) NSArray<SharedHardSectionsCatalogSection *> *defensesStick __attribute__((swift_name("defensesStick")));
@property (readonly) NSArray<SharedHardSectionsCatalogSection *> *handsAll __attribute__((swift_name("handsAll")));
@property (readonly) NSArray<SharedHardSectionsCatalogSection *> *releases __attribute__((swift_name("releases")));
@property (readonly) NSSet<NSString *> *supportedSubjectIds __attribute__((swift_name("supportedSubjectIds")));
@property (readonly) NSArray<SharedHardSectionsCatalogSection *> *topicBreakfallsRolls __attribute__((swift_name("topicBreakfallsRolls")));
@property (readonly) NSArray<SharedHardSectionsCatalogSection *> *topicGeneral __attribute__((swift_name("topicGeneral")));
@property (readonly) NSArray<SharedHardSectionsCatalogSection *> *topicGroundPrep __attribute__((swift_name("topicGroundPrep")));
@property (readonly) NSArray<SharedHardSectionsCatalogSection *> *topicKavaler __attribute__((swift_name("topicKavaler")));
@property (readonly) NSArray<SharedHardSectionsCatalogSection *> *topicKicks __attribute__((swift_name("topicKicks")));
@property (readonly) NSArray<SharedHardSectionsCatalogSection *> *topicReadyStance __attribute__((swift_name("topicReadyStance")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HardSectionsCatalog.BeltGroup")))
@interface SharedHardSectionsCatalogBeltGroup : SharedBase
- (instancetype)initWithBelt:(SharedBelt *)belt items:(NSArray<NSString *> *)items __attribute__((swift_name("init(belt:items:)"))) __attribute__((objc_designated_initializer));
- (SharedHardSectionsCatalogBeltGroup *)doCopyBelt:(SharedBelt *)belt items:(NSArray<NSString *> *)items __attribute__((swift_name("doCopy(belt:items:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SharedBelt *belt __attribute__((swift_name("belt")));
@property (readonly) NSArray<NSString *> *items __attribute__((swift_name("items")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HardSectionsCatalog.Section")))
@interface SharedHardSectionsCatalogSection : SharedBase
- (instancetype)initWithId:(NSString *)id title:(NSString *)title beltGroups:(NSArray<SharedHardSectionsCatalogBeltGroup *> *)beltGroups subSections:(NSArray<SharedHardSectionsCatalogSection *> *)subSections __attribute__((swift_name("init(id:title:beltGroups:subSections:)"))) __attribute__((objc_designated_initializer));
- (SharedHardSectionsCatalogSection *)doCopyId:(NSString *)id title:(NSString *)title beltGroups:(NSArray<SharedHardSectionsCatalogBeltGroup *> *)beltGroups subSections:(NSArray<SharedHardSectionsCatalogSection *> *)subSections __attribute__((swift_name("doCopy(id:title:beltGroups:subSections:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<SharedHardSectionsCatalogBeltGroup *> *beltGroups __attribute__((swift_name("beltGroups")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSArray<SharedHardSectionsCatalogSection *> *subSections __attribute__((swift_name("subSections")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HardSectionsResolver")))
@interface SharedHardSectionsResolver : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)hardSectionsResolver __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedHardSectionsResolver *shared __attribute__((swift_name("shared")));
- (id<SharedHardSectionsResolverNodeResult> _Nullable)resolveSubjectId:(NSString *)subjectId sectionId:(NSString * _Nullable)sectionId __attribute__((swift_name("resolve(subjectId:sectionId:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HardSectionsResolver.BeltItems")))
@interface SharedHardSectionsResolverBeltItems : SharedBase
- (instancetype)initWithBelt:(SharedBelt *)belt items:(NSArray<NSString *> *)items __attribute__((swift_name("init(belt:items:)"))) __attribute__((objc_designated_initializer));
- (SharedHardSectionsResolverBeltItems *)doCopyBelt:(SharedBelt *)belt items:(NSArray<NSString *> *)items __attribute__((swift_name("doCopy(belt:items:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SharedBelt *belt __attribute__((swift_name("belt")));
@property (readonly) NSArray<NSString *> *items __attribute__((swift_name("items")));
@end

__attribute__((swift_name("HardSectionsResolverNodeResult")))
@protocol SharedHardSectionsResolverNodeResult
@required
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HardSectionsResolverNodeResultBeltGroups")))
@interface SharedHardSectionsResolverNodeResultBeltGroups : SharedBase <SharedHardSectionsResolverNodeResult>
- (instancetype)initWithSubjectId:(NSString *)subjectId currentSectionId:(NSString *)currentSectionId title:(NSString *)title groups:(NSArray<SharedHardSectionsResolverBeltItems *> *)groups __attribute__((swift_name("init(subjectId:currentSectionId:title:groups:)"))) __attribute__((objc_designated_initializer));
- (SharedHardSectionsResolverNodeResultBeltGroups *)doCopySubjectId:(NSString *)subjectId currentSectionId:(NSString *)currentSectionId title:(NSString *)title groups:(NSArray<SharedHardSectionsResolverBeltItems *> *)groups __attribute__((swift_name("doCopy(subjectId:currentSectionId:title:groups:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *currentSectionId __attribute__((swift_name("currentSectionId")));
@property (readonly) NSArray<SharedHardSectionsResolverBeltItems *> *groups __attribute__((swift_name("groups")));
@property (readonly) NSString *subjectId __attribute__((swift_name("subjectId")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HardSectionsResolverNodeResultSections")))
@interface SharedHardSectionsResolverNodeResultSections : SharedBase <SharedHardSectionsResolverNodeResult>
- (instancetype)initWithSubjectId:(NSString *)subjectId currentSectionId:(NSString * _Nullable)currentSectionId title:(NSString * _Nullable)title entries:(NSArray<SharedHardSectionsResolverSectionEntry *> *)entries __attribute__((swift_name("init(subjectId:currentSectionId:title:entries:)"))) __attribute__((objc_designated_initializer));
- (SharedHardSectionsResolverNodeResultSections *)doCopySubjectId:(NSString *)subjectId currentSectionId:(NSString * _Nullable)currentSectionId title:(NSString * _Nullable)title entries:(NSArray<SharedHardSectionsResolverSectionEntry *> *)entries __attribute__((swift_name("doCopy(subjectId:currentSectionId:title:entries:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable currentSectionId __attribute__((swift_name("currentSectionId")));
@property (readonly) NSArray<SharedHardSectionsResolverSectionEntry *> *entries __attribute__((swift_name("entries")));
@property (readonly) NSString *subjectId __attribute__((swift_name("subjectId")));
@property (readonly) NSString * _Nullable title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HardSectionsResolver.SectionEntry")))
@interface SharedHardSectionsResolverSectionEntry : SharedBase
- (instancetype)initWithId:(NSString *)id title:(NSString *)title totalItemsCount:(int32_t)totalItemsCount __attribute__((swift_name("init(id:title:totalItemsCount:)"))) __attribute__((objc_designated_initializer));
- (SharedHardSectionsResolverSectionEntry *)doCopyId:(NSString *)id title:(NSString *)title totalItemsCount:(int32_t)totalItemsCount __attribute__((swift_name("doCopy(id:title:totalItemsCount:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@property (readonly) int32_t totalItemsCount __attribute__((swift_name("totalItemsCount")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SharedExerciseExplanationResolver")))
@interface SharedSharedExerciseExplanationResolver : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)sharedExerciseExplanationResolver __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedSharedExerciseExplanationResolver *shared __attribute__((swift_name("shared")));
- (NSString *)getBelt:(SharedBelt *)belt topic:(NSString *)topic item:(NSString *)item isEnglish:(BOOL)isEnglish __attribute__((swift_name("get(belt:topic:item:isEnglish:)")));
- (NSString *)resolveIdBelt:(SharedBelt *)belt topic:(NSString *)topic item:(NSString *)item __attribute__((swift_name("resolveId(belt:topic:item:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubjectItemsResolver")))
@interface SharedSubjectItemsResolver : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)subjectItemsResolver __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedSubjectItemsResolver *shared __attribute__((swift_name("shared")));
- (NSArray<SharedSubjectItemsResolverUiSection *> *)resolveBySubjectBelt:(SharedBelt *)belt subject:(SharedSubjectTopic *)subject __attribute__((swift_name("resolveBySubject(belt:subject:)")));
- (NSArray<SharedSubjectItemsResolverUiSection *> *)resolveByTopicBelt:(SharedBelt *)belt topicTitle:(NSString *)topicTitle subTopicTitle:(NSString * _Nullable)subTopicTitle __attribute__((swift_name("resolveByTopic(belt:topicTitle:subTopicTitle:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubjectItemsResolver.UiItem")))
@interface SharedSubjectItemsResolverUiItem : SharedBase
- (instancetype)initWithDisplayName:(NSString *)displayName canonicalId:(NSString *)canonicalId itemKey:(NSString *)itemKey rawItem:(NSString *)rawItem topicTitle:(NSString *)topicTitle subTopicTitle:(NSString * _Nullable)subTopicTitle __attribute__((swift_name("init(displayName:canonicalId:itemKey:rawItem:topicTitle:subTopicTitle:)"))) __attribute__((objc_designated_initializer));
- (SharedSubjectItemsResolverUiItem *)doCopyDisplayName:(NSString *)displayName canonicalId:(NSString *)canonicalId itemKey:(NSString *)itemKey rawItem:(NSString *)rawItem topicTitle:(NSString *)topicTitle subTopicTitle:(NSString * _Nullable)subTopicTitle __attribute__((swift_name("doCopy(displayName:canonicalId:itemKey:rawItem:topicTitle:subTopicTitle:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *canonicalId __attribute__((swift_name("canonicalId")));
@property (readonly) NSString *displayName __attribute__((swift_name("displayName")));
@property (readonly) NSString *itemKey __attribute__((swift_name("itemKey")));
@property (readonly) NSString *rawItem __attribute__((swift_name("rawItem")));
@property (readonly) NSString * _Nullable subTopicTitle __attribute__((swift_name("subTopicTitle")));
@property (readonly) NSString *topicTitle __attribute__((swift_name("topicTitle")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubjectItemsResolver.UiSection")))
@interface SharedSubjectItemsResolverUiSection : SharedBase
- (instancetype)initWithTitle:(NSString *)title items:(NSArray<SharedSubjectItemsResolverUiItem *> *)items __attribute__((swift_name("init(title:items:)"))) __attribute__((objc_designated_initializer));
- (SharedSubjectItemsResolverUiSection *)doCopyTitle:(NSString *)title items:(NSArray<SharedSubjectItemsResolverUiItem *> *)items __attribute__((swift_name("doCopy(title:items:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<SharedSubjectItemsResolverUiItem *> *items __attribute__((swift_name("items")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AttackType")))
@interface SharedAttackType : SharedKotlinEnum<SharedAttackType *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) SharedAttackType *punch __attribute__((swift_name("punch")));
@property (class, readonly) SharedAttackType *kick __attribute__((swift_name("kick")));
@property (class, readonly) SharedAttackType *any __attribute__((swift_name("any")));
+ (SharedKotlinArray<SharedAttackType *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<SharedAttackType *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("DefenseKind")))
@interface SharedDefenseKind : SharedKotlinEnum<SharedDefenseKind *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) SharedDefenseKind *internal __attribute__((swift_name("internal")));
@property (class, readonly) SharedDefenseKind *external __attribute__((swift_name("external")));
@property (class, readonly) SharedDefenseKind *none __attribute__((swift_name("none")));
+ (SharedKotlinArray<SharedDefenseKind *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<SharedDefenseKind *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExamFacade")))
@interface SharedExamFacade : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)examFacade __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedExamFacade *shared __attribute__((swift_name("shared")));
- (NSArray<NSString *> *)buildExamItemsBeltId:(NSString *)beltId topicTitlesProvider:(id<SharedExamFacadeTopicTitlesProvider>)topicTitlesProvider itemsProvider:(id<SharedExamFacadeItemsProvider>)itemsProvider __attribute__((swift_name("buildExamItems(beltId:topicTitlesProvider:itemsProvider:)")));
@end

__attribute__((swift_name("ExamFacadeItemsProvider")))
@protocol SharedExamFacadeItemsProvider
@required
- (NSArray<NSString *> *)itemsForBeltId:(NSString *)beltId topicTitle:(NSString *)topicTitle __attribute__((swift_name("itemsFor(beltId:topicTitle:)")));
@end

__attribute__((swift_name("ExamFacadeTopicTitlesProvider")))
@protocol SharedExamFacadeTopicTitlesProvider
@required
- (NSArray<NSString *> *)topicTitlesForBeltId:(NSString *)beltId __attribute__((swift_name("topicTitlesFor(beltId:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ForumMessage")))
@interface SharedForumMessage : SharedBase
- (instancetype)initWithId:(NSString *)id branch:(NSString *)branch authorName:(NSString *)authorName authorEmail:(NSString *)authorEmail text:(NSString *)text createdAt:(SharedKotlinx_datetimeInstant *)createdAt __attribute__((swift_name("init(id:branch:authorName:authorEmail:text:createdAt:)"))) __attribute__((objc_designated_initializer));
- (SharedForumMessage *)doCopyId:(NSString *)id branch:(NSString *)branch authorName:(NSString *)authorName authorEmail:(NSString *)authorEmail text:(NSString *)text createdAt:(SharedKotlinx_datetimeInstant *)createdAt __attribute__((swift_name("doCopy(id:branch:authorName:authorEmail:text:createdAt:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *authorEmail __attribute__((swift_name("authorEmail")));
@property (readonly) NSString *authorName __attribute__((swift_name("authorName")));
@property (readonly) NSString *branch __attribute__((swift_name("branch")));
@property (readonly) SharedKotlinx_datetimeInstant *createdAt __attribute__((swift_name("createdAt")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSString *text __attribute__((swift_name("text")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("FreeSessionsPaths")))
@interface SharedFreeSessionsPaths : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)freeSessionsPaths __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedFreeSessionsPaths *shared __attribute__((swift_name("shared")));
- (NSString *)freeSessionsColBranch:(NSString *)branch groupKey:(NSString *)groupKey __attribute__((swift_name("freeSessionsCol(branch:groupKey:)")));
@property (readonly) NSString *COL_FREE_SESSIONS __attribute__((swift_name("COL_FREE_SESSIONS")));
@property (readonly) NSString *COL_PARTICIPANTS __attribute__((swift_name("COL_PARTICIPANTS")));
@property (readonly) NSString *ROOT_BRANCHES __attribute__((swift_name("ROOT_BRANCHES")));
@property (readonly) NSString *ROOT_GROUPS __attribute__((swift_name("ROOT_GROUPS")));
@end

__attribute__((swift_name("FreeSessionsRepository")))
@protocol SharedFreeSessionsRepository
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)closeSessionBranch:(NSString *)branch groupKey:(NSString *)groupKey sessionId:(NSString *)sessionId completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("closeSession(branch:groupKey:sessionId:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)createFreeSessionBranch:(NSString *)branch groupKey:(NSString *)groupKey title:(NSString *)title locationName:(NSString * _Nullable)locationName lat:(SharedDouble * _Nullable)lat lng:(SharedDouble * _Nullable)lng startsAt:(int64_t)startsAt createdByUid:(NSString *)createdByUid createdByName:(NSString *)createdByName completionHandler:(void (^)(NSString * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("createFreeSession(branch:groupKey:title:locationName:lat:lng:startsAt:createdByUid:createdByName:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)deleteFreeSessionBranch:(NSString *)branch groupKey:(NSString *)groupKey sessionId:(NSString *)sessionId completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("deleteFreeSession(branch:groupKey:sessionId:completionHandler:)")));
- (id<SharedKotlinx_coroutines_coreFlow>)observeParticipantsBranch:(NSString *)branch groupKey:(NSString *)groupKey sessionId:(NSString *)sessionId __attribute__((swift_name("observeParticipants(branch:groupKey:sessionId:)")));
- (id<SharedKotlinx_coroutines_coreFlow>)observeUpcomingBranch:(NSString *)branch groupKey:(NSString *)groupKey nowMillis:(int64_t)nowMillis __attribute__((swift_name("observeUpcoming(branch:groupKey:nowMillis:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)setParticipantStateBranch:(NSString *)branch groupKey:(NSString *)groupKey sessionId:(NSString *)sessionId uid:(NSString *)uid name:(NSString *)name state:(SharedParticipantState *)state completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("setParticipantState(branch:groupKey:sessionId:uid:name:state:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("FreeSession")))
@interface SharedFreeSession : SharedBase
- (instancetype)initWithId:(NSString *)id branch:(NSString *)branch groupKey:(NSString *)groupKey title:(NSString *)title locationName:(NSString * _Nullable)locationName lat:(SharedDouble * _Nullable)lat lng:(SharedDouble * _Nullable)lng startsAt:(int64_t)startsAt createdAt:(int64_t)createdAt createdByUid:(NSString *)createdByUid createdByName:(NSString *)createdByName status:(NSString *)status goingCount:(int32_t)goingCount onWayCount:(int32_t)onWayCount arrivedCount:(int32_t)arrivedCount cantCount:(int32_t)cantCount __attribute__((swift_name("init(id:branch:groupKey:title:locationName:lat:lng:startsAt:createdAt:createdByUid:createdByName:status:goingCount:onWayCount:arrivedCount:cantCount:)"))) __attribute__((objc_designated_initializer));
- (SharedFreeSession *)doCopyId:(NSString *)id branch:(NSString *)branch groupKey:(NSString *)groupKey title:(NSString *)title locationName:(NSString * _Nullable)locationName lat:(SharedDouble * _Nullable)lat lng:(SharedDouble * _Nullable)lng startsAt:(int64_t)startsAt createdAt:(int64_t)createdAt createdByUid:(NSString *)createdByUid createdByName:(NSString *)createdByName status:(NSString *)status goingCount:(int32_t)goingCount onWayCount:(int32_t)onWayCount arrivedCount:(int32_t)arrivedCount cantCount:(int32_t)cantCount __attribute__((swift_name("doCopy(id:branch:groupKey:title:locationName:lat:lng:startsAt:createdAt:createdByUid:createdByName:status:goingCount:onWayCount:arrivedCount:cantCount:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int32_t arrivedCount __attribute__((swift_name("arrivedCount")));
@property (readonly) NSString *branch __attribute__((swift_name("branch")));
@property (readonly) int32_t cantCount __attribute__((swift_name("cantCount")));
@property (readonly) int64_t createdAt __attribute__((swift_name("createdAt")));
@property (readonly) NSString *createdByName __attribute__((swift_name("createdByName")));
@property (readonly) NSString *createdByUid __attribute__((swift_name("createdByUid")));
@property (readonly) int32_t goingCount __attribute__((swift_name("goingCount")));
@property (readonly) NSString *groupKey __attribute__((swift_name("groupKey")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) SharedDouble * _Nullable lat __attribute__((swift_name("lat")));
@property (readonly) SharedDouble * _Nullable lng __attribute__((swift_name("lng")));
@property (readonly) NSString * _Nullable locationName __attribute__((swift_name("locationName")));
@property (readonly) int32_t onWayCount __attribute__((swift_name("onWayCount")));
@property (readonly) int64_t startsAt __attribute__((swift_name("startsAt")));
@property (readonly) NSString *status __attribute__((swift_name("status")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("FreeSessionPart")))
@interface SharedFreeSessionPart : SharedBase
- (instancetype)initWithUid:(NSString *)uid name:(NSString *)name state:(SharedParticipantState *)state updatedAt:(int64_t)updatedAt __attribute__((swift_name("init(uid:name:state:updatedAt:)"))) __attribute__((objc_designated_initializer));
- (SharedFreeSessionPart *)doCopyUid:(NSString *)uid name:(NSString *)name state:(SharedParticipantState *)state updatedAt:(int64_t)updatedAt __attribute__((swift_name("doCopy(uid:name:state:updatedAt:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@property (readonly) SharedParticipantState *state __attribute__((swift_name("state")));
@property (readonly) NSString *uid __attribute__((swift_name("uid")));
@property (readonly) int64_t updatedAt __attribute__((swift_name("updatedAt")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ParticipantState")))
@interface SharedParticipantState : SharedKotlinEnum<SharedParticipantState *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) SharedParticipantStateCompanion *companion __attribute__((swift_name("companion")));
@property (class, readonly) SharedParticipantState *invited __attribute__((swift_name("invited")));
@property (class, readonly) SharedParticipantState *going __attribute__((swift_name("going")));
@property (class, readonly) SharedParticipantState *onWay __attribute__((swift_name("onWay")));
@property (class, readonly) SharedParticipantState *arrived __attribute__((swift_name("arrived")));
@property (class, readonly) SharedParticipantState *cant __attribute__((swift_name("cant")));
+ (SharedKotlinArray<SharedParticipantState *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<SharedParticipantState *> *entries __attribute__((swift_name("entries")));
@property (readonly) int32_t order __attribute__((swift_name("order")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ParticipantState.Companion")))
@interface SharedParticipantStateCompanion : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedParticipantStateCompanion *shared __attribute__((swift_name("shared")));
- (SharedParticipantState *)fromIdRaw:(NSString * _Nullable)raw __attribute__((swift_name("fromId(raw:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AppLanguage")))
@interface SharedAppLanguage : SharedKotlinEnum<SharedAppLanguage *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) SharedAppLanguageCompanion *companion __attribute__((swift_name("companion")));
@property (class, readonly) SharedAppLanguage *hebrew __attribute__((swift_name("hebrew")));
@property (class, readonly) SharedAppLanguage *english __attribute__((swift_name("english")));
+ (SharedKotlinArray<SharedAppLanguage *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<SharedAppLanguage *> *entries __attribute__((swift_name("entries")));
@property (readonly) NSString *code __attribute__((swift_name("code")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("AppLanguage.Companion")))
@interface SharedAppLanguageCompanion : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedAppLanguageCompanion *shared __attribute__((swift_name("shared")));
- (SharedAppLanguage *)fromCodeCode:(NSString * _Nullable)code __attribute__((swift_name("fromCode(code:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("LanguageKeys")))
@interface SharedLanguageKeys : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)languageKeys __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedLanguageKeys *shared __attribute__((swift_name("shared")));
@property (readonly) NSString *CANCEL __attribute__((swift_name("CANCEL")));
@property (readonly) NSString *ENGLISH __attribute__((swift_name("ENGLISH")));
@property (readonly) NSString *HEBREW __attribute__((swift_name("HEBREW")));
@property (readonly) NSString *HOME __attribute__((swift_name("HOME")));
@property (readonly) NSString *LANGUAGE __attribute__((swift_name("LANGUAGE")));
@property (readonly) NSString *LOGIN __attribute__((swift_name("LOGIN")));
@property (readonly) NSString *LOGOUT __attribute__((swift_name("LOGOUT")));
@property (readonly) NSString *SAVE __attribute__((swift_name("SAVE")));
@property (readonly) NSString *SEARCH __attribute__((swift_name("SEARCH")));
@property (readonly) NSString *SEND_MESSAGE __attribute__((swift_name("SEND_MESSAGE")));
@property (readonly) NSString *SETTINGS __attribute__((swift_name("SETTINGS")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("LanguageRepository")))
@interface SharedLanguageRepository : SharedBase
- (instancetype)initWithLanguageStore:(id<SharedLanguageStore>)languageStore __attribute__((swift_name("init(languageStore:)"))) __attribute__((objc_designated_initializer));
- (SharedAppLanguage *)currentLanguage __attribute__((swift_name("currentLanguage()")));
- (void)setLanguageLanguage:(SharedAppLanguage *)language __attribute__((swift_name("setLanguage(language:)")));
- (NSString *)textKey:(NSString *)key __attribute__((swift_name("text(key:)")));
@end

__attribute__((swift_name("LanguageStore")))
@protocol SharedLanguageStore
@required
- (SharedAppLanguage *)getLanguage __attribute__((swift_name("getLanguage()")));
- (void)setLanguageLanguage:(SharedAppLanguage *)language __attribute__((swift_name("setLanguage(language:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("LanguageStrings")))
@interface SharedLanguageStrings : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)languageStrings __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedLanguageStrings *shared __attribute__((swift_name("shared")));
- (NSString *)getLanguage:(SharedAppLanguage *)language key:(NSString *)key __attribute__((swift_name("get(language:key:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("LocalizationRuntime")))
@interface SharedLocalizationRuntime : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)localizationRuntime __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedLocalizationRuntime *shared __attribute__((swift_name("shared")));
@property SharedAppLanguage *currentLanguage __attribute__((swift_name("currentLanguage")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KmiBelt")))
@interface SharedKmiBelt : SharedKotlinEnum<SharedKmiBelt *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) SharedKmiBelt *white __attribute__((swift_name("white")));
@property (class, readonly) SharedKmiBelt *yellow __attribute__((swift_name("yellow")));
@property (class, readonly) SharedKmiBelt *orange __attribute__((swift_name("orange")));
@property (class, readonly) SharedKmiBelt *green __attribute__((swift_name("green")));
@property (class, readonly) SharedKmiBelt *blue __attribute__((swift_name("blue")));
@property (class, readonly) SharedKmiBelt *brown __attribute__((swift_name("brown")));
@property (class, readonly) SharedKmiBelt *black __attribute__((swift_name("black")));
+ (SharedKotlinArray<SharedKmiBelt *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<SharedKmiBelt *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KmiBeltContent")))
@interface SharedKmiBeltContent : SharedBase
- (instancetype)initWithTopics:(NSArray<SharedKmiTopic *> *)topics __attribute__((swift_name("init(topics:)"))) __attribute__((objc_designated_initializer));
- (SharedKmiBeltContent *)doCopyTopics:(NSArray<SharedKmiTopic *> *)topics __attribute__((swift_name("doCopy(topics:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<SharedKmiTopic *> *topics __attribute__((swift_name("topics")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KmiSubTopic")))
@interface SharedKmiSubTopic : SharedBase
- (instancetype)initWithTitle:(NSString *)title items:(NSArray<NSString *> *)items __attribute__((swift_name("init(title:items:)"))) __attribute__((objc_designated_initializer));
- (SharedKmiSubTopic *)doCopyTitle:(NSString *)title items:(NSArray<NSString *> *)items __attribute__((swift_name("doCopy(title:items:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<NSString *> *items __attribute__((swift_name("items")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KmiTopic")))
@interface SharedKmiTopic : SharedBase
- (instancetype)initWithTitle:(NSString *)title items:(NSArray<NSString *> *)items subTopics:(NSArray<SharedKmiSubTopic *> *)subTopics __attribute__((swift_name("init(title:items:subTopics:)"))) __attribute__((objc_designated_initializer));
- (SharedKmiTopic *)doCopyTitle:(NSString *)title items:(NSArray<NSString *> *)items subTopics:(NSArray<SharedKmiSubTopic *> *)subTopics __attribute__((swift_name("doCopy(title:items:subTopics:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSArray<NSString *> *items __attribute__((swift_name("items")));
@property (readonly) NSArray<SharedKmiSubTopic *> *subTopics __attribute__((swift_name("subTopics")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PlatformSoundPlayer")))
@interface SharedPlatformSoundPlayer : SharedBase
- (instancetype)initWithPlatformContext:(id _Nullable)platformContext __attribute__((swift_name("init(platformContext:)"))) __attribute__((objc_designated_initializer));
- (void)playName:(NSString *)name __attribute__((swift_name("play(name:)")));
- (void)release_ __attribute__((swift_name("release()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PracticeFacade")))
@interface SharedPracticeFacade : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)practiceFacade __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedPracticeFacade *shared __attribute__((swift_name("shared")));
- (NSArray<SharedPracticeItem *> *)buildPracticeItemsRequest:(SharedPracticeRequest *)request topicTitlesProvider:(id<SharedPracticeFacadeTopicTitlesProvider>)topicTitlesProvider itemsProvider:(id<SharedPracticeFacadeItemsProvider>)itemsProvider setsProvider:(id<SharedPracticeFacadeSetProvider>)setsProvider excludedProvider:(id<SharedPracticeFacadeExcludedProvider>)excludedProvider canonicalKeyFor:(NSString *(^)(NSString *))canonicalKeyFor displayNameFor:(NSString *(^)(NSString *))displayNameFor __attribute__((swift_name("buildPracticeItems(request:topicTitlesProvider:itemsProvider:setsProvider:excludedProvider:canonicalKeyFor:displayNameFor:)")));
- (NSArray<SharedPracticeItem *> *)buildWeightedOrderItems:(NSArray<SharedPracticeItem *> *)items wrongCanonicalKeys:(NSSet<NSString *> *)wrongCanonicalKeys wrongWeight:(int32_t)wrongWeight seed:(SharedInt * _Nullable)seed __attribute__((swift_name("buildWeightedOrder(items:wrongCanonicalKeys:wrongWeight:seed:)")));
@end

__attribute__((swift_name("PracticeFacadeExcludedProvider")))
@protocol SharedPracticeFacadeExcludedProvider
@required
- (BOOL)isExcludedBeltId:(NSString *)beltId topicTitle:(NSString *)topicTitle rawItem:(NSString *)rawItem display:(NSString *)display __attribute__((swift_name("isExcluded(beltId:topicTitle:rawItem:display:)")));
@end

__attribute__((swift_name("PracticeFacadeItemsProvider")))
@protocol SharedPracticeFacadeItemsProvider
@required
- (NSArray<NSString *> *)itemsForBeltId:(NSString *)beltId topicTitle:(NSString *)topicTitle __attribute__((swift_name("itemsFor(beltId:topicTitle:)")));
@end

__attribute__((swift_name("PracticeFacadeSetProvider")))
@protocol SharedPracticeFacadeSetProvider
@required
- (NSSet<NSString *> *)getSetKey:(NSString *)key __attribute__((swift_name("getSet(key:)")));
@end

__attribute__((swift_name("PracticeFacadeTopicTitlesProvider")))
@protocol SharedPracticeFacadeTopicTitlesProvider
@required
- (NSArray<NSString *> *)topicTitlesForBeltId:(NSString *)beltId __attribute__((swift_name("topicTitlesFor(beltId:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PracticeFilters")))
@interface SharedPracticeFilters : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)practiceFilters __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedPracticeFilters *shared __attribute__((swift_name("shared")));
@property (readonly) NSString *ALL __attribute__((swift_name("ALL")));
@property (readonly) NSString *FAVS_ALL __attribute__((swift_name("FAVS_ALL")));
@property (readonly) NSString *TOPICS_PICK_TOKEN __attribute__((swift_name("TOPICS_PICK_TOKEN")));
@property (readonly) NSString *UNKNOWN __attribute__((swift_name("UNKNOWN")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PracticeItem")))
@interface SharedPracticeItem : SharedBase
- (instancetype)initWithBeltId:(NSString *)beltId topicTitle:(NSString *)topicTitle rawTitle:(NSString *)rawTitle displayTitle:(NSString *)displayTitle canonicalKey:(NSString *)canonicalKey __attribute__((swift_name("init(beltId:topicTitle:rawTitle:displayTitle:canonicalKey:)"))) __attribute__((objc_designated_initializer));
- (SharedPracticeItem *)doCopyBeltId:(NSString *)beltId topicTitle:(NSString *)topicTitle rawTitle:(NSString *)rawTitle displayTitle:(NSString *)displayTitle canonicalKey:(NSString *)canonicalKey __attribute__((swift_name("doCopy(beltId:topicTitle:rawTitle:displayTitle:canonicalKey:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *beltId __attribute__((swift_name("beltId")));
@property (readonly) NSString *canonicalKey __attribute__((swift_name("canonicalKey")));
@property (readonly) NSString *displayTitle __attribute__((swift_name("displayTitle")));
@property (readonly) NSString *rawTitle __attribute__((swift_name("rawTitle")));
@property (readonly) NSString *topicTitle __attribute__((swift_name("topicTitle")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PracticeRequest")))
@interface SharedPracticeRequest : SharedBase
- (instancetype)initWithBeltId:(NSString *)beltId topicFilter:(NSString * _Nullable)topicFilter __attribute__((swift_name("init(beltId:topicFilter:)"))) __attribute__((objc_designated_initializer));
- (SharedPracticeRequest *)doCopyBeltId:(NSString *)beltId topicFilter:(NSString * _Nullable)topicFilter __attribute__((swift_name("doCopy(beltId:topicFilter:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *beltId __attribute__((swift_name("beltId")));
@property (readonly) NSString * _Nullable topicFilter __attribute__((swift_name("topicFilter")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KmiPrefs")))
@interface SharedKmiPrefs : SharedBase
- (instancetype)initWithSettings:(id<SharedMultiplatform_settingsSettings>)settings __attribute__((swift_name("init(settings:)"))) __attribute__((objc_designated_initializer));
- (void)clearAll __attribute__((swift_name("clearAll()")));
- (int32_t)incrementOpenCount __attribute__((swift_name("incrementOpenCount()")));
@property NSString * _Nullable ageGroup __attribute__((swift_name("ageGroup")));
@property NSString * _Nullable branch __attribute__((swift_name("branch")));
@property NSString * _Nullable branchId __attribute__((swift_name("branchId")));
@property BOOL clickSounds __attribute__((swift_name("clickSounds")));
@property NSString * _Nullable email __attribute__((swift_name("email")));
@property float fontScale __attribute__((swift_name("fontScale")));
@property NSString *fontScaleString __attribute__((swift_name("fontScaleString")));
@property NSString *fontSize __attribute__((swift_name("fontSize")));
@property NSString * _Nullable fullName __attribute__((swift_name("fullName")));
@property BOOL hapticsOn __attribute__((swift_name("hapticsOn")));
@property int32_t leadMinutes __attribute__((swift_name("leadMinutes")));
@property int32_t openCount __attribute__((swift_name("openCount")));
@property NSString * _Nullable password __attribute__((swift_name("password")));
@property NSString * _Nullable phone __attribute__((swift_name("phone")));
@property NSString * _Nullable region __attribute__((swift_name("region")));
@property BOOL remindersOn __attribute__((swift_name("remindersOn")));
@property BOOL syncCalendar __attribute__((swift_name("syncCalendar")));
@property NSString *themeMode __attribute__((swift_name("themeMode")));
@property NSString * _Nullable username __attribute__((swift_name("username")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KmiPrefsFacade")))
@interface SharedKmiPrefsFacade : SharedBase
@property (class, readonly, getter=companion) SharedKmiPrefsFacadeCompanion *companion __attribute__((swift_name("companion")));
- (NSString *)ageGroup __attribute__((swift_name("ageGroup()")));
- (NSString *)branch __attribute__((swift_name("branch()")));
- (NSString *)branchId __attribute__((swift_name("branchId()")));
- (NSString *)email __attribute__((swift_name("email()")));
- (NSString *)fontScale __attribute__((swift_name("fontScale()")));
- (NSString *)fontSize __attribute__((swift_name("fontSize()")));
- (NSString *)fullName __attribute__((swift_name("fullName()")));
- (int32_t)leadMinutes __attribute__((swift_name("leadMinutes()")));
- (NSString *)password __attribute__((swift_name("password()")));
- (NSString *)phone __attribute__((swift_name("phone()")));
- (NSString *)region __attribute__((swift_name("region()")));
- (BOOL)remindersOn __attribute__((swift_name("remindersOn()")));
- (BOOL)syncCalendar __attribute__((swift_name("syncCalendar()")));
- (NSString *)themeMode __attribute__((swift_name("themeMode()")));
- (NSString *)username __attribute__((swift_name("username()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KmiPrefsFacade.Companion")))
@interface SharedKmiPrefsFacadeCompanion : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedKmiPrefsFacadeCompanion *shared __attribute__((swift_name("shared")));
- (SharedKmiPrefsFacade *)sharedContext:(id)context __attribute__((swift_name("shared(context:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KmiPrefsFactory")))
@interface SharedKmiPrefsFactory : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)kmiPrefsFactory __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedKmiPrefsFactory *shared __attribute__((swift_name("shared")));
- (SharedKmiPrefs *)createContext:(id)context __attribute__((swift_name("create(context:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SharedSettings")))
@interface SharedSharedSettings : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)sharedSettings __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedSharedSettings *shared __attribute__((swift_name("shared")));
- (id<SharedMultiplatform_settingsSettings>)createName:(NSString *)name __attribute__((swift_name("create(name:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SharedSettingsFactoryProvider")))
@interface SharedSharedSettingsFactoryProvider : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)sharedSettingsFactoryProvider __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedSharedSettingsFactoryProvider *shared __attribute__((swift_name("shared")));
- (id<SharedMultiplatform_settingsSettingsFactory>)createFactory __attribute__((swift_name("createFactory()")));
@end

__attribute__((swift_name("UserPrefsRepository")))
@protocol SharedUserPrefsRepository
@required
- (double)getFontScale __attribute__((swift_name("getFontScale()")));
- (NSString *)getFontSize __attribute__((swift_name("getFontSize()")));
- (NSString *)getThemeMode __attribute__((swift_name("getThemeMode()")));
- (void)setFontScaleValue:(double)value __attribute__((swift_name("setFontScale(value:)")));
- (void)setFontSizeValue:(NSString *)value __attribute__((swift_name("setFontSize(value:)")));
- (void)setThemeModeValue:(NSString *)value __attribute__((swift_name("setThemeMode(value:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("UserPrefsRepositoryIos")))
@interface SharedUserPrefsRepositoryIos : SharedBase <SharedUserPrefsRepository>
- (instancetype)initWithSuiteName:(NSString * _Nullable)suiteName __attribute__((swift_name("init(suiteName:)"))) __attribute__((objc_designated_initializer));
- (double)getFontScale __attribute__((swift_name("getFontScale()")));
- (NSString *)getFontSize __attribute__((swift_name("getFontSize()")));
- (NSString *)getThemeMode __attribute__((swift_name("getThemeMode()")));
- (void)setFontScaleValue:(double)value __attribute__((swift_name("setFontScale(value:)")));
- (void)setFontSizeValue:(NSString *)value __attribute__((swift_name("setFontSize(value:)")));
- (void)setThemeModeValue:(NSString *)value __attribute__((swift_name("setThemeMode(value:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ProgressFacade")))
@interface SharedProgressFacade : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)progressFacade __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedProgressFacade *shared __attribute__((swift_name("shared")));
- (NSArray<SharedProgressFacadeBeltProgressRow *> *)computeBeltsProgressBeltsToScan:(NSArray<SharedBeltDto *> *)beltsToScan excludedProvider:(id<SharedProgressFacadeExcludedProvider>)excludedProvider statusProvider:(id<SharedProgressFacadeStatusProvider>)statusProvider canonicalKeyFor:(NSString *(^)(NSString *))canonicalKeyFor displayNameFor:(NSString *(^)(NSString *))displayNameFor __attribute__((swift_name("computeBeltsProgress(beltsToScan:excludedProvider:statusProvider:canonicalKeyFor:displayNameFor:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ProgressFacade.BeltProgressRow")))
@interface SharedProgressFacadeBeltProgressRow : SharedBase
- (instancetype)initWithBeltId:(NSString *)beltId beltTitle:(NSString *)beltTitle done:(int32_t)done total:(int32_t)total percent:(int32_t)percent __attribute__((swift_name("init(beltId:beltTitle:done:total:percent:)"))) __attribute__((objc_designated_initializer));
- (SharedProgressFacadeBeltProgressRow *)doCopyBeltId:(NSString *)beltId beltTitle:(NSString *)beltTitle done:(int32_t)done total:(int32_t)total percent:(int32_t)percent __attribute__((swift_name("doCopy(beltId:beltTitle:done:total:percent:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *beltId __attribute__((swift_name("beltId")));
@property (readonly) NSString *beltTitle __attribute__((swift_name("beltTitle")));
@property (readonly) int32_t done __attribute__((swift_name("done")));
@property (readonly) int32_t percent __attribute__((swift_name("percent")));
@property (readonly) int32_t total __attribute__((swift_name("total")));
@end

__attribute__((swift_name("ProgressFacadeExcludedProvider")))
@protocol SharedProgressFacadeExcludedProvider
@required
- (BOOL)isExcludedBeltId:(NSString *)beltId topicTitle:(NSString *)topicTitle rawItem:(NSString *)rawItem displayName:(NSString *)displayName __attribute__((swift_name("isExcluded(beltId:topicTitle:rawItem:displayName:)")));
@end

__attribute__((swift_name("ProgressFacadeStatusProvider")))
@protocol SharedProgressFacadeStatusProvider
@required
- (SharedBoolean * _Nullable)getStatusBeltId:(NSString *)beltId topicTitle:(NSString *)topicTitle canonicalItemKey:(NSString *)canonicalItemKey __attribute__((swift_name("getStatus(beltId:topicTitle:canonicalItemKey:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ProgressStore")))
@interface SharedProgressStore : SharedBase
- (instancetype)initWithSettings:(id<SharedMultiplatform_settingsSettings>)settings keyPrefix:(NSString *)keyPrefix __attribute__((swift_name("init(settings:keyPrefix:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) SharedProgressStoreCompanion *companion __attribute__((swift_name("companion")));
- (int32_t)percentBeltKey:(NSString *)beltKey total:(int32_t)total __attribute__((swift_name("percent(beltKey:total:)")));
- (NSDictionary<NSString *, SharedInt *> *)snapshotTotals:(NSDictionary<NSString *, SharedInt *> *)totals __attribute__((swift_name("snapshot(totals:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ProgressStore.Companion")))
@interface SharedProgressStoreCompanion : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedProgressStoreCompanion *shared __attribute__((swift_name("shared")));
- (SharedProgressStore *)fromContextName:(NSString *)name context:(id)context keyPrefix:(NSString *)keyPrefix __attribute__((swift_name("fromContext(name:context:keyPrefix:)")));
@end

__attribute__((swift_name("QuestionsContentSource")))
@protocol SharedQuestionsContentSource
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)listBeltsWithCompletionHandler:(void (^)(NSArray<SharedBeltRef *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("listBelts(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)listItemsBeltId:(NSString *)beltId topicTitle:(NSString *)topicTitle subTopicTitle:(NSString * _Nullable)subTopicTitle completionHandler:(void (^)(NSArray<SharedQuestionItem *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("listItems(beltId:topicTitle:subTopicTitle:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)listTopicsForBeltBeltId:(NSString *)beltId completionHandler:(void (^)(NSArray<SharedTopicBucket *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("listTopicsForBelt(beltId:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("IosQuestionsSource")))
@interface SharedIosQuestionsSource : SharedBase <SharedQuestionsContentSource>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)listBeltsWithCompletionHandler:(void (^)(NSArray<SharedBeltRef *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("listBelts(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)listItemsBeltId:(NSString *)beltId topicTitle:(NSString *)topicTitle subTopicTitle:(NSString * _Nullable)subTopicTitle completionHandler:(void (^)(NSArray<SharedQuestionItem *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("listItems(beltId:topicTitle:subTopicTitle:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)listTopicsForBeltBeltId:(NSString *)beltId completionHandler:(void (^)(NSArray<SharedTopicBucket *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("listTopicsForBelt(beltId:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("BeltRef")))
@interface SharedBeltRef : SharedBase
- (instancetype)initWithId:(NSString *)id heb:(NSString *)heb __attribute__((swift_name("init(id:heb:)"))) __attribute__((objc_designated_initializer));
- (SharedBeltRef *)doCopyId:(NSString *)id heb:(NSString *)heb __attribute__((swift_name("doCopy(id:heb:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *heb __attribute__((swift_name("heb")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("QuestionItem")))
@interface SharedQuestionItem : SharedBase
- (instancetype)initWithId:(NSString *)id title:(NSString *)title subtitle:(NSString * _Nullable)subtitle body:(NSString * _Nullable)body __attribute__((swift_name("init(id:title:subtitle:body:)"))) __attribute__((objc_designated_initializer));
- (SharedQuestionItem *)doCopyId:(NSString *)id title:(NSString *)title subtitle:(NSString * _Nullable)subtitle body:(NSString * _Nullable)body __attribute__((swift_name("doCopy(id:title:subtitle:body:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable body __attribute__((swift_name("body")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSString * _Nullable subtitle __attribute__((swift_name("subtitle")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubTopicBucket")))
@interface SharedSubTopicBucket : SharedBase
- (instancetype)initWithSubTopic:(SharedSubTopicRef *)subTopic count:(int32_t)count __attribute__((swift_name("init(subTopic:count:)"))) __attribute__((objc_designated_initializer));
- (SharedSubTopicBucket *)doCopySubTopic:(SharedSubTopicRef *)subTopic count:(int32_t)count __attribute__((swift_name("doCopy(subTopic:count:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int32_t count __attribute__((swift_name("count")));
@property (readonly) SharedSubTopicRef *subTopic __attribute__((swift_name("subTopic")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SubTopicRef")))
@interface SharedSubTopicRef : SharedBase
- (instancetype)initWithTitle:(NSString *)title __attribute__((swift_name("init(title:)"))) __attribute__((objc_designated_initializer));
- (SharedSubTopicRef *)doCopyTitle:(NSString *)title __attribute__((swift_name("doCopy(title:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TopicBucket")))
@interface SharedTopicBucket : SharedBase
- (instancetype)initWithTopic:(SharedTopicRef *)topic count:(int32_t)count subTopics:(NSArray<SharedSubTopicBucket *> *)subTopics __attribute__((swift_name("init(topic:count:subTopics:)"))) __attribute__((objc_designated_initializer));
- (SharedTopicBucket *)doCopyTopic:(SharedTopicRef *)topic count:(int32_t)count subTopics:(NSArray<SharedSubTopicBucket *> *)subTopics __attribute__((swift_name("doCopy(topic:count:subTopics:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int32_t count __attribute__((swift_name("count")));
@property (readonly) NSArray<SharedSubTopicBucket *> *subTopics __attribute__((swift_name("subTopics")));
@property (readonly) SharedTopicRef *topic __attribute__((swift_name("topic")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TopicRef")))
@interface SharedTopicRef : SharedBase
- (instancetype)initWithTitle:(NSString *)title __attribute__((swift_name("init(title:)"))) __attribute__((objc_designated_initializer));
- (SharedTopicRef *)doCopyTitle:(NSString *)title __attribute__((swift_name("doCopy(title:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SharedRegistryQuestionsSource")))
@interface SharedSharedRegistryQuestionsSource : SharedBase <SharedQuestionsContentSource>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)sharedRegistryQuestionsSource __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedSharedRegistryQuestionsSource *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)listBeltsWithCompletionHandler:(void (^)(NSArray<SharedBeltRef *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("listBelts(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)listItemsBeltId:(NSString *)beltId topicTitle:(NSString *)topicTitle subTopicTitle:(NSString * _Nullable)subTopicTitle completionHandler:(void (^)(NSArray<SharedQuestionItem *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("listItems(beltId:topicTitle:subTopicTitle:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)listTopicsForBeltBeltId:(NSString *)beltId completionHandler:(void (^)(NSArray<SharedTopicBucket *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("listTopicsForBelt(beltId:completionHandler:)")));
- (void)registerBeltId:(NSString *)id heb:(NSString *)heb __attribute__((swift_name("registerBelt(id:heb:)")));
- (void)registerItemBeltId:(NSString *)beltId topicTitle:(NSString *)topicTitle subTopicTitle:(NSString * _Nullable)subTopicTitle item:(SharedQuestionItem *)item __attribute__((swift_name("registerItem(beltId:topicTitle:subTopicTitle:item:)")));
- (void)registerSubTopicBeltId:(NSString *)beltId topicTitle:(NSString *)topicTitle subTopicTitle:(NSString *)subTopicTitle __attribute__((swift_name("registerSubTopic(beltId:topicTitle:subTopicTitle:)")));
- (void)registerTopicBeltId:(NSString *)beltId topicTitle:(NSString *)topicTitle __attribute__((swift_name("registerTopic(beltId:topicTitle:)")));
- (void)reset __attribute__((swift_name("reset()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExerciseTitleFormatter")))
@interface SharedExerciseTitleFormatter : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)exerciseTitleFormatter __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedExerciseTitleFormatter *shared __attribute__((swift_name("shared")));
- (NSString *)displayNameRaw:(NSString *)raw __attribute__((swift_name("displayName(raw:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SearchKeyParser")))
@interface SharedSearchKeyParser : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)searchKeyParser __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedSearchKeyParser *shared __attribute__((swift_name("shared")));
- (BOOL)containsAllTarget:(NSString * _Nullable)target keywords:(NSArray<NSString *> *)keywords __attribute__((swift_name("containsAll(target:keywords:)")));
- (NSString *)normText:(NSString * _Nullable)text __attribute__((swift_name("norm(text:)")));
- (NSArray<NSString *> *)parseKeywordsQuery:(NSString * _Nullable)query minLen:(int32_t)minLen __attribute__((swift_name("parseKeywords(query:minLen:)")));
- (int32_t)scoreTarget:(NSString * _Nullable)target query:(NSString * _Nullable)query __attribute__((swift_name("score(target:query:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("DailyExerciseItem")))
@interface SharedDailyExerciseItem : SharedBase
- (instancetype)initWithBelt:(SharedBelt *)belt topic:(NSString *)topic item:(NSString *)item __attribute__((swift_name("init(belt:topic:item:)"))) __attribute__((objc_designated_initializer));
- (SharedDailyExerciseItem *)doCopyBelt:(SharedBelt *)belt topic:(NSString *)topic item:(NSString *)item __attribute__((swift_name("doCopy(belt:topic:item:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SharedBelt *belt __attribute__((swift_name("belt")));
@property (readonly) NSString *item __attribute__((swift_name("item")));
@property (readonly) NSString *topic __attribute__((swift_name("topic")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("DailyExercisePicker")))
@interface SharedDailyExercisePicker : SharedBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (NSString *)candidateKeyItem:(SharedDailyExerciseItem *)item __attribute__((swift_name("candidateKey(item:)")));
- (SharedDailyExerciseItem * _Nullable)pickNextExerciseForUserRegisteredBelt:(SharedBelt *)registeredBelt lastItemKey:(NSString * _Nullable)lastItemKey __attribute__((swift_name("pickNextExerciseForUser(registeredBelt:lastItemKey:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("BeltProgress")))
@interface SharedBeltProgress : SharedBase
- (instancetype)initWithTitle:(NSString *)title percent:(int32_t)percent colorHex:(NSString *)colorHex lightColorHex:(NSString *)lightColorHex __attribute__((swift_name("init(title:percent:colorHex:lightColorHex:)"))) __attribute__((objc_designated_initializer));
- (SharedBeltProgress *)doCopyTitle:(NSString *)title percent:(int32_t)percent colorHex:(NSString *)colorHex lightColorHex:(NSString *)lightColorHex __attribute__((swift_name("doCopy(title:percent:colorHex:lightColorHex:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *colorHex __attribute__((swift_name("colorHex")));
@property (readonly) NSString *lightColorHex __attribute__((swift_name("lightColorHex")));
@property (readonly) int32_t percent __attribute__((swift_name("percent")));
@property (readonly) NSString *title __attribute__((swift_name("title")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ProgressCalc")))
@interface SharedProgressCalc : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)progressCalc __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedProgressCalc *shared __attribute__((swift_name("shared")));
- (SharedProgressCalcCounts *)countsOfChecks:(NSArray<SharedBoolean *> *)checks __attribute__((swift_name("countsOf(checks:)")));
- (NSArray<SharedBeltProgress *> *)fromCountsYellow:(SharedProgressCalcCounts *)yellow orange:(SharedProgressCalcCounts *)orange green:(SharedProgressCalcCounts *)green blue:(SharedProgressCalcCounts *)blue __attribute__((swift_name("fromCounts(yellow:orange:green:blue:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ProgressCalc.Counts")))
@interface SharedProgressCalcCounts : SharedBase
- (instancetype)initWithDone:(int32_t)done total:(int32_t)total __attribute__((swift_name("init(done:total:)"))) __attribute__((objc_designated_initializer));
- (SharedProgressCalcCounts *)doCopyDone:(int32_t)done total:(int32_t)total __attribute__((swift_name("doCopy(done:total:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int32_t done __attribute__((swift_name("done")));
@property (readonly) int32_t total __attribute__((swift_name("total")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ProgressReport")))
@interface SharedProgressReport : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)progressReport __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedProgressReport *shared __attribute__((swift_name("shared")));
- (NSString *)buildHtmlItems:(NSArray<SharedBeltProgress *> *)items __attribute__((swift_name("buildHtml(items:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KmiSearch")))
@interface SharedKmiSearch : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)kmiSearch __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedKmiSearch *shared __attribute__((swift_name("shared")));
- (NSArray<SharedSearchHit *> *)searchRepo:(NSDictionary<SharedKmiBelt *, SharedKmiBeltContent *> *)repo query:(NSString *)query belt:(SharedKmiBelt * _Nullable)belt __attribute__((swift_name("search(repo:query:belt:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SearchHit")))
@interface SharedSearchHit : SharedBase
- (instancetype)initWithBelt:(SharedKmiBelt *)belt topic:(NSString *)topic item:(NSString * _Nullable)item __attribute__((swift_name("init(belt:topic:item:)"))) __attribute__((objc_designated_initializer));
- (SharedSearchHit *)doCopyBelt:(SharedKmiBelt *)belt topic:(NSString *)topic item:(NSString * _Nullable)item __attribute__((swift_name("doCopy(belt:topic:item:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SharedKmiBelt *belt __attribute__((swift_name("belt")));
@property (readonly) NSString * _Nullable item __attribute__((swift_name("item")));
@property (readonly) NSString *topic __attribute__((swift_name("topic")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KmiTtsManager")))
@interface SharedKmiTtsManager : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)kmiTtsManager __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedKmiTtsManager *shared __attribute__((swift_name("shared")));
- (int32_t)clearCloudTtsCache __attribute__((swift_name("clearCloudTtsCache()")));
- (void)doInitPlatform:(SharedPlatformContext *)platform __attribute__((swift_name("doInit(platform:)")));
- (void)setCloudSpeakingRateRate:(double)rate __attribute__((swift_name("setCloudSpeakingRate(rate:)")));
- (void)setSpeechProfileRate:(float)rate pitch:(float)pitch __attribute__((swift_name("setSpeechProfile(rate:pitch:)")));
- (void)speakText:(NSString *)text __attribute__((swift_name("speak(text:)")));
- (void)stop __attribute__((swift_name("stop()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PlatformAudioPlayer")))
@interface SharedPlatformAudioPlayer : SharedBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (void)playFilePath:(NSString *)path speed:(float)speed __attribute__((swift_name("playFile(path:speed:)")));
- (void)release_ __attribute__((swift_name("release()")));
- (void)stop __attribute__((swift_name("stop()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PlatformCache")))
@interface SharedPlatformCache : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)platformCache __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedPlatformCache *shared __attribute__((swift_name("shared")));
- (int32_t)deleteByPrefixPrefix:(NSString *)prefix suffix:(NSString *)suffix __attribute__((swift_name("deleteByPrefix(prefix:suffix:)")));
- (SharedPlatformFile_ * _Nullable)fileIfExistsFileName:(NSString *)fileName __attribute__((swift_name("fileIfExists(fileName:)")));
- (SharedPlatformFile_ *)writeFileFileName:(NSString *)fileName bytes:(SharedKotlinByteArray *)bytes __attribute__((swift_name("writeFile(fileName:bytes:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PlatformClock")))
@interface SharedPlatformClock : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)platformClock __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedPlatformClock *shared __attribute__((swift_name("shared")));
- (int64_t)nowMs __attribute__((swift_name("nowMs()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PlatformContext")))
@interface SharedPlatformContext : SharedBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PlatformCoroutines")))
@interface SharedPlatformCoroutines : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)platformCoroutines __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedPlatformCoroutines *shared __attribute__((swift_name("shared")));
- (void)launchBackgroundBlock:(id<SharedKotlinSuspendFunction0>)block __attribute__((swift_name("launchBackground(block:)")));
- (void)launchMainBlock:(void (^)(void))block __attribute__((swift_name("launchMain(block:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PlatformEnv")))
@interface SharedPlatformEnv : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)platformEnv __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedPlatformEnv *shared __attribute__((swift_name("shared")));
- (void)doInitPlatform:(SharedPlatformContext *)platform __attribute__((swift_name("doInit(platform:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PlatformFile_")))
@interface SharedPlatformFile_ : SharedBase
- (instancetype)initWithPath:(NSString *)path __attribute__((swift_name("init(path:)"))) __attribute__((objc_designated_initializer));
@property (readonly) NSString *absolutePath __attribute__((swift_name("absolutePath")));
@property (readonly) int64_t sizeBytes __attribute__((swift_name("sizeBytes")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PlatformFormat")))
@interface SharedPlatformFormat : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)platformFormat __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedPlatformFormat *shared __attribute__((swift_name("shared")));
- (NSString *)f2V:(double)v __attribute__((swift_name("f2(v:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PlatformHttp")))
@interface SharedPlatformHttp : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)platformHttp __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedPlatformHttp *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)postJsonUrl:(NSString *)url jsonBody:(NSString *)jsonBody completionHandler:(void (^)(SharedKotlinByteArray * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("postJson(url:jsonBody:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PlatformJson")))
@interface SharedPlatformJson : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)platformJson __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedPlatformJson *shared __attribute__((swift_name("shared")));
- (NSString *)objPairs:(SharedKotlinArray<SharedKotlinPair<NSString *, id> *> *)pairs __attribute__((swift_name("obj(pairs:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PlatformPrefs")))
@interface SharedPlatformPrefs : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)platformPrefs __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedPlatformPrefs *shared __attribute__((swift_name("shared")));
- (NSString *)getStringKey:(NSString *)key default:(NSString *)default_ __attribute__((swift_name("getString(key:default:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("LogBridge")))
@interface SharedLogBridge : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)logBridge __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedLogBridge *shared __attribute__((swift_name("shared")));
- (void)dTag:(NSString *)tag msg:(NSString *)msg __attribute__((swift_name("d(tag:msg:)")));
- (void)eTag:(NSString *)tag msg:(NSString *)msg t:(SharedKotlinThrowable * _Nullable)t __attribute__((swift_name("e(tag:msg:t:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("FreeSessionsRepository_iosKt")))
@interface SharedFreeSessionsRepository_iosKt : SharedBase
+ (id<SharedFreeSessionsRepository>)freeSessionsRepository __attribute__((swift_name("freeSessionsRepository()")));
+ (int64_t)systemNowMillis __attribute__((swift_name("systemNowMillis()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("GreetingKt")))
@interface SharedGreetingKt : SharedBase
+ (NSString *)greet __attribute__((swift_name("greet()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TextExtensionsKt")))
@interface SharedTextExtensionsKt : SharedBase
+ (BOOL)containsAllKeywords:(NSString * _Nullable)receiver keywords:(NSArray<NSString *> *)keywords __attribute__((swift_name("containsAllKeywords(_:keywords:)")));
+ (NSString *)normHeb:(NSString *)receiver __attribute__((swift_name("normHeb(_:)")));
+ (NSString *)normHebLocal:(NSString *)receiver __attribute__((swift_name("normHebLocal(_:)")));
+ (NSString *)normHebOrEmpty:(NSString * _Nullable)receiver __attribute__((swift_name("normHebOrEmpty(_:)")));
+ (int32_t)searchScore:(NSString * _Nullable)receiver query:(NSString * _Nullable)query __attribute__((swift_name("searchScore(_:query:)")));
+ (NSArray<NSString *> *)toSearchKeywords:(NSString * _Nullable)receiver minLen:(int32_t)minLen __attribute__((swift_name("toSearchKeywords(_:minLen:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinEnumCompanion")))
@interface SharedKotlinEnumCompanion : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedKotlinEnumCompanion *shared __attribute__((swift_name("shared")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinArray")))
@interface SharedKotlinArray<T> : SharedBase
+ (instancetype)arrayWithSize:(int32_t)size init:(T _Nullable (^)(SharedInt *))init __attribute__((swift_name("init(size:init:)")));
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (T _Nullable)getIndex:(int32_t)index __attribute__((swift_name("get(index:)")));
- (id<SharedKotlinIterator>)iterator __attribute__((swift_name("iterator()")));
- (void)setIndex:(int32_t)index value:(T _Nullable)value __attribute__((swift_name("set(index:value:)")));
@property (readonly) int32_t size __attribute__((swift_name("size")));
@end

__attribute__((swift_name("Multiplatform_settingsSettings")))
@protocol SharedMultiplatform_settingsSettings
@required
- (void)clear __attribute__((swift_name("clear()")));
- (BOOL)getBooleanKey:(NSString *)key defaultValue:(BOOL)defaultValue __attribute__((swift_name("getBoolean(key:defaultValue:)")));
- (SharedBoolean * _Nullable)getBooleanOrNullKey:(NSString *)key __attribute__((swift_name("getBooleanOrNull(key:)")));
- (double)getDoubleKey:(NSString *)key defaultValue:(double)defaultValue __attribute__((swift_name("getDouble(key:defaultValue:)")));
- (SharedDouble * _Nullable)getDoubleOrNullKey:(NSString *)key __attribute__((swift_name("getDoubleOrNull(key:)")));
- (float)getFloatKey:(NSString *)key defaultValue:(float)defaultValue __attribute__((swift_name("getFloat(key:defaultValue:)")));
- (SharedFloat * _Nullable)getFloatOrNullKey:(NSString *)key __attribute__((swift_name("getFloatOrNull(key:)")));
- (int32_t)getIntKey:(NSString *)key defaultValue:(int32_t)defaultValue __attribute__((swift_name("getInt(key:defaultValue:)")));
- (SharedInt * _Nullable)getIntOrNullKey:(NSString *)key __attribute__((swift_name("getIntOrNull(key:)")));
- (int64_t)getLongKey:(NSString *)key defaultValue:(int64_t)defaultValue __attribute__((swift_name("getLong(key:defaultValue:)")));
- (SharedLong * _Nullable)getLongOrNullKey:(NSString *)key __attribute__((swift_name("getLongOrNull(key:)")));
- (NSString *)getStringKey:(NSString *)key defaultValue:(NSString *)defaultValue __attribute__((swift_name("getString(key:defaultValue:)")));
- (NSString * _Nullable)getStringOrNullKey:(NSString *)key __attribute__((swift_name("getStringOrNull(key:)")));
- (BOOL)hasKeyKey:(NSString *)key __attribute__((swift_name("hasKey(key:)")));
- (void)putBooleanKey:(NSString *)key value:(BOOL)value __attribute__((swift_name("putBoolean(key:value:)")));
- (void)putDoubleKey:(NSString *)key value:(double)value __attribute__((swift_name("putDouble(key:value:)")));
- (void)putFloatKey:(NSString *)key value:(float)value __attribute__((swift_name("putFloat(key:value:)")));
- (void)putIntKey:(NSString *)key value:(int32_t)value __attribute__((swift_name("putInt(key:value:)")));
- (void)putLongKey:(NSString *)key value:(int64_t)value __attribute__((swift_name("putLong(key:value:)")));
- (void)putStringKey:(NSString *)key value:(NSString *)value __attribute__((swift_name("putString(key:value:)")));
- (void)removeKey:(NSString *)key __attribute__((swift_name("remove(key:)")));
@property (readonly) NSSet<NSString *> *keys __attribute__((swift_name("keys")));
@property (readonly) int32_t size __attribute__((swift_name("size")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinPair")))
@interface SharedKotlinPair<__covariant A, __covariant B> : SharedBase
- (instancetype)initWithFirst:(A _Nullable)first second:(B _Nullable)second __attribute__((swift_name("init(first:second:)"))) __attribute__((objc_designated_initializer));
- (SharedKotlinPair<A, B> *)doCopyFirst:(A _Nullable)first second:(B _Nullable)second __attribute__((swift_name("doCopy(first:second:)")));
- (BOOL)equalsOther:(id _Nullable)other __attribute__((swift_name("equals(other:)")));
- (int32_t)hashCode __attribute__((swift_name("hashCode()")));
- (NSString *)toString __attribute__((swift_name("toString()")));
@property (readonly) A _Nullable first __attribute__((swift_name("first")));
@property (readonly) B _Nullable second __attribute__((swift_name("second")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable(with=NormalClass(value=kotlinx/datetime/serializers/InstantIso8601Serializer))
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Kotlinx_datetimeInstant")))
@interface SharedKotlinx_datetimeInstant : SharedBase <SharedKotlinComparable>
@property (class, readonly, getter=companion) SharedKotlinx_datetimeInstantCompanion *companion __attribute__((swift_name("companion")));
- (int32_t)compareToOther:(SharedKotlinx_datetimeInstant *)other __attribute__((swift_name("compareTo(other:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (SharedKotlinx_datetimeInstant *)minusDuration:(int64_t)duration __attribute__((swift_name("minus(duration:)")));
- (int64_t)minusOther:(SharedKotlinx_datetimeInstant *)other __attribute__((swift_name("minus(other:)")));
- (SharedKotlinx_datetimeInstant *)plusDuration:(int64_t)duration __attribute__((swift_name("plus(duration:)")));
- (int64_t)toEpochMilliseconds __attribute__((swift_name("toEpochMilliseconds()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int64_t epochSeconds __attribute__((swift_name("epochSeconds")));
@property (readonly) int32_t nanosecondsOfSecond __attribute__((swift_name("nanosecondsOfSecond")));
@end

__attribute__((swift_name("KotlinThrowable")))
@interface SharedKotlinThrowable : SharedBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(SharedKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(SharedKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));

/**
 * @note annotations
 *   kotlin.experimental.ExperimentalNativeApi
*/
- (SharedKotlinArray<NSString *> *)getStackTrace __attribute__((swift_name("getStackTrace()")));
- (void)printStackTrace __attribute__((swift_name("printStackTrace()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) SharedKotlinThrowable * _Nullable cause __attribute__((swift_name("cause")));
@property (readonly) NSString * _Nullable message __attribute__((swift_name("message")));
- (NSError *)asError __attribute__((swift_name("asError()")));
@end

__attribute__((swift_name("KotlinException")))
@interface SharedKotlinException : SharedKotlinThrowable
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(SharedKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(SharedKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));
@end

__attribute__((swift_name("KotlinRuntimeException")))
@interface SharedKotlinRuntimeException : SharedKotlinException
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(SharedKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(SharedKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));
@end

__attribute__((swift_name("KotlinIllegalStateException")))
@interface SharedKotlinIllegalStateException : SharedKotlinRuntimeException
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(SharedKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(SharedKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.4")
*/
__attribute__((swift_name("KotlinCancellationException")))
@interface SharedKotlinCancellationException : SharedKotlinIllegalStateException
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(SharedKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(SharedKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreFlow")))
@protocol SharedKotlinx_coroutines_coreFlow
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)collectCollector:(id<SharedKotlinx_coroutines_coreFlowCollector>)collector completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("collect(collector:completionHandler:)")));
@end

__attribute__((swift_name("Multiplatform_settingsSettingsFactory")))
@protocol SharedMultiplatform_settingsSettingsFactory
@required
- (id<SharedMultiplatform_settingsSettings>)createName:(NSString * _Nullable)name __attribute__((swift_name("create(name:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinByteArray")))
@interface SharedKotlinByteArray : SharedBase
+ (instancetype)arrayWithSize:(int32_t)size __attribute__((swift_name("init(size:)")));
+ (instancetype)arrayWithSize:(int32_t)size init:(SharedByte *(^)(SharedInt *))init __attribute__((swift_name("init(size:init:)")));
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (int8_t)getIndex:(int32_t)index __attribute__((swift_name("get(index:)")));
- (SharedKotlinByteIterator *)iterator __attribute__((swift_name("iterator()")));
- (void)setIndex:(int32_t)index value:(int8_t)value __attribute__((swift_name("set(index:value:)")));
@property (readonly) int32_t size __attribute__((swift_name("size")));
@end

__attribute__((swift_name("KotlinFunction")))
@protocol SharedKotlinFunction
@required
@end

__attribute__((swift_name("KotlinSuspendFunction0")))
@protocol SharedKotlinSuspendFunction0 <SharedKotlinFunction>
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)invokeWithCompletionHandler:(void (^)(id _Nullable_result, NSError * _Nullable))completionHandler __attribute__((swift_name("invoke(completionHandler:)")));
@end

__attribute__((swift_name("KotlinIterator")))
@protocol SharedKotlinIterator
@required
- (BOOL)hasNext __attribute__((swift_name("hasNext()")));
- (id _Nullable)next __attribute__((swift_name("next()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Kotlinx_datetimeInstant.Companion")))
@interface SharedKotlinx_datetimeInstantCompanion : SharedBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) SharedKotlinx_datetimeInstantCompanion *shared __attribute__((swift_name("shared")));
- (SharedKotlinx_datetimeInstant *)fromEpochMillisecondsEpochMilliseconds:(int64_t)epochMilliseconds __attribute__((swift_name("fromEpochMilliseconds(epochMilliseconds:)")));
- (SharedKotlinx_datetimeInstant *)fromEpochSecondsEpochSeconds:(int64_t)epochSeconds nanosecondAdjustment:(int32_t)nanosecondAdjustment __attribute__((swift_name("fromEpochSeconds(epochSeconds:nanosecondAdjustment:)")));
- (SharedKotlinx_datetimeInstant *)fromEpochSecondsEpochSeconds:(int64_t)epochSeconds nanosecondAdjustment_:(int64_t)nanosecondAdjustment __attribute__((swift_name("fromEpochSeconds(epochSeconds:nanosecondAdjustment_:)")));
- (SharedKotlinx_datetimeInstant *)now __attribute__((swift_name("now()"))) __attribute__((unavailable("Use Clock.System.now() instead")));
- (SharedKotlinx_datetimeInstant *)parseInput:(id)input format:(id<SharedKotlinx_datetimeDateTimeFormat>)format __attribute__((swift_name("parse(input:format:)")));
- (id<SharedKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@property (readonly) SharedKotlinx_datetimeInstant *DISTANT_FUTURE __attribute__((swift_name("DISTANT_FUTURE")));
@property (readonly) SharedKotlinx_datetimeInstant *DISTANT_PAST __attribute__((swift_name("DISTANT_PAST")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreFlowCollector")))
@protocol SharedKotlinx_coroutines_coreFlowCollector
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)emitValue:(id _Nullable)value completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("emit(value:completionHandler:)")));
@end

__attribute__((swift_name("KotlinByteIterator")))
@interface SharedKotlinByteIterator : SharedBase <SharedKotlinIterator>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (SharedByte *)next __attribute__((swift_name("next()")));
- (int8_t)nextByte __attribute__((swift_name("nextByte()")));
@end

__attribute__((swift_name("Kotlinx_datetimeDateTimeFormat")))
@protocol SharedKotlinx_datetimeDateTimeFormat
@required
- (NSString *)formatValue:(id _Nullable)value __attribute__((swift_name("format(value:)")));
- (id<SharedKotlinAppendable>)formatToAppendable:(id<SharedKotlinAppendable>)appendable value:(id _Nullable)value __attribute__((swift_name("formatTo(appendable:value:)")));
- (id _Nullable)parseInput:(id)input __attribute__((swift_name("parse(input:)")));
- (id _Nullable)parseOrNullInput:(id)input __attribute__((swift_name("parseOrNull(input:)")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreSerializationStrategy")))
@protocol SharedKotlinx_serialization_coreSerializationStrategy
@required
- (void)serializeEncoder:(id<SharedKotlinx_serialization_coreEncoder>)encoder value:(id _Nullable)value __attribute__((swift_name("serialize(encoder:value:)")));
@property (readonly) id<SharedKotlinx_serialization_coreSerialDescriptor> descriptor __attribute__((swift_name("descriptor")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreDeserializationStrategy")))
@protocol SharedKotlinx_serialization_coreDeserializationStrategy
@required
- (id _Nullable)deserializeDecoder:(id<SharedKotlinx_serialization_coreDecoder>)decoder __attribute__((swift_name("deserialize(decoder:)")));
@property (readonly) id<SharedKotlinx_serialization_coreSerialDescriptor> descriptor __attribute__((swift_name("descriptor")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreKSerializer")))
@protocol SharedKotlinx_serialization_coreKSerializer <SharedKotlinx_serialization_coreSerializationStrategy, SharedKotlinx_serialization_coreDeserializationStrategy>
@required
@end

__attribute__((swift_name("KotlinAppendable")))
@protocol SharedKotlinAppendable
@required
- (id<SharedKotlinAppendable>)appendValue:(unichar)value __attribute__((swift_name("append(value:)")));
- (id<SharedKotlinAppendable>)appendValue_:(id _Nullable)value __attribute__((swift_name("append(value_:)")));
- (id<SharedKotlinAppendable>)appendValue:(id _Nullable)value startIndex:(int32_t)startIndex endIndex:(int32_t)endIndex __attribute__((swift_name("append(value:startIndex:endIndex:)")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreEncoder")))
@protocol SharedKotlinx_serialization_coreEncoder
@required
- (id<SharedKotlinx_serialization_coreCompositeEncoder>)beginCollectionDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor collectionSize:(int32_t)collectionSize __attribute__((swift_name("beginCollection(descriptor:collectionSize:)")));
- (id<SharedKotlinx_serialization_coreCompositeEncoder>)beginStructureDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("beginStructure(descriptor:)")));
- (void)encodeBooleanValue:(BOOL)value __attribute__((swift_name("encodeBoolean(value:)")));
- (void)encodeByteValue:(int8_t)value __attribute__((swift_name("encodeByte(value:)")));
- (void)encodeCharValue:(unichar)value __attribute__((swift_name("encodeChar(value:)")));
- (void)encodeDoubleValue:(double)value __attribute__((swift_name("encodeDouble(value:)")));
- (void)encodeEnumEnumDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)enumDescriptor index:(int32_t)index __attribute__((swift_name("encodeEnum(enumDescriptor:index:)")));
- (void)encodeFloatValue:(float)value __attribute__((swift_name("encodeFloat(value:)")));
- (id<SharedKotlinx_serialization_coreEncoder>)encodeInlineDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("encodeInline(descriptor:)")));
- (void)encodeIntValue:(int32_t)value __attribute__((swift_name("encodeInt(value:)")));
- (void)encodeLongValue:(int64_t)value __attribute__((swift_name("encodeLong(value:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (void)encodeNotNullMark __attribute__((swift_name("encodeNotNullMark()")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (void)encodeNull __attribute__((swift_name("encodeNull()")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (void)encodeNullableSerializableValueSerializer:(id<SharedKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeNullableSerializableValue(serializer:value:)")));
- (void)encodeSerializableValueSerializer:(id<SharedKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeSerializableValue(serializer:value:)")));
- (void)encodeShortValue:(int16_t)value __attribute__((swift_name("encodeShort(value:)")));
- (void)encodeStringValue:(NSString *)value __attribute__((swift_name("encodeString(value:)")));
@property (readonly) SharedKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreSerialDescriptor")))
@protocol SharedKotlinx_serialization_coreSerialDescriptor
@required

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (NSArray<id<SharedKotlinAnnotation>> *)getElementAnnotationsIndex:(int32_t)index __attribute__((swift_name("getElementAnnotations(index:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id<SharedKotlinx_serialization_coreSerialDescriptor>)getElementDescriptorIndex:(int32_t)index __attribute__((swift_name("getElementDescriptor(index:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (int32_t)getElementIndexName:(NSString *)name __attribute__((swift_name("getElementIndex(name:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (NSString *)getElementNameIndex:(int32_t)index __attribute__((swift_name("getElementName(index:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (BOOL)isElementOptionalIndex:(int32_t)index __attribute__((swift_name("isElementOptional(index:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
@property (readonly) NSArray<id<SharedKotlinAnnotation>> *annotations __attribute__((swift_name("annotations")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
@property (readonly) int32_t elementsCount __attribute__((swift_name("elementsCount")));
@property (readonly) BOOL isInline __attribute__((swift_name("isInline")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
@property (readonly) BOOL isNullable __attribute__((swift_name("isNullable")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
@property (readonly) SharedKotlinx_serialization_coreSerialKind *kind __attribute__((swift_name("kind")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
@property (readonly) NSString *serialName __attribute__((swift_name("serialName")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreDecoder")))
@protocol SharedKotlinx_serialization_coreDecoder
@required
- (id<SharedKotlinx_serialization_coreCompositeDecoder>)beginStructureDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("beginStructure(descriptor:)")));
- (BOOL)decodeBoolean __attribute__((swift_name("decodeBoolean()")));
- (int8_t)decodeByte __attribute__((swift_name("decodeByte()")));
- (unichar)decodeChar __attribute__((swift_name("decodeChar()")));
- (double)decodeDouble __attribute__((swift_name("decodeDouble()")));
- (int32_t)decodeEnumEnumDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)enumDescriptor __attribute__((swift_name("decodeEnum(enumDescriptor:)")));
- (float)decodeFloat __attribute__((swift_name("decodeFloat()")));
- (id<SharedKotlinx_serialization_coreDecoder>)decodeInlineDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("decodeInline(descriptor:)")));
- (int32_t)decodeInt __attribute__((swift_name("decodeInt()")));
- (int64_t)decodeLong __attribute__((swift_name("decodeLong()")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (BOOL)decodeNotNullMark __attribute__((swift_name("decodeNotNullMark()")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (SharedKotlinNothing * _Nullable)decodeNull __attribute__((swift_name("decodeNull()")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id _Nullable)decodeNullableSerializableValueDeserializer:(id<SharedKotlinx_serialization_coreDeserializationStrategy>)deserializer __attribute__((swift_name("decodeNullableSerializableValue(deserializer:)")));
- (id _Nullable)decodeSerializableValueDeserializer:(id<SharedKotlinx_serialization_coreDeserializationStrategy>)deserializer __attribute__((swift_name("decodeSerializableValue(deserializer:)")));
- (int16_t)decodeShort __attribute__((swift_name("decodeShort()")));
- (NSString *)decodeString __attribute__((swift_name("decodeString()")));
@property (readonly) SharedKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreCompositeEncoder")))
@protocol SharedKotlinx_serialization_coreCompositeEncoder
@required
- (void)encodeBooleanElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(BOOL)value __attribute__((swift_name("encodeBooleanElement(descriptor:index:value:)")));
- (void)encodeByteElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(int8_t)value __attribute__((swift_name("encodeByteElement(descriptor:index:value:)")));
- (void)encodeCharElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(unichar)value __attribute__((swift_name("encodeCharElement(descriptor:index:value:)")));
- (void)encodeDoubleElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(double)value __attribute__((swift_name("encodeDoubleElement(descriptor:index:value:)")));
- (void)encodeFloatElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(float)value __attribute__((swift_name("encodeFloatElement(descriptor:index:value:)")));
- (id<SharedKotlinx_serialization_coreEncoder>)encodeInlineElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("encodeInlineElement(descriptor:index:)")));
- (void)encodeIntElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(int32_t)value __attribute__((swift_name("encodeIntElement(descriptor:index:value:)")));
- (void)encodeLongElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(int64_t)value __attribute__((swift_name("encodeLongElement(descriptor:index:value:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (void)encodeNullableSerializableElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index serializer:(id<SharedKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeNullableSerializableElement(descriptor:index:serializer:value:)")));
- (void)encodeSerializableElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index serializer:(id<SharedKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeSerializableElement(descriptor:index:serializer:value:)")));
- (void)encodeShortElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(int16_t)value __attribute__((swift_name("encodeShortElement(descriptor:index:value:)")));
- (void)encodeStringElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(NSString *)value __attribute__((swift_name("encodeStringElement(descriptor:index:value:)")));
- (void)endStructureDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("endStructure(descriptor:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (BOOL)shouldEncodeElementDefaultDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("shouldEncodeElementDefault(descriptor:index:)")));
@property (readonly) SharedKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreSerializersModule")))
@interface SharedKotlinx_serialization_coreSerializersModule : SharedBase

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (void)dumpToCollector:(id<SharedKotlinx_serialization_coreSerializersModuleCollector>)collector __attribute__((swift_name("dumpTo(collector:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id<SharedKotlinx_serialization_coreKSerializer> _Nullable)getContextualKClass:(id<SharedKotlinKClass>)kClass typeArgumentsSerializers:(NSArray<id<SharedKotlinx_serialization_coreKSerializer>> *)typeArgumentsSerializers __attribute__((swift_name("getContextual(kClass:typeArgumentsSerializers:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id<SharedKotlinx_serialization_coreSerializationStrategy> _Nullable)getPolymorphicBaseClass:(id<SharedKotlinKClass>)baseClass value:(id)value __attribute__((swift_name("getPolymorphic(baseClass:value:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id<SharedKotlinx_serialization_coreDeserializationStrategy> _Nullable)getPolymorphicBaseClass:(id<SharedKotlinKClass>)baseClass serializedClassName:(NSString * _Nullable)serializedClassName __attribute__((swift_name("getPolymorphic(baseClass:serializedClassName:)")));
@end

__attribute__((swift_name("KotlinAnnotation")))
@protocol SharedKotlinAnnotation
@required
@end


/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
__attribute__((swift_name("Kotlinx_serialization_coreSerialKind")))
@interface SharedKotlinx_serialization_coreSerialKind : SharedBase
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreCompositeDecoder")))
@protocol SharedKotlinx_serialization_coreCompositeDecoder
@required
- (BOOL)decodeBooleanElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeBooleanElement(descriptor:index:)")));
- (int8_t)decodeByteElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeByteElement(descriptor:index:)")));
- (unichar)decodeCharElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeCharElement(descriptor:index:)")));
- (int32_t)decodeCollectionSizeDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("decodeCollectionSize(descriptor:)")));
- (double)decodeDoubleElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeDoubleElement(descriptor:index:)")));
- (int32_t)decodeElementIndexDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("decodeElementIndex(descriptor:)")));
- (float)decodeFloatElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeFloatElement(descriptor:index:)")));
- (id<SharedKotlinx_serialization_coreDecoder>)decodeInlineElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeInlineElement(descriptor:index:)")));
- (int32_t)decodeIntElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeIntElement(descriptor:index:)")));
- (int64_t)decodeLongElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeLongElement(descriptor:index:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id _Nullable)decodeNullableSerializableElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index deserializer:(id<SharedKotlinx_serialization_coreDeserializationStrategy>)deserializer previousValue:(id _Nullable)previousValue __attribute__((swift_name("decodeNullableSerializableElement(descriptor:index:deserializer:previousValue:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (BOOL)decodeSequentially __attribute__((swift_name("decodeSequentially()")));
- (id _Nullable)decodeSerializableElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index deserializer:(id<SharedKotlinx_serialization_coreDeserializationStrategy>)deserializer previousValue:(id _Nullable)previousValue __attribute__((swift_name("decodeSerializableElement(descriptor:index:deserializer:previousValue:)")));
- (int16_t)decodeShortElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeShortElement(descriptor:index:)")));
- (NSString *)decodeStringElementDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeStringElement(descriptor:index:)")));
- (void)endStructureDescriptor:(id<SharedKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("endStructure(descriptor:)")));
@property (readonly) SharedKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinNothing")))
@interface SharedKotlinNothing : SharedBase
@end


/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
__attribute__((swift_name("Kotlinx_serialization_coreSerializersModuleCollector")))
@protocol SharedKotlinx_serialization_coreSerializersModuleCollector
@required
- (void)contextualKClass:(id<SharedKotlinKClass>)kClass provider:(id<SharedKotlinx_serialization_coreKSerializer> (^)(NSArray<id<SharedKotlinx_serialization_coreKSerializer>> *))provider __attribute__((swift_name("contextual(kClass:provider:)")));
- (void)contextualKClass:(id<SharedKotlinKClass>)kClass serializer:(id<SharedKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("contextual(kClass:serializer:)")));
- (void)polymorphicBaseClass:(id<SharedKotlinKClass>)baseClass actualClass:(id<SharedKotlinKClass>)actualClass actualSerializer:(id<SharedKotlinx_serialization_coreKSerializer>)actualSerializer __attribute__((swift_name("polymorphic(baseClass:actualClass:actualSerializer:)")));
- (void)polymorphicDefaultBaseClass:(id<SharedKotlinKClass>)baseClass defaultDeserializerProvider:(id<SharedKotlinx_serialization_coreDeserializationStrategy> _Nullable (^)(NSString * _Nullable))defaultDeserializerProvider __attribute__((swift_name("polymorphicDefault(baseClass:defaultDeserializerProvider:)"))) __attribute__((deprecated("Deprecated in favor of function with more precise name: polymorphicDefaultDeserializer")));
- (void)polymorphicDefaultDeserializerBaseClass:(id<SharedKotlinKClass>)baseClass defaultDeserializerProvider:(id<SharedKotlinx_serialization_coreDeserializationStrategy> _Nullable (^)(NSString * _Nullable))defaultDeserializerProvider __attribute__((swift_name("polymorphicDefaultDeserializer(baseClass:defaultDeserializerProvider:)")));
- (void)polymorphicDefaultSerializerBaseClass:(id<SharedKotlinKClass>)baseClass defaultSerializerProvider:(id<SharedKotlinx_serialization_coreSerializationStrategy> _Nullable (^)(id))defaultSerializerProvider __attribute__((swift_name("polymorphicDefaultSerializer(baseClass:defaultSerializerProvider:)")));
@end

__attribute__((swift_name("KotlinKDeclarationContainer")))
@protocol SharedKotlinKDeclarationContainer
@required
@end

__attribute__((swift_name("KotlinKAnnotatedElement")))
@protocol SharedKotlinKAnnotatedElement
@required
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.1")
*/
__attribute__((swift_name("KotlinKClassifier")))
@protocol SharedKotlinKClassifier
@required
@end

__attribute__((swift_name("KotlinKClass")))
@protocol SharedKotlinKClass <SharedKotlinKDeclarationContainer, SharedKotlinKAnnotatedElement, SharedKotlinKClassifier>
@required

/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.1")
*/
- (BOOL)isInstanceValue:(id _Nullable)value __attribute__((swift_name("isInstance(value:)")));
@property (readonly) NSString * _Nullable qualifiedName __attribute__((swift_name("qualifiedName")));
@property (readonly) NSString * _Nullable simpleName __attribute__((swift_name("simpleName")));
@end

#pragma pop_macro("_Nullable_result")
#pragma clang diagnostic pop
NS_ASSUME_NONNULL_END
