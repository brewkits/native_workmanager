#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

@class KMPWMBGTaskType, KMPWMBackoffPolicy, KMPWMCRC32, KMPWMChainExecutorCompanion, KMPWMChainExecutorExecutionMetrics, KMPWMChainProgress, KMPWMChainProgressCompanion, KMPWMConstraints, KMPWMConstraintsCompanion, KMPWMEventStoreConfig, KMPWMEventSyncManager, KMPWMExactAlarmIOSBehavior, KMPWMExistingPolicy, KMPWMInfoPlistReader, KMPWMKoin_coreBeanDefinition<T>, KMPWMKoin_coreCallbacks<T>, KMPWMKoin_coreCoreResolver, KMPWMKoin_coreExtensionManager, KMPWMKoin_coreInstanceFactory<T>, KMPWMKoin_coreInstanceFactoryCompanion, KMPWMKoin_coreInstanceRegistry, KMPWMKoin_coreKind, KMPWMKoin_coreKoin, KMPWMKoin_coreKoinDefinition<R>, KMPWMKoin_coreLevel, KMPWMKoin_coreLockable, KMPWMKoin_coreLogger, KMPWMKoin_coreModule, KMPWMKoin_coreOptionRegistry, KMPWMKoin_coreParametersHolder, KMPWMKoin_corePropertyRegistry, KMPWMKoin_coreResolutionContext, KMPWMKoin_coreScope, KMPWMKoin_coreScopeDSL, KMPWMKoin_coreScopeRegistry, KMPWMKoin_coreScopeRegistryCompanion, KMPWMKoin_coreSingleInstanceFactory<T>, KMPWMKoin_coreTypeQualifier, KMPWMKotlinArray<T>, KMPWMKotlinByteArray, KMPWMKotlinByteIterator, KMPWMKotlinEnum<E>, KMPWMKotlinEnumCompanion, KMPWMKotlinException, KMPWMKotlinIllegalStateException, KMPWMKotlinLazyThreadSafetyMode, KMPWMKotlinNothing, KMPWMKotlinRuntimeException, KMPWMKotlinThrowable, KMPWMKotlinx_serialization_coreSerialKind, KMPWMKotlinx_serialization_coreSerializersModule, KMPWMLogTags, KMPWMLogger, KMPWMLoggerLevel, KMPWMMigrationResult, KMPWMQos, KMPWMScheduleResult, KMPWMSingleTaskExecutorCompanion, KMPWMStoredEvent, KMPWMStoredEventCompanion, KMPWMSystemConstraint, KMPWMSystemConstraintCompanion, KMPWMTaskChain, KMPWMTaskCompletionEvent, KMPWMTaskCompletionEventCompanion, KMPWMTaskEventBus, KMPWMTaskEventManager, KMPWMTaskIds, KMPWMTaskProgressBus, KMPWMTaskProgressEvent, KMPWMTaskProgressEventCompanion, KMPWMTaskRequest, KMPWMTaskRequestCompanion, KMPWMTaskSpec<T>, KMPWMTaskTriggerBatteryLow, KMPWMTaskTriggerBatteryOkay, KMPWMTaskTriggerContentUri, KMPWMTaskTriggerDeviceIdle, KMPWMTaskTriggerExact, KMPWMTaskTriggerOneTime, KMPWMTaskTriggerPeriodic, KMPWMTaskTriggerStorageLow, KMPWMTaskTriggerWindowed, KMPWMWorkerProgress, KMPWMWorkerProgressCompanion, KMPWMWorkerTypes;

@protocol KMPWMBackgroundTaskScheduler, KMPWMCloseable, KMPWMEventStore, KMPWMIosWorkerFactory, KMPWMKoin_coreKoinComponent, KMPWMKoin_coreKoinExtension, KMPWMKoin_coreKoinScopeComponent, KMPWMKoin_coreQualifier, KMPWMKoin_coreResolutionExtension, KMPWMKoin_coreScopeCallback, KMPWMKotlinAnnotation, KMPWMKotlinComparable, KMPWMKotlinIterator, KMPWMKotlinKAnnotatedElement, KMPWMKotlinKClass, KMPWMKotlinKClassifier, KMPWMKotlinKDeclarationContainer, KMPWMKotlinLazy, KMPWMKotlinx_coroutines_coreFlow, KMPWMKotlinx_coroutines_coreFlowCollector, KMPWMKotlinx_coroutines_coreSharedFlow, KMPWMKotlinx_serialization_coreCompositeDecoder, KMPWMKotlinx_serialization_coreCompositeEncoder, KMPWMKotlinx_serialization_coreDecoder, KMPWMKotlinx_serialization_coreDeserializationStrategy, KMPWMKotlinx_serialization_coreEncoder, KMPWMKotlinx_serialization_coreKSerializer, KMPWMKotlinx_serialization_coreSerialDescriptor, KMPWMKotlinx_serialization_coreSerializationStrategy, KMPWMKotlinx_serialization_coreSerializersModuleCollector, KMPWMTaskTrigger, KMPWMWorker, KMPWMWorkerFactory;

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
@interface KMPWMBase : NSObject
- (instancetype)init __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
+ (void)initialize __attribute__((objc_requires_super));
@end

@interface KMPWMBase (KMPWMBaseCopying) <NSCopying>
@end

__attribute__((swift_name("KotlinMutableSet")))
@interface KMPWMMutableSet<ObjectType> : NSMutableSet<ObjectType>
@end

__attribute__((swift_name("KotlinMutableDictionary")))
@interface KMPWMMutableDictionary<KeyType, ObjectType> : NSMutableDictionary<KeyType, ObjectType>
@end

@interface NSError (NSErrorKMPWMKotlinException)
@property (readonly) id _Nullable kotlinException;
@end

__attribute__((swift_name("KotlinNumber")))
@interface KMPWMNumber : NSNumber
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
@interface KMPWMByte : KMPWMNumber
- (instancetype)initWithChar:(char)value;
+ (instancetype)numberWithChar:(char)value;
@end

__attribute__((swift_name("KotlinUByte")))
@interface KMPWMUByte : KMPWMNumber
- (instancetype)initWithUnsignedChar:(unsigned char)value;
+ (instancetype)numberWithUnsignedChar:(unsigned char)value;
@end

__attribute__((swift_name("KotlinShort")))
@interface KMPWMShort : KMPWMNumber
- (instancetype)initWithShort:(short)value;
+ (instancetype)numberWithShort:(short)value;
@end

__attribute__((swift_name("KotlinUShort")))
@interface KMPWMUShort : KMPWMNumber
- (instancetype)initWithUnsignedShort:(unsigned short)value;
+ (instancetype)numberWithUnsignedShort:(unsigned short)value;
@end

__attribute__((swift_name("KotlinInt")))
@interface KMPWMInt : KMPWMNumber
- (instancetype)initWithInt:(int)value;
+ (instancetype)numberWithInt:(int)value;
@end

__attribute__((swift_name("KotlinUInt")))
@interface KMPWMUInt : KMPWMNumber
- (instancetype)initWithUnsignedInt:(unsigned int)value;
+ (instancetype)numberWithUnsignedInt:(unsigned int)value;
@end

__attribute__((swift_name("KotlinLong")))
@interface KMPWMLong : KMPWMNumber
- (instancetype)initWithLongLong:(long long)value;
+ (instancetype)numberWithLongLong:(long long)value;
@end

__attribute__((swift_name("KotlinULong")))
@interface KMPWMULong : KMPWMNumber
- (instancetype)initWithUnsignedLongLong:(unsigned long long)value;
+ (instancetype)numberWithUnsignedLongLong:(unsigned long long)value;
@end

__attribute__((swift_name("KotlinFloat")))
@interface KMPWMFloat : KMPWMNumber
- (instancetype)initWithFloat:(float)value;
+ (instancetype)numberWithFloat:(float)value;
@end

__attribute__((swift_name("KotlinDouble")))
@interface KMPWMDouble : KMPWMNumber
- (instancetype)initWithDouble:(double)value;
+ (instancetype)numberWithDouble:(double)value;
@end

__attribute__((swift_name("KotlinBoolean")))
@interface KMPWMBoolean : KMPWMNumber
- (instancetype)initWithBool:(BOOL)value;
+ (instancetype)numberWithBool:(BOOL)value;
@end

__attribute__((swift_name("Closeable")))
@protocol KMPWMCloseable
@required
- (void)close __attribute__((swift_name("close()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ChainExecutor")))
@interface KMPWMChainExecutor : KMPWMBase <KMPWMCloseable>
- (instancetype)initWithWorkerFactory:(id<KMPWMIosWorkerFactory>)workerFactory taskType:(KMPWMBGTaskType *)taskType __attribute__((swift_name("init(workerFactory:taskType:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMChainExecutorCompanion *companion __attribute__((swift_name("companion")));
- (void)cleanup __attribute__((swift_name("cleanup()"))) __attribute__((deprecated("Use close() or .use {} pattern instead")));
- (void)close __attribute__((swift_name("close()")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)executeChainsInBatchMaxChains:(int32_t)maxChains totalTimeoutMs:(int64_t)totalTimeoutMs deadlineEpochMs:(KMPWMLong * _Nullable)deadlineEpochMs completionHandler:(void (^)(KMPWMInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("executeChainsInBatch(maxChains:totalTimeoutMs:deadlineEpochMs:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)executeNextChainFromQueueWithCompletionHandler:(void (^)(KMPWMBoolean * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("executeNextChainFromQueue(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getChainQueueSizeWithCompletionHandler:(void (^)(KMPWMInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getChainQueueSize(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)requestShutdownWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("requestShutdown(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)resetShutdownStateWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("resetShutdownState(completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ChainExecutor.Companion")))
@interface KMPWMChainExecutorCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMChainExecutorCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) int64_t CHAIN_TIMEOUT_MS __attribute__((swift_name("CHAIN_TIMEOUT_MS")));
@property (readonly) int64_t SHUTDOWN_GRACE_PERIOD_MS __attribute__((swift_name("SHUTDOWN_GRACE_PERIOD_MS")));
@property (readonly) int64_t TASK_TIMEOUT_MS __attribute__((swift_name("TASK_TIMEOUT_MS")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ChainExecutor.ExecutionMetrics")))
@interface KMPWMChainExecutorExecutionMetrics : KMPWMBase
- (instancetype)initWithTaskType:(KMPWMBGTaskType *)taskType startTime:(int64_t)startTime endTime:(int64_t)endTime duration:(int64_t)duration chainsAttempted:(int32_t)chainsAttempted chainsSucceeded:(int32_t)chainsSucceeded chainsFailed:(int32_t)chainsFailed wasKilledBySystem:(BOOL)wasKilledBySystem timeUsagePercentage:(int32_t)timeUsagePercentage queueSizeRemaining:(int32_t)queueSizeRemaining __attribute__((swift_name("init(taskType:startTime:endTime:duration:chainsAttempted:chainsSucceeded:chainsFailed:wasKilledBySystem:timeUsagePercentage:queueSizeRemaining:)"))) __attribute__((objc_designated_initializer));
- (KMPWMChainExecutorExecutionMetrics *)doCopyTaskType:(KMPWMBGTaskType *)taskType startTime:(int64_t)startTime endTime:(int64_t)endTime duration:(int64_t)duration chainsAttempted:(int32_t)chainsAttempted chainsSucceeded:(int32_t)chainsSucceeded chainsFailed:(int32_t)chainsFailed wasKilledBySystem:(BOOL)wasKilledBySystem timeUsagePercentage:(int32_t)timeUsagePercentage queueSizeRemaining:(int32_t)queueSizeRemaining __attribute__((swift_name("doCopy(taskType:startTime:endTime:duration:chainsAttempted:chainsSucceeded:chainsFailed:wasKilledBySystem:timeUsagePercentage:queueSizeRemaining:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int32_t chainsAttempted __attribute__((swift_name("chainsAttempted")));
@property (readonly) int32_t chainsFailed __attribute__((swift_name("chainsFailed")));
@property (readonly) int32_t chainsSucceeded __attribute__((swift_name("chainsSucceeded")));
@property (readonly) int64_t duration __attribute__((swift_name("duration")));
@property (readonly) int64_t endTime __attribute__((swift_name("endTime")));
@property (readonly) int32_t queueSizeRemaining __attribute__((swift_name("queueSizeRemaining")));
@property (readonly) int64_t startTime __attribute__((swift_name("startTime")));
@property (readonly) KMPWMBGTaskType *taskType __attribute__((swift_name("taskType")));
@property (readonly) int32_t timeUsagePercentage __attribute__((swift_name("timeUsagePercentage")));
@property (readonly) BOOL wasKilledBySystem __attribute__((swift_name("wasKilledBySystem")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ChainProgress")))
@interface KMPWMChainProgress : KMPWMBase
- (instancetype)initWithChainId:(NSString *)chainId totalSteps:(int32_t)totalSteps completedSteps:(NSArray<KMPWMInt *> *)completedSteps completedTasksInSteps:(NSDictionary<KMPWMInt *, NSArray<KMPWMInt *> *> *)completedTasksInSteps lastFailedStep:(KMPWMInt * _Nullable)lastFailedStep retryCount:(int32_t)retryCount maxRetries:(int32_t)maxRetries __attribute__((swift_name("init(chainId:totalSteps:completedSteps:completedTasksInSteps:lastFailedStep:retryCount:maxRetries:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMChainProgressCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMChainProgress *)doCopyChainId:(NSString *)chainId totalSteps:(int32_t)totalSteps completedSteps:(NSArray<KMPWMInt *> *)completedSteps completedTasksInSteps:(NSDictionary<KMPWMInt *, NSArray<KMPWMInt *> *> *)completedTasksInSteps lastFailedStep:(KMPWMInt * _Nullable)lastFailedStep retryCount:(int32_t)retryCount maxRetries:(int32_t)maxRetries __attribute__((swift_name("doCopy(chainId:totalSteps:completedSteps:completedTasksInSteps:lastFailedStep:retryCount:maxRetries:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (int32_t)getCompletionPercentage __attribute__((swift_name("getCompletionPercentage()")));
- (KMPWMInt * _Nullable)getNextStepIndex __attribute__((swift_name("getNextStepIndex()")));
- (BOOL)hasExceededRetries __attribute__((swift_name("hasExceededRetries()")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (BOOL)isComplete __attribute__((swift_name("isComplete()")));
- (BOOL)isStepCompletedStepIndex:(int32_t)stepIndex __attribute__((swift_name("isStepCompleted(stepIndex:)")));
- (BOOL)isTaskInStepCompletedStepIndex:(int32_t)stepIndex taskIndex:(int32_t)taskIndex __attribute__((swift_name("isTaskInStepCompleted(stepIndex:taskIndex:)")));
- (NSString *)description __attribute__((swift_name("description()")));
- (KMPWMChainProgress *)withCompletedStepStepIndex:(int32_t)stepIndex __attribute__((swift_name("withCompletedStep(stepIndex:)")));
- (KMPWMChainProgress *)withCompletedTaskInStepStepIndex:(int32_t)stepIndex taskIndex:(int32_t)taskIndex __attribute__((swift_name("withCompletedTaskInStep(stepIndex:taskIndex:)")));
- (KMPWMChainProgress *)withFailureStepIndex:(int32_t)stepIndex __attribute__((swift_name("withFailure(stepIndex:)")));
@property (readonly) NSString *chainId __attribute__((swift_name("chainId")));
@property (readonly) NSArray<KMPWMInt *> *completedSteps __attribute__((swift_name("completedSteps")));
@property (readonly) NSDictionary<KMPWMInt *, NSArray<KMPWMInt *> *> *completedTasksInSteps __attribute__((swift_name("completedTasksInSteps")));
@property (readonly) KMPWMInt * _Nullable lastFailedStep __attribute__((swift_name("lastFailedStep")));
@property (readonly) int32_t maxRetries __attribute__((swift_name("maxRetries")));
@property (readonly) int32_t retryCount __attribute__((swift_name("retryCount")));
@property (readonly) int32_t totalSteps __attribute__((swift_name("totalSteps")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ChainProgress.Companion")))
@interface KMPWMChainProgressCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMChainProgressCompanion *shared __attribute__((swift_name("shared")));
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end

__attribute__((swift_name("KotlinThrowable")))
@interface KMPWMKotlinThrowable : KMPWMBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(KMPWMKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(KMPWMKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));

/**
 * @note annotations
 *   kotlin.experimental.ExperimentalNativeApi
*/
- (KMPWMKotlinArray<NSString *> *)getStackTrace __attribute__((swift_name("getStackTrace()")));
- (void)printStackTrace __attribute__((swift_name("printStackTrace()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) KMPWMKotlinThrowable * _Nullable cause __attribute__((swift_name("cause")));
@property (readonly) NSString * _Nullable message __attribute__((swift_name("message")));
- (NSError *)asError __attribute__((swift_name("asError()")));
@end

__attribute__((swift_name("KotlinException")))
@interface KMPWMKotlinException : KMPWMKotlinThrowable
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(KMPWMKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(KMPWMKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("CorruptQueueException")))
@interface KMPWMCorruptQueueException : KMPWMKotlinException
- (instancetype)initWithMessage:(NSString *)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
- (instancetype)initWithCause:(KMPWMKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(KMPWMKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("InfoPlistReader")))
@interface KMPWMInfoPlistReader : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)infoPlistReader __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMInfoPlistReader *shared __attribute__((swift_name("shared")));
- (BOOL)isTaskIdPermittedTaskId:(NSString *)taskId __attribute__((swift_name("isTaskIdPermitted(taskId:)")));
- (NSSet<NSString *> *)readPermittedTaskIds __attribute__((swift_name("readPermittedTaskIds()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("InsufficientDiskSpaceException")))
@interface KMPWMInsufficientDiskSpaceException : KMPWMKotlinException
- (instancetype)initWithRequired:(int64_t)required available:(int64_t)available __attribute__((swift_name("init(required:available:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)initWithCause:(KMPWMKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(KMPWMKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (readonly) int64_t available __attribute__((swift_name("available")));
@property (readonly) int64_t required __attribute__((swift_name("required")));
@end

__attribute__((swift_name("Worker")))
@protocol KMPWMWorker
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)doWorkInput:(NSString * _Nullable)input completionHandler:(void (^)(KMPWMBoolean * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("doWork(input:completionHandler:)")));
@end

__attribute__((swift_name("IosWorker")))
@protocol KMPWMIosWorker <KMPWMWorker>
@required
@end

__attribute__((swift_name("WorkerFactory")))
@protocol KMPWMWorkerFactory
@required
- (id<KMPWMWorker> _Nullable)createWorkerWorkerClassName:(NSString *)workerClassName __attribute__((swift_name("createWorker(workerClassName:)")));
@end

__attribute__((swift_name("IosWorkerFactory")))
@protocol KMPWMIosWorkerFactory <KMPWMWorkerFactory>
@required
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("MigrationResult")))
@interface KMPWMMigrationResult : KMPWMBase
- (instancetype)initWithSuccess:(BOOL)success message:(NSString *)message chainsMigrated:(int32_t)chainsMigrated metadataMigrated:(int32_t)metadataMigrated __attribute__((swift_name("init(success:message:chainsMigrated:metadataMigrated:)"))) __attribute__((objc_designated_initializer));
- (KMPWMMigrationResult *)doCopySuccess:(BOOL)success message:(NSString *)message chainsMigrated:(int32_t)chainsMigrated metadataMigrated:(int32_t)metadataMigrated __attribute__((swift_name("doCopy(success:message:chainsMigrated:metadataMigrated:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int32_t chainsMigrated __attribute__((swift_name("chainsMigrated")));
@property (readonly) NSString *message __attribute__((swift_name("message")));
@property (readonly) int32_t metadataMigrated __attribute__((swift_name("metadataMigrated")));
@property (readonly) BOOL success __attribute__((swift_name("success")));
@end

__attribute__((swift_name("BackgroundTaskScheduler")))
@protocol KMPWMBackgroundTaskScheduler
@required
- (KMPWMTaskChain *)beginWithTask:(KMPWMTaskRequest *)task __attribute__((swift_name("beginWith(task:)")));
- (KMPWMTaskChain *)beginWithTasks:(NSArray<KMPWMTaskRequest *> *)tasks __attribute__((swift_name("beginWith(tasks:)")));
- (void)cancelId:(NSString *)id __attribute__((swift_name("cancel(id:)")));
- (void)cancelAll __attribute__((swift_name("cancelAll()")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)enqueueId:(NSString *)id trigger:(id<KMPWMTaskTrigger>)trigger workerClassName:(NSString *)workerClassName constraints:(KMPWMConstraints *)constraints inputJson:(NSString * _Nullable)inputJson policy:(KMPWMExistingPolicy *)policy completionHandler:(void (^)(KMPWMScheduleResult * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("enqueue(id:trigger:workerClassName:constraints:inputJson:policy:completionHandler:)")));
- (void)enqueueChainChain:(KMPWMTaskChain *)chain id:(NSString * _Nullable)id policy:(KMPWMExistingPolicy *)policy __attribute__((swift_name("enqueueChain(chain:id:policy:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("NativeTaskScheduler")))
@interface KMPWMNativeTaskScheduler : KMPWMBase <KMPWMBackgroundTaskScheduler>
- (instancetype)initWithAdditionalPermittedTaskIds:(NSSet<NSString *> *)additionalPermittedTaskIds __attribute__((swift_name("init(additionalPermittedTaskIds:)"))) __attribute__((objc_designated_initializer));
- (KMPWMTaskChain *)beginWithTask:(KMPWMTaskRequest *)task __attribute__((swift_name("beginWith(task:)")));
- (KMPWMTaskChain *)beginWithTasks:(NSArray<KMPWMTaskRequest *> *)tasks __attribute__((swift_name("beginWith(tasks:)")));
- (void)cancelId:(NSString *)id __attribute__((swift_name("cancel(id:)")));
- (void)cancelAll __attribute__((swift_name("cancelAll()")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)enqueueId:(NSString *)id trigger:(id<KMPWMTaskTrigger>)trigger workerClassName:(NSString *)workerClassName constraints:(KMPWMConstraints *)constraints inputJson:(NSString * _Nullable)inputJson policy:(KMPWMExistingPolicy *)policy completionHandler:(void (^)(KMPWMScheduleResult * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("enqueue(id:trigger:workerClassName:constraints:inputJson:policy:completionHandler:)")));
- (void)enqueueChainChain:(KMPWMTaskChain *)chain id:(NSString * _Nullable)id policy:(KMPWMExistingPolicy *)policy __attribute__((swift_name("enqueueChain(chain:id:policy:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SingleTaskExecutor")))
@interface KMPWMSingleTaskExecutor : KMPWMBase
- (instancetype)initWithWorkerFactory:(id<KMPWMIosWorkerFactory>)workerFactory __attribute__((swift_name("init(workerFactory:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMSingleTaskExecutorCompanion *companion __attribute__((swift_name("companion")));
- (void)cleanup __attribute__((swift_name("cleanup()")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)executeTaskWorkerClassName:(NSString *)workerClassName input:(NSString * _Nullable)input timeoutMs:(int64_t)timeoutMs completionHandler:(void (^)(KMPWMBoolean * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("executeTask(workerClassName:input:timeoutMs:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SingleTaskExecutor.Companion")))
@interface KMPWMSingleTaskExecutorCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMSingleTaskExecutorCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) int64_t DEFAULT_TIMEOUT_MS __attribute__((swift_name("DEFAULT_TIMEOUT_MS")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskIds")))
@interface KMPWMTaskIds : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)taskIds __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMTaskIds *shared __attribute__((swift_name("shared")));
@property (readonly) NSString *EXACT_REMINDER __attribute__((swift_name("EXACT_REMINDER")));
@property (readonly) NSString *HEAVY_TASK_1 __attribute__((swift_name("HEAVY_TASK_1")));
@property (readonly) NSString *ONE_TIME_UPLOAD __attribute__((swift_name("ONE_TIME_UPLOAD")));
@property (readonly) NSString *PERIODIC_SYNC_TASK __attribute__((swift_name("PERIODIC_SYNC_TASK")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("WorkerTypes")))
@interface KMPWMWorkerTypes : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)workerTypes __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMWorkerTypes *shared __attribute__((swift_name("shared")));
@property (readonly) NSString *HEAVY_PROCESSING_WORKER __attribute__((swift_name("HEAVY_PROCESSING_WORKER")));
@property (readonly) NSString *SYNC_WORKER __attribute__((swift_name("SYNC_WORKER")));
@property (readonly) NSString *UPLOAD_WORKER __attribute__((swift_name("UPLOAD_WORKER")));
@end

__attribute__((swift_name("KotlinComparable")))
@protocol KMPWMKotlinComparable
@required
- (int32_t)compareToOther:(id _Nullable)other __attribute__((swift_name("compareTo(other:)")));
@end

__attribute__((swift_name("KotlinEnum")))
@interface KMPWMKotlinEnum<E> : KMPWMBase <KMPWMKotlinComparable>
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMKotlinEnumCompanion *companion __attribute__((swift_name("companion")));
- (int32_t)compareToOther:(E)other __attribute__((swift_name("compareTo(other:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@property (readonly) int32_t ordinal __attribute__((swift_name("ordinal")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("BGTaskType")))
@interface KMPWMBGTaskType : KMPWMKotlinEnum<KMPWMBGTaskType *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) KMPWMBGTaskType *appRefresh __attribute__((swift_name("appRefresh")));
@property (class, readonly) KMPWMBGTaskType *processing __attribute__((swift_name("processing")));
+ (KMPWMKotlinArray<KMPWMBGTaskType *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<KMPWMBGTaskType *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("BackoffPolicy")))
@interface KMPWMBackoffPolicy : KMPWMKotlinEnum<KMPWMBackoffPolicy *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) KMPWMBackoffPolicy *linear __attribute__((swift_name("linear")));
@property (class, readonly) KMPWMBackoffPolicy *exponential __attribute__((swift_name("exponential")));
+ (KMPWMKotlinArray<KMPWMBackoffPolicy *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<KMPWMBackoffPolicy *> *entries __attribute__((swift_name("entries")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Constraints")))
@interface KMPWMConstraints : KMPWMBase
- (instancetype)initWithRequiresNetwork:(BOOL)requiresNetwork requiresUnmeteredNetwork:(BOOL)requiresUnmeteredNetwork requiresCharging:(BOOL)requiresCharging allowWhileIdle:(BOOL)allowWhileIdle qos:(KMPWMQos *)qos isHeavyTask:(BOOL)isHeavyTask backoffPolicy:(KMPWMBackoffPolicy *)backoffPolicy backoffDelayMs:(int64_t)backoffDelayMs systemConstraints:(NSSet<KMPWMSystemConstraint *> *)systemConstraints exactAlarmIOSBehavior:(KMPWMExactAlarmIOSBehavior *)exactAlarmIOSBehavior __attribute__((swift_name("init(requiresNetwork:requiresUnmeteredNetwork:requiresCharging:allowWhileIdle:qos:isHeavyTask:backoffPolicy:backoffDelayMs:systemConstraints:exactAlarmIOSBehavior:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMConstraintsCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMConstraints *)doCopyRequiresNetwork:(BOOL)requiresNetwork requiresUnmeteredNetwork:(BOOL)requiresUnmeteredNetwork requiresCharging:(BOOL)requiresCharging allowWhileIdle:(BOOL)allowWhileIdle qos:(KMPWMQos *)qos isHeavyTask:(BOOL)isHeavyTask backoffPolicy:(KMPWMBackoffPolicy *)backoffPolicy backoffDelayMs:(int64_t)backoffDelayMs systemConstraints:(NSSet<KMPWMSystemConstraint *> *)systemConstraints exactAlarmIOSBehavior:(KMPWMExactAlarmIOSBehavior *)exactAlarmIOSBehavior __attribute__((swift_name("doCopy(requiresNetwork:requiresUnmeteredNetwork:requiresCharging:allowWhileIdle:qos:isHeavyTask:backoffPolicy:backoffDelayMs:systemConstraints:exactAlarmIOSBehavior:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) BOOL allowWhileIdle __attribute__((swift_name("allowWhileIdle")));
@property (readonly) int64_t backoffDelayMs __attribute__((swift_name("backoffDelayMs")));
@property (readonly) KMPWMBackoffPolicy *backoffPolicy __attribute__((swift_name("backoffPolicy")));
@property (readonly) KMPWMExactAlarmIOSBehavior *exactAlarmIOSBehavior __attribute__((swift_name("exactAlarmIOSBehavior")));
@property (readonly) BOOL isHeavyTask __attribute__((swift_name("isHeavyTask")));
@property (readonly) KMPWMQos *qos __attribute__((swift_name("qos")));
@property (readonly) BOOL requiresCharging __attribute__((swift_name("requiresCharging")));
@property (readonly) BOOL requiresNetwork __attribute__((swift_name("requiresNetwork")));
@property (readonly) BOOL requiresUnmeteredNetwork __attribute__((swift_name("requiresUnmeteredNetwork")));
@property (readonly) NSSet<KMPWMSystemConstraint *> *systemConstraints __attribute__((swift_name("systemConstraints")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Constraints.Companion")))
@interface KMPWMConstraintsCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMConstraintsCompanion *shared __attribute__((swift_name("shared")));
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("EventSyncManager")))
@interface KMPWMEventSyncManager : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)eventSyncManager __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMEventSyncManager *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)clearOldEventsEventStore:(id<KMPWMEventStore>)eventStore olderThanMs:(int64_t)olderThanMs completionHandler:(void (^)(KMPWMInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("clearOldEvents(eventStore:olderThanMs:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)syncEventsEventStore:(id<KMPWMEventStore>)eventStore completionHandler:(void (^)(KMPWMInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("syncEvents(eventStore:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExactAlarmIOSBehavior")))
@interface KMPWMExactAlarmIOSBehavior : KMPWMKotlinEnum<KMPWMExactAlarmIOSBehavior *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) KMPWMExactAlarmIOSBehavior *showNotification __attribute__((swift_name("showNotification")));
@property (class, readonly) KMPWMExactAlarmIOSBehavior *attemptBackgroundRun __attribute__((swift_name("attemptBackgroundRun")));
@property (class, readonly) KMPWMExactAlarmIOSBehavior *throwError __attribute__((swift_name("throwError")));
+ (KMPWMKotlinArray<KMPWMExactAlarmIOSBehavior *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<KMPWMExactAlarmIOSBehavior *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExistingPolicy")))
@interface KMPWMExistingPolicy : KMPWMKotlinEnum<KMPWMExistingPolicy *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) KMPWMExistingPolicy *keep __attribute__((swift_name("keep")));
@property (class, readonly) KMPWMExistingPolicy *replace __attribute__((swift_name("replace")));
+ (KMPWMKotlinArray<KMPWMExistingPolicy *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<KMPWMExistingPolicy *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((swift_name("ProgressListener")))
@protocol KMPWMProgressListener
@required
- (void)onProgressUpdateProgress:(KMPWMWorkerProgress *)progress __attribute__((swift_name("onProgressUpdate(progress:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Qos")))
@interface KMPWMQos : KMPWMKotlinEnum<KMPWMQos *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) KMPWMQos *utility __attribute__((swift_name("utility")));
@property (class, readonly) KMPWMQos *background __attribute__((swift_name("background")));
@property (class, readonly) KMPWMQos *userinitiated __attribute__((swift_name("userinitiated")));
@property (class, readonly) KMPWMQos *userinteractive __attribute__((swift_name("userinteractive")));
+ (KMPWMKotlinArray<KMPWMQos *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<KMPWMQos *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ScheduleResult")))
@interface KMPWMScheduleResult : KMPWMKotlinEnum<KMPWMScheduleResult *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) KMPWMScheduleResult *accepted __attribute__((swift_name("accepted")));
@property (class, readonly) KMPWMScheduleResult *rejectedOsPolicy __attribute__((swift_name("rejectedOsPolicy")));
@property (class, readonly) KMPWMScheduleResult *throttled __attribute__((swift_name("throttled")));
+ (KMPWMKotlinArray<KMPWMScheduleResult *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<KMPWMScheduleResult *> *entries __attribute__((swift_name("entries")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SystemConstraint")))
@interface KMPWMSystemConstraint : KMPWMKotlinEnum<KMPWMSystemConstraint *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) KMPWMSystemConstraintCompanion *companion __attribute__((swift_name("companion")));
@property (class, readonly) KMPWMSystemConstraint *allowLowStorage __attribute__((swift_name("allowLowStorage")));
@property (class, readonly) KMPWMSystemConstraint *allowLowBattery __attribute__((swift_name("allowLowBattery")));
@property (class, readonly) KMPWMSystemConstraint *requireBatteryNotLow __attribute__((swift_name("requireBatteryNotLow")));
@property (class, readonly) KMPWMSystemConstraint *deviceIdle __attribute__((swift_name("deviceIdle")));
+ (KMPWMKotlinArray<KMPWMSystemConstraint *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<KMPWMSystemConstraint *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SystemConstraint.Companion")))
@interface KMPWMSystemConstraintCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMSystemConstraintCompanion *shared __attribute__((swift_name("shared")));
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializerTypeParamsSerializers:(KMPWMKotlinArray<id<KMPWMKotlinx_serialization_coreKSerializer>> *)typeParamsSerializers __attribute__((swift_name("serializer(typeParamsSerializers:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskChain")))
@interface KMPWMTaskChain : KMPWMBase
- (void)enqueue __attribute__((swift_name("enqueue()")));
- (KMPWMTaskChain *)thenTask:(KMPWMTaskRequest *)task __attribute__((swift_name("then(task:)")));
- (KMPWMTaskChain *)thenTasks:(NSArray<KMPWMTaskRequest *> *)tasks __attribute__((swift_name("then(tasks:)")));
- (KMPWMTaskChain *)withIdId:(NSString *)id policy:(KMPWMExistingPolicy *)policy __attribute__((swift_name("withId(id:policy:)")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskCompletionEvent")))
@interface KMPWMTaskCompletionEvent : KMPWMBase
- (instancetype)initWithTaskName:(NSString *)taskName success:(BOOL)success message:(NSString *)message __attribute__((swift_name("init(taskName:success:message:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMTaskCompletionEventCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMTaskCompletionEvent *)doCopyTaskName:(NSString *)taskName success:(BOOL)success message:(NSString *)message __attribute__((swift_name("doCopy(taskName:success:message:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *message __attribute__((swift_name("message")));
@property (readonly) BOOL success __attribute__((swift_name("success")));
@property (readonly) NSString *taskName __attribute__((swift_name("taskName")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskCompletionEvent.Companion")))
@interface KMPWMTaskCompletionEventCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMTaskCompletionEventCompanion *shared __attribute__((swift_name("shared")));
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskEventBus")))
@interface KMPWMTaskEventBus : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)taskEventBus __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMTaskEventBus *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)emitEvent:(KMPWMTaskCompletionEvent *)event completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("emit(event:completionHandler:)")));
@property (readonly) id<KMPWMKotlinx_coroutines_coreSharedFlow> events __attribute__((swift_name("events")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskEventManager")))
@interface KMPWMTaskEventManager : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)taskEventManager __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMTaskEventManager *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)emitEvent:(KMPWMTaskCompletionEvent *)event completionHandler:(void (^)(NSString * _Nullable_result, NSError * _Nullable))completionHandler __attribute__((swift_name("emit(event:completionHandler:)")));
- (void)initializeStore:(id<KMPWMEventStore>)store __attribute__((swift_name("initialize(store:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskProgressBus")))
@interface KMPWMTaskProgressBus : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)taskProgressBus __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMTaskProgressBus *shared __attribute__((swift_name("shared")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)emitEvent:(KMPWMTaskProgressEvent *)event completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("emit(event:completionHandler:)")));
@property (readonly) id<KMPWMKotlinx_coroutines_coreSharedFlow> events __attribute__((swift_name("events")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskProgressEvent")))
@interface KMPWMTaskProgressEvent : KMPWMBase
- (instancetype)initWithTaskId:(NSString *)taskId taskName:(NSString *)taskName progress:(KMPWMWorkerProgress *)progress __attribute__((swift_name("init(taskId:taskName:progress:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMTaskProgressEventCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMTaskProgressEvent *)doCopyTaskId:(NSString *)taskId taskName:(NSString *)taskName progress:(KMPWMWorkerProgress *)progress __attribute__((swift_name("doCopy(taskId:taskName:progress:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) KMPWMWorkerProgress *progress __attribute__((swift_name("progress")));
@property (readonly) NSString *taskId __attribute__((swift_name("taskId")));
@property (readonly) NSString *taskName __attribute__((swift_name("taskName")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskProgressEvent.Companion")))
@interface KMPWMTaskProgressEventCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMTaskProgressEventCompanion *shared __attribute__((swift_name("shared")));
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskRequest")))
@interface KMPWMTaskRequest : KMPWMBase
- (instancetype)initWithWorkerClassName:(NSString *)workerClassName inputJson:(NSString * _Nullable)inputJson constraints:(KMPWMConstraints * _Nullable)constraints __attribute__((swift_name("init(workerClassName:inputJson:constraints:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMTaskRequestCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMTaskRequest *)doCopyWorkerClassName:(NSString *)workerClassName inputJson:(NSString * _Nullable)inputJson constraints:(KMPWMConstraints * _Nullable)constraints __attribute__((swift_name("doCopy(workerClassName:inputJson:constraints:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) KMPWMConstraints * _Nullable constraints __attribute__((swift_name("constraints")));
@property (readonly) NSString * _Nullable inputJson __attribute__((swift_name("inputJson")));
@property (readonly) NSString *workerClassName __attribute__((swift_name("workerClassName")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskRequest.Companion")))
@interface KMPWMTaskRequestCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMTaskRequestCompanion *shared __attribute__((swift_name("shared")));
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskSpec")))
@interface KMPWMTaskSpec<T> : KMPWMBase
- (instancetype)initWithWorkerClassName:(NSString *)workerClassName constraints:(KMPWMConstraints *)constraints input:(T _Nullable)input __attribute__((swift_name("init(workerClassName:constraints:input:)"))) __attribute__((objc_designated_initializer));
- (KMPWMTaskSpec<T> *)doCopyWorkerClassName:(NSString *)workerClassName constraints:(KMPWMConstraints *)constraints input:(T _Nullable)input __attribute__((swift_name("doCopy(workerClassName:constraints:input:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) KMPWMConstraints *constraints __attribute__((swift_name("constraints")));
@property (readonly) T _Nullable input __attribute__((swift_name("input")));
@property (readonly) NSString *workerClassName __attribute__((swift_name("workerClassName")));
@end

__attribute__((swift_name("TaskTrigger")))
@protocol KMPWMTaskTrigger
@required
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskTriggerBatteryLow")))
@interface KMPWMTaskTriggerBatteryLow : KMPWMBase <KMPWMTaskTrigger>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)batteryLow __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMTaskTriggerBatteryLow *shared __attribute__((swift_name("shared")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskTriggerBatteryOkay")))
@interface KMPWMTaskTriggerBatteryOkay : KMPWMBase <KMPWMTaskTrigger>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)batteryOkay __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMTaskTriggerBatteryOkay *shared __attribute__((swift_name("shared")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskTriggerContentUri")))
@interface KMPWMTaskTriggerContentUri : KMPWMBase <KMPWMTaskTrigger>
- (instancetype)initWithUriString:(NSString *)uriString triggerForDescendants:(BOOL)triggerForDescendants __attribute__((swift_name("init(uriString:triggerForDescendants:)"))) __attribute__((objc_designated_initializer));
- (KMPWMTaskTriggerContentUri *)doCopyUriString:(NSString *)uriString triggerForDescendants:(BOOL)triggerForDescendants __attribute__((swift_name("doCopy(uriString:triggerForDescendants:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) BOOL triggerForDescendants __attribute__((swift_name("triggerForDescendants")));
@property (readonly) NSString *uriString __attribute__((swift_name("uriString")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskTriggerDeviceIdle")))
@interface KMPWMTaskTriggerDeviceIdle : KMPWMBase <KMPWMTaskTrigger>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)deviceIdle __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMTaskTriggerDeviceIdle *shared __attribute__((swift_name("shared")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskTriggerExact")))
@interface KMPWMTaskTriggerExact : KMPWMBase <KMPWMTaskTrigger>
- (instancetype)initWithAtEpochMillis:(int64_t)atEpochMillis __attribute__((swift_name("init(atEpochMillis:)"))) __attribute__((objc_designated_initializer));
- (KMPWMTaskTriggerExact *)doCopyAtEpochMillis:(int64_t)atEpochMillis __attribute__((swift_name("doCopy(atEpochMillis:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int64_t atEpochMillis __attribute__((swift_name("atEpochMillis")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskTriggerOneTime")))
@interface KMPWMTaskTriggerOneTime : KMPWMBase <KMPWMTaskTrigger>
- (instancetype)initWithInitialDelayMs:(int64_t)initialDelayMs __attribute__((swift_name("init(initialDelayMs:)"))) __attribute__((objc_designated_initializer));
- (KMPWMTaskTriggerOneTime *)doCopyInitialDelayMs:(int64_t)initialDelayMs __attribute__((swift_name("doCopy(initialDelayMs:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int64_t initialDelayMs __attribute__((swift_name("initialDelayMs")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskTriggerPeriodic")))
@interface KMPWMTaskTriggerPeriodic : KMPWMBase <KMPWMTaskTrigger>
- (instancetype)initWithIntervalMs:(int64_t)intervalMs flexMs:(KMPWMLong * _Nullable)flexMs __attribute__((swift_name("init(intervalMs:flexMs:)"))) __attribute__((objc_designated_initializer));
- (KMPWMTaskTriggerPeriodic *)doCopyIntervalMs:(int64_t)intervalMs flexMs:(KMPWMLong * _Nullable)flexMs __attribute__((swift_name("doCopy(intervalMs:flexMs:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) KMPWMLong * _Nullable flexMs __attribute__((swift_name("flexMs")));
@property (readonly) int64_t intervalMs __attribute__((swift_name("intervalMs")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskTriggerStorageLow")))
@interface KMPWMTaskTriggerStorageLow : KMPWMBase <KMPWMTaskTrigger>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)storageLow __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMTaskTriggerStorageLow *shared __attribute__((swift_name("shared")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskTriggerWindowed")))
@interface KMPWMTaskTriggerWindowed : KMPWMBase <KMPWMTaskTrigger>
- (instancetype)initWithEarliest:(int64_t)earliest latest:(int64_t)latest __attribute__((swift_name("init(earliest:latest:)"))) __attribute__((objc_designated_initializer));
- (KMPWMTaskTriggerWindowed *)doCopyEarliest:(int64_t)earliest latest:(int64_t)latest __attribute__((swift_name("doCopy(earliest:latest:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int64_t earliest __attribute__((swift_name("earliest")));
@property (readonly) int64_t latest __attribute__((swift_name("latest")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("WorkerProgress")))
@interface KMPWMWorkerProgress : KMPWMBase
- (instancetype)initWithProgress:(int32_t)progress message:(NSString * _Nullable)message currentStep:(KMPWMInt * _Nullable)currentStep totalSteps:(KMPWMInt * _Nullable)totalSteps __attribute__((swift_name("init(progress:message:currentStep:totalSteps:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMWorkerProgressCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMWorkerProgress *)doCopyProgress:(int32_t)progress message:(NSString * _Nullable)message currentStep:(KMPWMInt * _Nullable)currentStep totalSteps:(KMPWMInt * _Nullable)totalSteps __attribute__((swift_name("doCopy(progress:message:currentStep:totalSteps:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)toDisplayString __attribute__((swift_name("toDisplayString()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) KMPWMInt * _Nullable currentStep __attribute__((swift_name("currentStep")));
@property (readonly) NSString * _Nullable message __attribute__((swift_name("message")));
@property (readonly) int32_t progress __attribute__((swift_name("progress")));
@property (readonly) KMPWMInt * _Nullable totalSteps __attribute__((swift_name("totalSteps")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("WorkerProgress.Companion")))
@interface KMPWMWorkerProgressCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMWorkerProgressCompanion *shared __attribute__((swift_name("shared")));
- (KMPWMWorkerProgress *)forStepStep:(int32_t)step totalSteps:(int32_t)totalSteps message:(NSString * _Nullable)message __attribute__((swift_name("forStep(step:totalSteps:message:)")));
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end

__attribute__((swift_name("EventStore")))
@protocol KMPWMEventStore
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)clearAllWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("clearAll(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)clearOldEventsOlderThanMs:(int64_t)olderThanMs completionHandler:(void (^)(KMPWMInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("clearOldEvents(olderThanMs:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getEventCountWithCompletionHandler:(void (^)(KMPWMInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getEventCount(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getUnconsumedEventsWithCompletionHandler:(void (^)(NSArray<KMPWMStoredEvent *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getUnconsumedEvents(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)markEventConsumedEventId:(NSString *)eventId completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("markEventConsumed(eventId:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)saveEventEvent:(KMPWMTaskCompletionEvent *)event completionHandler:(void (^)(NSString * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("saveEvent(event:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("EventStoreConfig")))
@interface KMPWMEventStoreConfig : KMPWMBase
- (instancetype)initWithMaxEvents:(int32_t)maxEvents consumedEventRetentionMs:(int64_t)consumedEventRetentionMs unconsumedEventRetentionMs:(int64_t)unconsumedEventRetentionMs autoCleanup:(BOOL)autoCleanup __attribute__((swift_name("init(maxEvents:consumedEventRetentionMs:unconsumedEventRetentionMs:autoCleanup:)"))) __attribute__((objc_designated_initializer));
- (KMPWMEventStoreConfig *)doCopyMaxEvents:(int32_t)maxEvents consumedEventRetentionMs:(int64_t)consumedEventRetentionMs unconsumedEventRetentionMs:(int64_t)unconsumedEventRetentionMs autoCleanup:(BOOL)autoCleanup __attribute__((swift_name("doCopy(maxEvents:consumedEventRetentionMs:unconsumedEventRetentionMs:autoCleanup:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) BOOL autoCleanup __attribute__((swift_name("autoCleanup")));
@property (readonly) int64_t consumedEventRetentionMs __attribute__((swift_name("consumedEventRetentionMs")));
@property (readonly) int32_t maxEvents __attribute__((swift_name("maxEvents")));
@property (readonly) int64_t unconsumedEventRetentionMs __attribute__((swift_name("unconsumedEventRetentionMs")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("IosEventStore")))
@interface KMPWMIosEventStore : KMPWMBase <KMPWMEventStore>
- (instancetype)initWithConfig:(KMPWMEventStoreConfig *)config __attribute__((swift_name("init(config:)"))) __attribute__((objc_designated_initializer));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)clearAllWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("clearAll(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)clearOldEventsOlderThanMs:(int64_t)olderThanMs completionHandler:(void (^)(KMPWMInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("clearOldEvents(olderThanMs:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getEventCountWithCompletionHandler:(void (^)(KMPWMInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getEventCount(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getUnconsumedEventsWithCompletionHandler:(void (^)(NSArray<KMPWMStoredEvent *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getUnconsumedEvents(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)markEventConsumedEventId:(NSString *)eventId completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("markEventConsumed(eventId:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)saveEventEvent:(KMPWMTaskCompletionEvent *)event completionHandler:(void (^)(NSString * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("saveEvent(event:completionHandler:)")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("StoredEvent")))
@interface KMPWMStoredEvent : KMPWMBase
- (instancetype)initWithId:(NSString *)id event:(KMPWMTaskCompletionEvent *)event timestamp:(int64_t)timestamp consumed:(BOOL)consumed __attribute__((swift_name("init(id:event:timestamp:consumed:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMStoredEventCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMStoredEvent *)doCopyId:(NSString *)id event:(KMPWMTaskCompletionEvent *)event timestamp:(int64_t)timestamp consumed:(BOOL)consumed __attribute__((swift_name("doCopy(id:event:timestamp:consumed:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) BOOL consumed __attribute__((swift_name("consumed")));
@property (readonly) KMPWMTaskCompletionEvent *event __attribute__((swift_name("event")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) int64_t timestamp __attribute__((swift_name("timestamp")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("StoredEvent.Companion")))
@interface KMPWMStoredEventCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMStoredEventCompanion *shared __attribute__((swift_name("shared")));
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("CRC32")))
@interface KMPWMCRC32 : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)cRC32 __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMCRC32 *shared __attribute__((swift_name("shared")));
- (uint32_t)calculateData:(KMPWMKotlinByteArray *)data __attribute__((swift_name("calculate(data:)")));
- (uint32_t)calculateData_:(NSString *)data __attribute__((swift_name("calculate(data_:)")));
- (BOOL)verifyData:(KMPWMKotlinByteArray *)data expectedCrc:(uint32_t)expectedCrc __attribute__((swift_name("verify(data:expectedCrc:)")));
- (BOOL)verifyData:(NSString *)data expectedCrc_:(uint32_t)expectedCrc __attribute__((swift_name("verify(data:expectedCrc_:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("LogTags")))
@interface KMPWMLogTags : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)logTags __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMLogTags *shared __attribute__((swift_name("shared")));
@property (readonly) NSString *ALARM __attribute__((swift_name("ALARM")));
@property (readonly) NSString *CHAIN __attribute__((swift_name("CHAIN")));
@property (readonly) NSString *ERROR __attribute__((swift_name("ERROR")));
@property (readonly) NSString *PERMISSION __attribute__((swift_name("PERMISSION")));
@property (readonly) NSString *PUSH __attribute__((swift_name("PUSH")));
@property (readonly) NSString *QUEUE __attribute__((swift_name("QUEUE")));
@property (readonly) NSString *SCHEDULER __attribute__((swift_name("SCHEDULER")));
@property (readonly) NSString *TAG_DEBUG __attribute__((swift_name("TAG_DEBUG")));
@property (readonly) NSString *WORKER __attribute__((swift_name("WORKER")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Logger")))
@interface KMPWMLogger : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)logger __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMLogger *shared __attribute__((swift_name("shared")));
- (void)dTag:(NSString *)tag message:(NSString *)message throwable:(KMPWMKotlinThrowable * _Nullable)throwable __attribute__((swift_name("d(tag:message:throwable:)")));
- (void)eTag:(NSString *)tag message:(NSString *)message throwable:(KMPWMKotlinThrowable * _Nullable)throwable __attribute__((swift_name("e(tag:message:throwable:)")));
- (void)iTag:(NSString *)tag message:(NSString *)message throwable:(KMPWMKotlinThrowable * _Nullable)throwable __attribute__((swift_name("i(tag:message:throwable:)")));
- (void)vTag:(NSString *)tag message:(NSString *)message throwable:(KMPWMKotlinThrowable * _Nullable)throwable __attribute__((swift_name("v(tag:message:throwable:)")));
- (void)wTag:(NSString *)tag message:(NSString *)message throwable:(KMPWMKotlinThrowable * _Nullable)throwable __attribute__((swift_name("w(tag:message:throwable:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Logger.Level")))
@interface KMPWMLoggerLevel : KMPWMKotlinEnum<KMPWMLoggerLevel *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) KMPWMLoggerLevel *verbose __attribute__((swift_name("verbose")));
@property (class, readonly) KMPWMLoggerLevel *debugLevel __attribute__((swift_name("debugLevel")));
@property (class, readonly) KMPWMLoggerLevel *info __attribute__((swift_name("info")));
@property (class, readonly) KMPWMLoggerLevel *warn __attribute__((swift_name("warn")));
@property (class, readonly) KMPWMLoggerLevel *error __attribute__((swift_name("error")));
+ (KMPWMKotlinArray<KMPWMLoggerLevel *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<KMPWMLoggerLevel *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinByteArray")))
@interface KMPWMKotlinByteArray : KMPWMBase
+ (instancetype)arrayWithSize:(int32_t)size __attribute__((swift_name("init(size:)")));
+ (instancetype)arrayWithSize:(int32_t)size init:(KMPWMByte *(^)(KMPWMInt *))init __attribute__((swift_name("init(size:init:)")));
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (int8_t)getIndex:(int32_t)index __attribute__((swift_name("get(index:)")));
- (KMPWMKotlinByteIterator *)iterator __attribute__((swift_name("iterator()")));
- (void)setIndex:(int32_t)index value:(int8_t)value __attribute__((swift_name("set(index:value:)")));
@property (readonly) int32_t size __attribute__((swift_name("size")));
@end

@interface KMPWMKotlinByteArray (Extensions)
- (uint32_t)crc32 __attribute__((swift_name("crc32()")));
- (BOOL)verifyCrc32ExpectedCrc:(uint32_t)expectedCrc __attribute__((swift_name("verifyCrc32(expectedCrc:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("BackgroundTaskSchedulerExtKt")))
@interface KMPWMBackgroundTaskSchedulerExtKt : KMPWMBase
+ (KMPWMTaskChain *)beginWith:(id<KMPWMBackgroundTaskScheduler>)receiver tasks:(KMPWMKotlinArray<KMPWMTaskSpec<id> *> *)tasks __attribute__((swift_name("beginWith(_:tasks:)")));
+ (KMPWMTaskChain *)beginWith:(id<KMPWMBackgroundTaskScheduler>)receiver workerClassName:(NSString *)workerClassName constraints:(KMPWMConstraints *)constraints input:(id _Nullable)input __attribute__((swift_name("beginWith(_:workerClassName:constraints:input:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
+ (void)enqueue:(id<KMPWMBackgroundTaskScheduler>)receiver id:(NSString *)id trigger:(id<KMPWMTaskTrigger>)trigger workerClassName:(NSString *)workerClassName constraints:(KMPWMConstraints *)constraints input:(id _Nullable)input policy:(KMPWMExistingPolicy *)policy completionHandler:(void (^)(KMPWMScheduleResult * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("enqueue(_:id:trigger:workerClassName:constraints:input:policy:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("CRC32Kt")))
@interface KMPWMCRC32Kt : KMPWMBase
+ (uint32_t)crc32:(NSString *)receiver __attribute__((swift_name("crc32(_:)")));
+ (BOOL)verifyCrc32:(NSString *)receiver expectedCrc:(uint32_t)expectedCrc __attribute__((swift_name("verifyCrc32(_:expectedCrc:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ChainExecutorKt")))
@interface KMPWMChainExecutorKt : KMPWMBase
+ (id _Nullable)use:(id<KMPWMCloseable>)receiver block:(id _Nullable (^)(id<KMPWMCloseable>))block __attribute__((swift_name("use(_:block:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KoinModule_iosKt")))
@interface KMPWMKoinModule_iosKt : KMPWMBase
+ (KMPWMKoin_coreModule *)kmpWorkerModuleWorkerFactory:(id<KMPWMWorkerFactory>)workerFactory iosTaskIds:(NSSet<NSString *> *)iosTaskIds __attribute__((swift_name("kmpWorkerModule(workerFactory:iosTaskIds:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KoinModuleKt")))
@interface KMPWMKoinModuleKt : KMPWMBase
+ (KMPWMKoin_coreModule *)kmpWorkerCoreModuleScheduler:(id<KMPWMBackgroundTaskScheduler>)scheduler workerFactory:(id<KMPWMWorkerFactory>)workerFactory __attribute__((swift_name("kmpWorkerCoreModule(scheduler:workerFactory:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskTriggerHelperKt")))
@interface KMPWMTaskTriggerHelperKt : KMPWMBase
+ (KMPWMConstraints *)createConstraints __attribute__((swift_name("createConstraints()")));
+ (id<KMPWMTaskTrigger>)createTaskTriggerOneTimeInitialDelayMs:(int64_t)initialDelayMs __attribute__((swift_name("createTaskTriggerOneTime(initialDelayMs:)")));
@end

__attribute__((swift_name("KotlinRuntimeException")))
@interface KMPWMKotlinRuntimeException : KMPWMKotlinException
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(KMPWMKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(KMPWMKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));
@end

__attribute__((swift_name("KotlinIllegalStateException")))
@interface KMPWMKotlinIllegalStateException : KMPWMKotlinRuntimeException
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(KMPWMKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(KMPWMKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.4")
*/
__attribute__((swift_name("KotlinCancellationException")))
@interface KMPWMKotlinCancellationException : KMPWMKotlinIllegalStateException
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(KMPWMKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(KMPWMKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));
@end

__attribute__((swift_name("Kotlinx_serialization_coreSerializationStrategy")))
@protocol KMPWMKotlinx_serialization_coreSerializationStrategy
@required
- (void)serializeEncoder:(id<KMPWMKotlinx_serialization_coreEncoder>)encoder value:(id _Nullable)value __attribute__((swift_name("serialize(encoder:value:)")));
@property (readonly) id<KMPWMKotlinx_serialization_coreSerialDescriptor> descriptor __attribute__((swift_name("descriptor")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreDeserializationStrategy")))
@protocol KMPWMKotlinx_serialization_coreDeserializationStrategy
@required
- (id _Nullable)deserializeDecoder:(id<KMPWMKotlinx_serialization_coreDecoder>)decoder __attribute__((swift_name("deserialize(decoder:)")));
@property (readonly) id<KMPWMKotlinx_serialization_coreSerialDescriptor> descriptor __attribute__((swift_name("descriptor")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreKSerializer")))
@protocol KMPWMKotlinx_serialization_coreKSerializer <KMPWMKotlinx_serialization_coreSerializationStrategy, KMPWMKotlinx_serialization_coreDeserializationStrategy>
@required
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinArray")))
@interface KMPWMKotlinArray<T> : KMPWMBase
+ (instancetype)arrayWithSize:(int32_t)size init:(T _Nullable (^)(KMPWMInt *))init __attribute__((swift_name("init(size:init:)")));
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (T _Nullable)getIndex:(int32_t)index __attribute__((swift_name("get(index:)")));
- (id<KMPWMKotlinIterator>)iterator __attribute__((swift_name("iterator()")));
- (void)setIndex:(int32_t)index value:(T _Nullable)value __attribute__((swift_name("set(index:value:)")));
@property (readonly) int32_t size __attribute__((swift_name("size")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinEnumCompanion")))
@interface KMPWMKotlinEnumCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKotlinEnumCompanion *shared __attribute__((swift_name("shared")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreFlow")))
@protocol KMPWMKotlinx_coroutines_coreFlow
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)collectCollector:(id<KMPWMKotlinx_coroutines_coreFlowCollector>)collector completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("collect(collector:completionHandler:)")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreSharedFlow")))
@protocol KMPWMKotlinx_coroutines_coreSharedFlow <KMPWMKotlinx_coroutines_coreFlow>
@required
@property (readonly) NSArray<id> *replayCache __attribute__((swift_name("replayCache")));
@end

__attribute__((swift_name("KotlinIterator")))
@protocol KMPWMKotlinIterator
@required
- (BOOL)hasNext __attribute__((swift_name("hasNext()")));
- (id _Nullable)next __attribute__((swift_name("next()")));
@end

__attribute__((swift_name("KotlinByteIterator")))
@interface KMPWMKotlinByteIterator : KMPWMBase <KMPWMKotlinIterator>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (KMPWMByte *)next __attribute__((swift_name("next()")));
- (int8_t)nextByte __attribute__((swift_name("nextByte()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Koin_coreModule")))
@interface KMPWMKoin_coreModule : KMPWMBase
- (instancetype)initWith_createdAtStart:(BOOL)_createdAtStart __attribute__((swift_name("init(_createdAtStart:)"))) __attribute__((objc_designated_initializer));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (KMPWMKoin_coreKoinDefinition<id> *)factoryQualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier definition:(id _Nullable (^)(KMPWMKoin_coreScope *, KMPWMKoin_coreParametersHolder *))definition __attribute__((swift_name("factory(qualifier:definition:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (void)includesModule:(KMPWMKotlinArray<KMPWMKoin_coreModule *> *)module __attribute__((swift_name("includes(module:)")));
- (void)includesModule_:(id)module __attribute__((swift_name("includes(module_:)")));
- (void)indexPrimaryTypeInstanceFactory:(KMPWMKoin_coreInstanceFactory<id> *)instanceFactory __attribute__((swift_name("indexPrimaryType(instanceFactory:)")));
- (void)indexSecondaryTypesInstanceFactory:(KMPWMKoin_coreInstanceFactory<id> *)instanceFactory __attribute__((swift_name("indexSecondaryTypes(instanceFactory:)")));
- (NSArray<KMPWMKoin_coreModule *> *)plusModules:(NSArray<KMPWMKoin_coreModule *> *)modules __attribute__((swift_name("plus(modules:)")));
- (NSArray<KMPWMKoin_coreModule *> *)plusModule:(KMPWMKoin_coreModule *)module __attribute__((swift_name("plus(module:)")));
- (void)prepareForCreationAtStartInstanceFactory:(KMPWMKoin_coreSingleInstanceFactory<id> *)instanceFactory __attribute__((swift_name("prepareForCreationAtStart(instanceFactory:)")));
- (void)scopeScopeSet:(void (^)(KMPWMKoin_coreScopeDSL *))scopeSet __attribute__((swift_name("scope(scopeSet:)")));
- (void)scopeQualifier:(id<KMPWMKoin_coreQualifier>)qualifier scopeSet:(void (^)(KMPWMKoin_coreScopeDSL *))scopeSet __attribute__((swift_name("scope(qualifier:scopeSet:)")));
- (KMPWMKoin_coreKoinDefinition<id> *)singleQualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier createdAtStart:(BOOL)createdAtStart definition:(id _Nullable (^)(KMPWMKoin_coreScope *, KMPWMKoin_coreParametersHolder *))definition __attribute__((swift_name("single(qualifier:createdAtStart:definition:)")));
@property (readonly) KMPWMMutableSet<KMPWMKoin_coreSingleInstanceFactory<id> *> *eagerInstances __attribute__((swift_name("eagerInstances")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) NSMutableArray<KMPWMKoin_coreModule *> *includedModules __attribute__((swift_name("includedModules")));
@property (readonly) BOOL isLoaded __attribute__((swift_name("isLoaded")));
@property (readonly) KMPWMMutableDictionary<NSString *, KMPWMKoin_coreInstanceFactory<id> *> *mappings __attribute__((swift_name("mappings")));
@property (readonly) KMPWMMutableSet<id<KMPWMKoin_coreQualifier>> *scopes __attribute__((swift_name("scopes")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreEncoder")))
@protocol KMPWMKotlinx_serialization_coreEncoder
@required
- (id<KMPWMKotlinx_serialization_coreCompositeEncoder>)beginCollectionDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor collectionSize:(int32_t)collectionSize __attribute__((swift_name("beginCollection(descriptor:collectionSize:)")));
- (id<KMPWMKotlinx_serialization_coreCompositeEncoder>)beginStructureDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("beginStructure(descriptor:)")));
- (void)encodeBooleanValue:(BOOL)value __attribute__((swift_name("encodeBoolean(value:)")));
- (void)encodeByteValue:(int8_t)value __attribute__((swift_name("encodeByte(value:)")));
- (void)encodeCharValue:(unichar)value __attribute__((swift_name("encodeChar(value:)")));
- (void)encodeDoubleValue:(double)value __attribute__((swift_name("encodeDouble(value:)")));
- (void)encodeEnumEnumDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)enumDescriptor index:(int32_t)index __attribute__((swift_name("encodeEnum(enumDescriptor:index:)")));
- (void)encodeFloatValue:(float)value __attribute__((swift_name("encodeFloat(value:)")));
- (id<KMPWMKotlinx_serialization_coreEncoder>)encodeInlineDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("encodeInline(descriptor:)")));
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
- (void)encodeNullableSerializableValueSerializer:(id<KMPWMKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeNullableSerializableValue(serializer:value:)")));
- (void)encodeSerializableValueSerializer:(id<KMPWMKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeSerializableValue(serializer:value:)")));
- (void)encodeShortValue:(int16_t)value __attribute__((swift_name("encodeShort(value:)")));
- (void)encodeStringValue:(NSString *)value __attribute__((swift_name("encodeString(value:)")));
@property (readonly) KMPWMKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreSerialDescriptor")))
@protocol KMPWMKotlinx_serialization_coreSerialDescriptor
@required
- (NSArray<id<KMPWMKotlinAnnotation>> *)getElementAnnotationsIndex:(int32_t)index __attribute__((swift_name("getElementAnnotations(index:)")));
- (id<KMPWMKotlinx_serialization_coreSerialDescriptor>)getElementDescriptorIndex:(int32_t)index __attribute__((swift_name("getElementDescriptor(index:)")));
- (int32_t)getElementIndexName:(NSString *)name __attribute__((swift_name("getElementIndex(name:)")));
- (NSString *)getElementNameIndex:(int32_t)index __attribute__((swift_name("getElementName(index:)")));
- (BOOL)isElementOptionalIndex:(int32_t)index __attribute__((swift_name("isElementOptional(index:)")));
@property (readonly) NSArray<id<KMPWMKotlinAnnotation>> *annotations __attribute__((swift_name("annotations")));
@property (readonly) int32_t elementsCount __attribute__((swift_name("elementsCount")));
@property (readonly) BOOL isInline __attribute__((swift_name("isInline")));
@property (readonly) BOOL isNullable __attribute__((swift_name("isNullable")));
@property (readonly) KMPWMKotlinx_serialization_coreSerialKind *kind __attribute__((swift_name("kind")));
@property (readonly) NSString *serialName __attribute__((swift_name("serialName")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreDecoder")))
@protocol KMPWMKotlinx_serialization_coreDecoder
@required
- (id<KMPWMKotlinx_serialization_coreCompositeDecoder>)beginStructureDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("beginStructure(descriptor:)")));
- (BOOL)decodeBoolean __attribute__((swift_name("decodeBoolean()")));
- (int8_t)decodeByte __attribute__((swift_name("decodeByte()")));
- (unichar)decodeChar __attribute__((swift_name("decodeChar()")));
- (double)decodeDouble __attribute__((swift_name("decodeDouble()")));
- (int32_t)decodeEnumEnumDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)enumDescriptor __attribute__((swift_name("decodeEnum(enumDescriptor:)")));
- (float)decodeFloat __attribute__((swift_name("decodeFloat()")));
- (id<KMPWMKotlinx_serialization_coreDecoder>)decodeInlineDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("decodeInline(descriptor:)")));
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
- (KMPWMKotlinNothing * _Nullable)decodeNull __attribute__((swift_name("decodeNull()")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id _Nullable)decodeNullableSerializableValueDeserializer:(id<KMPWMKotlinx_serialization_coreDeserializationStrategy>)deserializer __attribute__((swift_name("decodeNullableSerializableValue(deserializer:)")));
- (id _Nullable)decodeSerializableValueDeserializer:(id<KMPWMKotlinx_serialization_coreDeserializationStrategy>)deserializer __attribute__((swift_name("decodeSerializableValue(deserializer:)")));
- (int16_t)decodeShort __attribute__((swift_name("decodeShort()")));
- (NSString *)decodeString __attribute__((swift_name("decodeString()")));
@property (readonly) KMPWMKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreFlowCollector")))
@protocol KMPWMKotlinx_coroutines_coreFlowCollector
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)emitValue:(id _Nullable)value completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("emit(value:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Koin_coreKoinDefinition")))
@interface KMPWMKoin_coreKoinDefinition<R> : KMPWMBase
- (instancetype)initWithModule:(KMPWMKoin_coreModule *)module factory:(KMPWMKoin_coreInstanceFactory<R> *)factory __attribute__((swift_name("init(module:factory:)"))) __attribute__((objc_designated_initializer));
- (KMPWMKoin_coreKoinDefinition<R> *)doCopyModule:(KMPWMKoin_coreModule *)module factory:(KMPWMKoin_coreInstanceFactory<R> *)factory __attribute__((swift_name("doCopy(module:factory:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) KMPWMKoin_coreInstanceFactory<R> *factory __attribute__((swift_name("factory")));
@property (readonly) KMPWMKoin_coreModule *module __attribute__((swift_name("module")));
@end

__attribute__((swift_name("Koin_coreQualifier")))
@protocol KMPWMKoin_coreQualifier
@required
@property (readonly) NSString *value __attribute__((swift_name("value")));
@end

__attribute__((swift_name("Koin_coreLockable")))
@interface KMPWMKoin_coreLockable : KMPWMBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Koin_coreScope")))
@interface KMPWMKoin_coreScope : KMPWMKoin_coreLockable
- (instancetype)initWithScopeQualifier:(id<KMPWMKoin_coreQualifier>)scopeQualifier id:(NSString *)id isRoot:(BOOL)isRoot scopeArchetype:(KMPWMKoin_coreTypeQualifier * _Nullable)scopeArchetype _koin:(KMPWMKoin_coreKoin *)_koin __attribute__((swift_name("init(scopeQualifier:id:isRoot:scopeArchetype:_koin:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
- (void)close __attribute__((swift_name("close()")));
- (void)declareInstance:(id _Nullable)instance qualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier secondaryTypes:(NSArray<id<KMPWMKotlinKClass>> *)secondaryTypes allowOverride:(BOOL)allowOverride holdInstance:(BOOL)holdInstance __attribute__((swift_name("declare(instance:qualifier:secondaryTypes:allowOverride:holdInstance:)")));
- (id)getQualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier parameters:(KMPWMKoin_coreParametersHolder *(^ _Nullable)(void))parameters __attribute__((swift_name("get(qualifier:parameters:)")));
- (id _Nullable)getClazz:(id<KMPWMKotlinKClass>)clazz qualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier parameters:(KMPWMKoin_coreParametersHolder *(^ _Nullable)(void))parameters __attribute__((swift_name("get(clazz:qualifier:parameters:)")));
- (NSArray<id> *)getAll __attribute__((swift_name("getAll()")));
- (NSArray<id> *)getAllClazz:(id<KMPWMKotlinKClass>)clazz __attribute__((swift_name("getAll(clazz:)")));
- (KMPWMKoin_coreKoin *)getKoin __attribute__((swift_name("getKoin()")));
- (NSArray<NSString *> *)getLinkedScopeIds __attribute__((swift_name("getLinkedScopeIds()")));
- (id _Nullable)getOrNullQualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier parameters:(KMPWMKoin_coreParametersHolder *(^ _Nullable)(void))parameters __attribute__((swift_name("getOrNull(qualifier:parameters:)")));
- (id _Nullable)getOrNullClazz:(id<KMPWMKotlinKClass>)clazz qualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier parameters:(KMPWMKoin_coreParametersHolder *(^ _Nullable)(void))parameters __attribute__((swift_name("getOrNull(clazz:qualifier:parameters:)")));
- (id)getPropertyKey:(NSString *)key __attribute__((swift_name("getProperty(key:)")));
- (id)getPropertyKey:(NSString *)key defaultValue:(id)defaultValue __attribute__((swift_name("getProperty(key:defaultValue:)")));
- (id _Nullable)getPropertyOrNullKey:(NSString *)key __attribute__((swift_name("getPropertyOrNull(key:)")));
- (KMPWMKoin_coreScope *)getScopeScopeID:(NSString *)scopeID __attribute__((swift_name("getScope(scopeID:)")));
- (id _Nullable)getSource __attribute__((swift_name("getSource()")));
- (id _Nullable)getWithParametersClazz:(id<KMPWMKotlinKClass>)clazz qualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier parameters:(KMPWMKoin_coreParametersHolder * _Nullable)parameters __attribute__((swift_name("getWithParameters(clazz:qualifier:parameters:)")));
- (id<KMPWMKotlinLazy>)injectQualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier mode:(KMPWMKotlinLazyThreadSafetyMode *)mode parameters:(KMPWMKoin_coreParametersHolder *(^ _Nullable)(void))parameters __attribute__((swift_name("inject(qualifier:mode:parameters:)")));
- (id<KMPWMKotlinLazy>)injectOrNullQualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier mode:(KMPWMKotlinLazyThreadSafetyMode *)mode parameters:(KMPWMKoin_coreParametersHolder *(^ _Nullable)(void))parameters __attribute__((swift_name("injectOrNull(qualifier:mode:parameters:)")));
- (BOOL)isNotClosed __attribute__((swift_name("isNotClosed()")));
- (void)linkToScopes:(KMPWMKotlinArray<KMPWMKoin_coreScope *> *)scopes __attribute__((swift_name("linkTo(scopes:)")));
- (void)registerCallbackCallback:(id<KMPWMKoin_coreScopeCallback>)callback __attribute__((swift_name("registerCallback(callback:)")));
- (NSString *)description __attribute__((swift_name("description()")));
- (void)unlinkScopes:(KMPWMKotlinArray<KMPWMKoin_coreScope *> *)scopes __attribute__((swift_name("unlink(scopes:)")));
@property (readonly) BOOL closed __attribute__((swift_name("closed")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) BOOL isRoot __attribute__((swift_name("isRoot")));
@property (readonly) KMPWMKoin_coreLogger *logger __attribute__((swift_name("logger")));
@property (readonly) KMPWMKoin_coreTypeQualifier * _Nullable scopeArchetype __attribute__((swift_name("scopeArchetype")));
@property (readonly) id<KMPWMKoin_coreQualifier> scopeQualifier __attribute__((swift_name("scopeQualifier")));
@property id _Nullable sourceValue __attribute__((swift_name("sourceValue")));
@end

__attribute__((swift_name("Koin_coreParametersHolder")))
@interface KMPWMKoin_coreParametersHolder : KMPWMBase
- (instancetype)initWith_values:(NSMutableArray<id> *)_values useIndexedValues:(KMPWMBoolean * _Nullable)useIndexedValues __attribute__((swift_name("init(_values:useIndexedValues:)"))) __attribute__((objc_designated_initializer));
- (KMPWMKoin_coreParametersHolder *)addValue:(id)value __attribute__((swift_name("add(value:)")));
- (id _Nullable)component1 __attribute__((swift_name("component1()")));
- (id _Nullable)component2 __attribute__((swift_name("component2()")));
- (id _Nullable)component3 __attribute__((swift_name("component3()")));
- (id _Nullable)component4 __attribute__((swift_name("component4()")));
- (id _Nullable)component5 __attribute__((swift_name("component5()")));
- (id _Nullable)elementAtI:(int32_t)i clazz:(id<KMPWMKotlinKClass>)clazz __attribute__((swift_name("elementAt(i:clazz:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (id)get __attribute__((swift_name("get()")));
- (id _Nullable)getI:(int32_t)i __attribute__((swift_name("get(i:)")));
- (id _Nullable)getOrNull __attribute__((swift_name("getOrNull()")));
- (id _Nullable)getOrNullClazz:(id<KMPWMKotlinKClass>)clazz __attribute__((swift_name("getOrNull(clazz:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (KMPWMKoin_coreParametersHolder *)insertIndex:(int32_t)index value:(id)value __attribute__((swift_name("insert(index:value:)")));
- (BOOL)isEmpty __attribute__((swift_name("isEmpty()")));
- (BOOL)isNotEmpty __attribute__((swift_name("isNotEmpty()")));
- (void)setI:(int32_t)i t:(id _Nullable)t __attribute__((swift_name("set(i:t:)")));
- (int32_t)size __attribute__((swift_name("size()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property int32_t index __attribute__((swift_name("index")));
@property (readonly) KMPWMBoolean * _Nullable useIndexedValues __attribute__((swift_name("useIndexedValues")));
@property (readonly) NSArray<id> *values __attribute__((swift_name("values")));
@end

__attribute__((swift_name("Koin_coreInstanceFactory")))
@interface KMPWMKoin_coreInstanceFactory<T> : KMPWMKoin_coreLockable
- (instancetype)initWithBeanDefinition:(KMPWMKoin_coreBeanDefinition<T> *)beanDefinition __attribute__((swift_name("init(beanDefinition:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
@property (class, readonly, getter=companion) KMPWMKoin_coreInstanceFactoryCompanion *companion __attribute__((swift_name("companion")));
- (T _Nullable)createContext:(KMPWMKoin_coreResolutionContext *)context __attribute__((swift_name("create(context:)")));
- (void)dropScope:(KMPWMKoin_coreScope * _Nullable)scope __attribute__((swift_name("drop(scope:)")));
- (void)dropAll __attribute__((swift_name("dropAll()")));
- (T _Nullable)getContext:(KMPWMKoin_coreResolutionContext *)context __attribute__((swift_name("get(context:)")));
- (BOOL)isCreatedContext:(KMPWMKoin_coreResolutionContext * _Nullable)context __attribute__((swift_name("isCreated(context:)")));
@property (readonly) KMPWMKoin_coreBeanDefinition<T> *beanDefinition __attribute__((swift_name("beanDefinition")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Koin_coreSingleInstanceFactory")))
@interface KMPWMKoin_coreSingleInstanceFactory<T> : KMPWMKoin_coreInstanceFactory<T>
- (instancetype)initWithBeanDefinition:(KMPWMKoin_coreBeanDefinition<T> *)beanDefinition __attribute__((swift_name("init(beanDefinition:)"))) __attribute__((objc_designated_initializer));
- (T _Nullable)createContext:(KMPWMKoin_coreResolutionContext *)context __attribute__((swift_name("create(context:)")));
- (void)dropScope:(KMPWMKoin_coreScope * _Nullable)scope __attribute__((swift_name("drop(scope:)")));
- (void)dropAll __attribute__((swift_name("dropAll()")));
- (T _Nullable)getContext:(KMPWMKoin_coreResolutionContext *)context __attribute__((swift_name("get(context:)")));
- (BOOL)isCreatedContext:(KMPWMKoin_coreResolutionContext * _Nullable)context __attribute__((swift_name("isCreated(context:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Koin_coreScopeDSL")))
@interface KMPWMKoin_coreScopeDSL : KMPWMBase
- (instancetype)initWithScopeQualifier:(id<KMPWMKoin_coreQualifier>)scopeQualifier module:(KMPWMKoin_coreModule *)module __attribute__((swift_name("init(scopeQualifier:module:)"))) __attribute__((objc_designated_initializer));
- (KMPWMKoin_coreKoinDefinition<id> *)factoryQualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier definition:(id _Nullable (^)(KMPWMKoin_coreScope *, KMPWMKoin_coreParametersHolder *))definition __attribute__((swift_name("factory(qualifier:definition:)")));
- (KMPWMKoin_coreKoinDefinition<id> *)scopedQualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier definition:(id _Nullable (^)(KMPWMKoin_coreScope *, KMPWMKoin_coreParametersHolder *))definition __attribute__((swift_name("scoped(qualifier:definition:)")));
@property (readonly) KMPWMKoin_coreModule *module __attribute__((swift_name("module")));
@property (readonly) id<KMPWMKoin_coreQualifier> scopeQualifier __attribute__((swift_name("scopeQualifier")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreCompositeEncoder")))
@protocol KMPWMKotlinx_serialization_coreCompositeEncoder
@required
- (void)encodeBooleanElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(BOOL)value __attribute__((swift_name("encodeBooleanElement(descriptor:index:value:)")));
- (void)encodeByteElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(int8_t)value __attribute__((swift_name("encodeByteElement(descriptor:index:value:)")));
- (void)encodeCharElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(unichar)value __attribute__((swift_name("encodeCharElement(descriptor:index:value:)")));
- (void)encodeDoubleElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(double)value __attribute__((swift_name("encodeDoubleElement(descriptor:index:value:)")));
- (void)encodeFloatElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(float)value __attribute__((swift_name("encodeFloatElement(descriptor:index:value:)")));
- (id<KMPWMKotlinx_serialization_coreEncoder>)encodeInlineElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("encodeInlineElement(descriptor:index:)")));
- (void)encodeIntElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(int32_t)value __attribute__((swift_name("encodeIntElement(descriptor:index:value:)")));
- (void)encodeLongElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(int64_t)value __attribute__((swift_name("encodeLongElement(descriptor:index:value:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (void)encodeNullableSerializableElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index serializer:(id<KMPWMKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeNullableSerializableElement(descriptor:index:serializer:value:)")));
- (void)encodeSerializableElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index serializer:(id<KMPWMKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeSerializableElement(descriptor:index:serializer:value:)")));
- (void)encodeShortElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(int16_t)value __attribute__((swift_name("encodeShortElement(descriptor:index:value:)")));
- (void)encodeStringElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(NSString *)value __attribute__((swift_name("encodeStringElement(descriptor:index:value:)")));
- (void)endStructureDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("endStructure(descriptor:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (BOOL)shouldEncodeElementDefaultDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("shouldEncodeElementDefault(descriptor:index:)")));
@property (readonly) KMPWMKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreSerializersModule")))
@interface KMPWMKotlinx_serialization_coreSerializersModule : KMPWMBase

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (void)dumpToCollector:(id<KMPWMKotlinx_serialization_coreSerializersModuleCollector>)collector __attribute__((swift_name("dumpTo(collector:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id<KMPWMKotlinx_serialization_coreKSerializer> _Nullable)getContextualKClass:(id<KMPWMKotlinKClass>)kClass typeArgumentsSerializers:(NSArray<id<KMPWMKotlinx_serialization_coreKSerializer>> *)typeArgumentsSerializers __attribute__((swift_name("getContextual(kClass:typeArgumentsSerializers:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id<KMPWMKotlinx_serialization_coreSerializationStrategy> _Nullable)getPolymorphicBaseClass:(id<KMPWMKotlinKClass>)baseClass value:(id)value __attribute__((swift_name("getPolymorphic(baseClass:value:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id<KMPWMKotlinx_serialization_coreDeserializationStrategy> _Nullable)getPolymorphicBaseClass:(id<KMPWMKotlinKClass>)baseClass serializedClassName:(NSString * _Nullable)serializedClassName __attribute__((swift_name("getPolymorphic(baseClass:serializedClassName:)")));
@end

__attribute__((swift_name("KotlinAnnotation")))
@protocol KMPWMKotlinAnnotation
@required
@end

__attribute__((swift_name("Kotlinx_serialization_coreSerialKind")))
@interface KMPWMKotlinx_serialization_coreSerialKind : KMPWMBase
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((swift_name("Kotlinx_serialization_coreCompositeDecoder")))
@protocol KMPWMKotlinx_serialization_coreCompositeDecoder
@required
- (BOOL)decodeBooleanElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeBooleanElement(descriptor:index:)")));
- (int8_t)decodeByteElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeByteElement(descriptor:index:)")));
- (unichar)decodeCharElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeCharElement(descriptor:index:)")));
- (int32_t)decodeCollectionSizeDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("decodeCollectionSize(descriptor:)")));
- (double)decodeDoubleElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeDoubleElement(descriptor:index:)")));
- (int32_t)decodeElementIndexDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("decodeElementIndex(descriptor:)")));
- (float)decodeFloatElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeFloatElement(descriptor:index:)")));
- (id<KMPWMKotlinx_serialization_coreDecoder>)decodeInlineElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeInlineElement(descriptor:index:)")));
- (int32_t)decodeIntElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeIntElement(descriptor:index:)")));
- (int64_t)decodeLongElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeLongElement(descriptor:index:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id _Nullable)decodeNullableSerializableElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index deserializer:(id<KMPWMKotlinx_serialization_coreDeserializationStrategy>)deserializer previousValue:(id _Nullable)previousValue __attribute__((swift_name("decodeNullableSerializableElement(descriptor:index:deserializer:previousValue:)")));

/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (BOOL)decodeSequentially __attribute__((swift_name("decodeSequentially()")));
- (id _Nullable)decodeSerializableElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index deserializer:(id<KMPWMKotlinx_serialization_coreDeserializationStrategy>)deserializer previousValue:(id _Nullable)previousValue __attribute__((swift_name("decodeSerializableElement(descriptor:index:deserializer:previousValue:)")));
- (int16_t)decodeShortElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeShortElement(descriptor:index:)")));
- (NSString *)decodeStringElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeStringElement(descriptor:index:)")));
- (void)endStructureDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("endStructure(descriptor:)")));
@property (readonly) KMPWMKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinNothing")))
@interface KMPWMKotlinNothing : KMPWMBase
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Koin_coreTypeQualifier")))
@interface KMPWMKoin_coreTypeQualifier : KMPWMBase <KMPWMKoin_coreQualifier>
- (instancetype)initWithType:(id<KMPWMKotlinKClass>)type __attribute__((swift_name("init(type:)"))) __attribute__((objc_designated_initializer));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) id<KMPWMKotlinKClass> type __attribute__((swift_name("type")));
@property (readonly) NSString *value __attribute__((swift_name("value")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Koin_coreKoin")))
@interface KMPWMKoin_coreKoin : KMPWMBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (void)close __attribute__((swift_name("close()")));
- (void)createEagerInstances __attribute__((swift_name("createEagerInstances()")));
- (KMPWMKoin_coreScope *)createScopeT:(id<KMPWMKoin_coreKoinScopeComponent>)t __attribute__((swift_name("createScope(t:)")));
- (KMPWMKoin_coreScope *)createScopeScopeId:(NSString *)scopeId __attribute__((swift_name("createScope(scopeId:)")));
- (KMPWMKoin_coreScope *)createScopeScopeId:(NSString *)scopeId source:(id _Nullable)source scopeArchetype:(KMPWMKoin_coreTypeQualifier * _Nullable)scopeArchetype __attribute__((swift_name("createScope(scopeId:source:scopeArchetype:)")));
- (KMPWMKoin_coreScope *)createScopeScopeId:(NSString *)scopeId qualifier:(id<KMPWMKoin_coreQualifier>)qualifier source:(id _Nullable)source scopeArchetype:(KMPWMKoin_coreTypeQualifier * _Nullable)scopeArchetype __attribute__((swift_name("createScope(scopeId:qualifier:source:scopeArchetype:)")));
- (void)declareInstance:(id _Nullable)instance qualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier secondaryTypes:(NSArray<id<KMPWMKotlinKClass>> *)secondaryTypes allowOverride:(BOOL)allowOverride __attribute__((swift_name("declare(instance:qualifier:secondaryTypes:allowOverride:)")));
- (void)deletePropertyKey:(NSString *)key __attribute__((swift_name("deleteProperty(key:)")));
- (void)deleteScopeScopeId:(NSString *)scopeId __attribute__((swift_name("deleteScope(scopeId:)")));
- (id)getQualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier parameters:(KMPWMKoin_coreParametersHolder *(^ _Nullable)(void))parameters __attribute__((swift_name("get(qualifier:parameters:)")));
- (id _Nullable)getClazz:(id<KMPWMKotlinKClass>)clazz qualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier parameters:(KMPWMKoin_coreParametersHolder *(^ _Nullable)(void))parameters __attribute__((swift_name("get(clazz:qualifier:parameters:)")));
- (NSArray<id> *)getAll __attribute__((swift_name("getAll()")));
- (KMPWMKoin_coreScope *)getOrCreateScopeScopeId:(NSString *)scopeId __attribute__((swift_name("getOrCreateScope(scopeId:)")));
- (KMPWMKoin_coreScope *)getOrCreateScopeScopeId:(NSString *)scopeId qualifier:(id<KMPWMKoin_coreQualifier>)qualifier source:(id _Nullable)source __attribute__((swift_name("getOrCreateScope(scopeId:qualifier:source:)")));
- (id _Nullable)getOrNullQualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier parameters:(KMPWMKoin_coreParametersHolder *(^ _Nullable)(void))parameters __attribute__((swift_name("getOrNull(qualifier:parameters:)")));
- (id _Nullable)getOrNullClazz:(id<KMPWMKotlinKClass>)clazz qualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier parameters:(KMPWMKoin_coreParametersHolder *(^ _Nullable)(void))parameters __attribute__((swift_name("getOrNull(clazz:qualifier:parameters:)")));
- (id _Nullable)getPropertyKey:(NSString *)key __attribute__((swift_name("getProperty(key:)")));
- (id)getPropertyKey:(NSString *)key defaultValue:(id)defaultValue __attribute__((swift_name("getProperty(key:defaultValue:)")));
- (KMPWMKoin_coreScope *)getScopeScopeId:(NSString *)scopeId __attribute__((swift_name("getScope(scopeId:)")));
- (KMPWMKoin_coreScope * _Nullable)getScopeOrNullScopeId:(NSString *)scopeId __attribute__((swift_name("getScopeOrNull(scopeId:)")));
- (id<KMPWMKotlinLazy>)injectQualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier mode:(KMPWMKotlinLazyThreadSafetyMode *)mode parameters:(KMPWMKoin_coreParametersHolder *(^ _Nullable)(void))parameters __attribute__((swift_name("inject(qualifier:mode:parameters:)")));
- (id<KMPWMKotlinLazy>)injectOrNullQualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier mode:(KMPWMKotlinLazyThreadSafetyMode *)mode parameters:(KMPWMKoin_coreParametersHolder *(^ _Nullable)(void))parameters __attribute__((swift_name("injectOrNull(qualifier:mode:parameters:)")));
- (void)loadModulesModules:(NSArray<KMPWMKoin_coreModule *> *)modules allowOverride:(BOOL)allowOverride createEagerInstances:(BOOL)createEagerInstances __attribute__((swift_name("loadModules(modules:allowOverride:createEagerInstances:)")));
- (void)setPropertyKey:(NSString *)key value:(id)value __attribute__((swift_name("setProperty(key:value:)")));
- (void)setupLoggerLogger:(KMPWMKoin_coreLogger *)logger __attribute__((swift_name("setupLogger(logger:)")));
- (void)unloadModulesModules:(NSArray<KMPWMKoin_coreModule *> *)modules __attribute__((swift_name("unloadModules(modules:)")));
@property (readonly) KMPWMKoin_coreExtensionManager *extensionManager __attribute__((swift_name("extensionManager")));
@property (readonly) KMPWMKoin_coreInstanceRegistry *instanceRegistry __attribute__((swift_name("instanceRegistry")));
@property (readonly) KMPWMKoin_coreLogger *logger __attribute__((swift_name("logger")));
@property (readonly) KMPWMKoin_coreOptionRegistry *optionRegistry __attribute__((swift_name("optionRegistry")));
@property (readonly) KMPWMKoin_corePropertyRegistry *propertyRegistry __attribute__((swift_name("propertyRegistry")));
@property (readonly) KMPWMKoin_coreCoreResolver *resolver __attribute__((swift_name("resolver")));
@property (readonly) KMPWMKoin_coreScopeRegistry *scopeRegistry __attribute__((swift_name("scopeRegistry")));
@end

__attribute__((swift_name("KotlinKDeclarationContainer")))
@protocol KMPWMKotlinKDeclarationContainer
@required
@end

__attribute__((swift_name("KotlinKAnnotatedElement")))
@protocol KMPWMKotlinKAnnotatedElement
@required
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.1")
*/
__attribute__((swift_name("KotlinKClassifier")))
@protocol KMPWMKotlinKClassifier
@required
@end

__attribute__((swift_name("KotlinKClass")))
@protocol KMPWMKotlinKClass <KMPWMKotlinKDeclarationContainer, KMPWMKotlinKAnnotatedElement, KMPWMKotlinKClassifier>
@required

/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.1")
*/
- (BOOL)isInstanceValue:(id _Nullable)value __attribute__((swift_name("isInstance(value:)")));
@property (readonly) NSString * _Nullable qualifiedName __attribute__((swift_name("qualifiedName")));
@property (readonly) NSString * _Nullable simpleName __attribute__((swift_name("simpleName")));
@end

__attribute__((swift_name("KotlinLazy")))
@protocol KMPWMKotlinLazy
@required
- (BOOL)isInitialized __attribute__((swift_name("isInitialized()")));
@property (readonly) id _Nullable value __attribute__((swift_name("value")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinLazyThreadSafetyMode")))
@interface KMPWMKotlinLazyThreadSafetyMode : KMPWMKotlinEnum<KMPWMKotlinLazyThreadSafetyMode *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) KMPWMKotlinLazyThreadSafetyMode *synchronized __attribute__((swift_name("synchronized")));
@property (class, readonly) KMPWMKotlinLazyThreadSafetyMode *publication __attribute__((swift_name("publication")));
@property (class, readonly) KMPWMKotlinLazyThreadSafetyMode *none __attribute__((swift_name("none")));
+ (KMPWMKotlinArray<KMPWMKotlinLazyThreadSafetyMode *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<KMPWMKotlinLazyThreadSafetyMode *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((swift_name("Koin_coreScopeCallback")))
@protocol KMPWMKoin_coreScopeCallback
@required
- (void)onScopeCloseScope:(KMPWMKoin_coreScope *)scope __attribute__((swift_name("onScopeClose(scope:)")));
@end

__attribute__((swift_name("Koin_coreLogger")))
@interface KMPWMKoin_coreLogger : KMPWMBase
- (instancetype)initWithLevel:(KMPWMKoin_coreLevel *)level __attribute__((swift_name("init(level:)"))) __attribute__((objc_designated_initializer));
- (void)debugMsg:(NSString *)msg __attribute__((swift_name("debug(msg:)")));
- (void)displayLevel:(KMPWMKoin_coreLevel *)level msg:(NSString *)msg __attribute__((swift_name("display(level:msg:)")));
- (void)errorMsg:(NSString *)msg __attribute__((swift_name("error(msg:)")));
- (void)infoMsg:(NSString *)msg __attribute__((swift_name("info(msg:)")));
- (BOOL)isAtLvl:(KMPWMKoin_coreLevel *)lvl __attribute__((swift_name("isAt(lvl:)")));
- (void)logLvl:(KMPWMKoin_coreLevel *)lvl msg:(NSString *(^)(void))msg __attribute__((swift_name("log(lvl:msg:)")));
- (void)logLvl:(KMPWMKoin_coreLevel *)lvl msg_:(NSString *)msg __attribute__((swift_name("log(lvl:msg_:)")));
- (void)warnMsg:(NSString *)msg __attribute__((swift_name("warn(msg:)")));
@property KMPWMKoin_coreLevel *level __attribute__((swift_name("level")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Koin_coreBeanDefinition")))
@interface KMPWMKoin_coreBeanDefinition<T> : KMPWMBase
- (instancetype)initWithScopeQualifier:(id<KMPWMKoin_coreQualifier>)scopeQualifier primaryType:(id<KMPWMKotlinKClass>)primaryType qualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier definition:(T _Nullable (^)(KMPWMKoin_coreScope *, KMPWMKoin_coreParametersHolder *))definition kind:(KMPWMKoin_coreKind *)kind secondaryTypes:(NSArray<id<KMPWMKotlinKClass>> *)secondaryTypes __attribute__((swift_name("init(scopeQualifier:primaryType:qualifier:definition:kind:secondaryTypes:)"))) __attribute__((objc_designated_initializer));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (BOOL)hasTypeClazz:(id<KMPWMKotlinKClass>)clazz __attribute__((swift_name("hasType(clazz:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (BOOL)isClazz:(id<KMPWMKotlinKClass>)clazz qualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier scopeDefinition:(id<KMPWMKoin_coreQualifier>)scopeDefinition __attribute__((swift_name("is(clazz:qualifier:scopeDefinition:)")));
- (NSString *)description __attribute__((swift_name("description()")));
@property KMPWMKoin_coreCallbacks<T> *callbacks __attribute__((swift_name("callbacks")));
@property (readonly) T _Nullable (^definition)(KMPWMKoin_coreScope *, KMPWMKoin_coreParametersHolder *) __attribute__((swift_name("definition")));
@property (readonly) KMPWMKoin_coreKind *kind __attribute__((swift_name("kind")));
@property (readonly) id<KMPWMKotlinKClass> primaryType __attribute__((swift_name("primaryType")));
@property id<KMPWMKoin_coreQualifier> _Nullable qualifier __attribute__((swift_name("qualifier")));
@property (readonly) id<KMPWMKoin_coreQualifier> scopeQualifier __attribute__((swift_name("scopeQualifier")));
@property NSArray<id<KMPWMKotlinKClass>> *secondaryTypes __attribute__((swift_name("secondaryTypes")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Koin_coreInstanceFactoryCompanion")))
@interface KMPWMKoin_coreInstanceFactoryCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKoin_coreInstanceFactoryCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) NSString *ERROR_SEPARATOR __attribute__((swift_name("ERROR_SEPARATOR")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Koin_coreResolutionContext")))
@interface KMPWMKoin_coreResolutionContext : KMPWMBase
- (instancetype)initWithLogger:(KMPWMKoin_coreLogger *)logger scope:(KMPWMKoin_coreScope *)scope clazz:(id<KMPWMKotlinKClass>)clazz qualifier:(id<KMPWMKoin_coreQualifier> _Nullable)qualifier parameters:(KMPWMKoin_coreParametersHolder * _Nullable)parameters __attribute__((swift_name("init(logger:scope:clazz:qualifier:parameters:)"))) __attribute__((objc_designated_initializer));
- (KMPWMKoin_coreResolutionContext *)doNewContextForScopeS:(KMPWMKoin_coreScope *)s __attribute__((swift_name("doNewContextForScope(s:)")));
@property (readonly) id<KMPWMKotlinKClass> clazz __attribute__((swift_name("clazz")));
@property (readonly) NSString *debugTag __attribute__((swift_name("debugTag")));
@property (readonly) KMPWMKoin_coreLogger *logger __attribute__((swift_name("logger")));
@property (readonly) KMPWMKoin_coreParametersHolder * _Nullable parameters __attribute__((swift_name("parameters")));
@property (readonly) id<KMPWMKoin_coreQualifier> _Nullable qualifier __attribute__((swift_name("qualifier")));
@property (readonly) KMPWMKoin_coreScope *scope __attribute__((swift_name("scope")));
@property KMPWMKoin_coreTypeQualifier * _Nullable scopeArchetype __attribute__((swift_name("scopeArchetype")));
@end


/**
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
__attribute__((swift_name("Kotlinx_serialization_coreSerializersModuleCollector")))
@protocol KMPWMKotlinx_serialization_coreSerializersModuleCollector
@required
- (void)contextualKClass:(id<KMPWMKotlinKClass>)kClass provider:(id<KMPWMKotlinx_serialization_coreKSerializer> (^)(NSArray<id<KMPWMKotlinx_serialization_coreKSerializer>> *))provider __attribute__((swift_name("contextual(kClass:provider:)")));
- (void)contextualKClass:(id<KMPWMKotlinKClass>)kClass serializer:(id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("contextual(kClass:serializer:)")));
- (void)polymorphicBaseClass:(id<KMPWMKotlinKClass>)baseClass actualClass:(id<KMPWMKotlinKClass>)actualClass actualSerializer:(id<KMPWMKotlinx_serialization_coreKSerializer>)actualSerializer __attribute__((swift_name("polymorphic(baseClass:actualClass:actualSerializer:)")));
- (void)polymorphicDefaultBaseClass:(id<KMPWMKotlinKClass>)baseClass defaultDeserializerProvider:(id<KMPWMKotlinx_serialization_coreDeserializationStrategy> _Nullable (^)(NSString * _Nullable))defaultDeserializerProvider __attribute__((swift_name("polymorphicDefault(baseClass:defaultDeserializerProvider:)"))) __attribute__((deprecated("Deprecated in favor of function with more precise name: polymorphicDefaultDeserializer")));
- (void)polymorphicDefaultDeserializerBaseClass:(id<KMPWMKotlinKClass>)baseClass defaultDeserializerProvider:(id<KMPWMKotlinx_serialization_coreDeserializationStrategy> _Nullable (^)(NSString * _Nullable))defaultDeserializerProvider __attribute__((swift_name("polymorphicDefaultDeserializer(baseClass:defaultDeserializerProvider:)")));
- (void)polymorphicDefaultSerializerBaseClass:(id<KMPWMKotlinKClass>)baseClass defaultSerializerProvider:(id<KMPWMKotlinx_serialization_coreSerializationStrategy> _Nullable (^)(id))defaultSerializerProvider __attribute__((swift_name("polymorphicDefaultSerializer(baseClass:defaultSerializerProvider:)")));
@end

__attribute__((swift_name("Koin_coreKoinComponent")))
@protocol KMPWMKoin_coreKoinComponent
@required
- (KMPWMKoin_coreKoin *)getKoin __attribute__((swift_name("getKoin()")));
@end

__attribute__((swift_name("Koin_coreKoinScopeComponent")))
@protocol KMPWMKoin_coreKoinScopeComponent <KMPWMKoin_coreKoinComponent>
@required
@property (readonly) KMPWMKoin_coreScope *scope __attribute__((swift_name("scope")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Koin_coreExtensionManager")))
@interface KMPWMKoin_coreExtensionManager : KMPWMBase
- (instancetype)initWith_koin:(KMPWMKoin_coreKoin *)_koin __attribute__((swift_name("init(_koin:)"))) __attribute__((objc_designated_initializer));
- (void)close __attribute__((swift_name("close()")));
- (id<KMPWMKoin_coreKoinExtension>)getExtensionId:(NSString *)id __attribute__((swift_name("getExtension(id:)")));
- (id<KMPWMKoin_coreKoinExtension> _Nullable)getExtensionOrNullId:(NSString *)id __attribute__((swift_name("getExtensionOrNull(id:)")));
- (void)registerExtensionId:(NSString *)id extension:(id<KMPWMKoin_coreKoinExtension>)extension __attribute__((swift_name("registerExtension(id:extension:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Koin_coreInstanceRegistry")))
@interface KMPWMKoin_coreInstanceRegistry : KMPWMBase
- (instancetype)initWith_koin:(KMPWMKoin_coreKoin *)_koin __attribute__((swift_name("init(_koin:)"))) __attribute__((objc_designated_initializer));
- (void)saveMappingAllowOverride:(BOOL)allowOverride mapping:(NSString *)mapping factory:(KMPWMKoin_coreInstanceFactory<id> *)factory logWarning:(BOOL)logWarning __attribute__((swift_name("saveMapping(allowOverride:mapping:factory:logWarning:)")));
- (int32_t)size __attribute__((swift_name("size()")));
@property (readonly) KMPWMKoin_coreKoin *_koin __attribute__((swift_name("_koin")));
@property (readonly) NSDictionary<NSString *, KMPWMKoin_coreInstanceFactory<id> *> *instances __attribute__((swift_name("instances")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Koin_coreOptionRegistry")))
@interface KMPWMKoin_coreOptionRegistry : KMPWMBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Koin_corePropertyRegistry")))
@interface KMPWMKoin_corePropertyRegistry : KMPWMBase
- (instancetype)initWith_koin:(KMPWMKoin_coreKoin *)_koin __attribute__((swift_name("init(_koin:)"))) __attribute__((objc_designated_initializer));
- (void)close __attribute__((swift_name("close()")));
- (void)deletePropertyKey:(NSString *)key __attribute__((swift_name("deleteProperty(key:)")));
- (id _Nullable)getPropertyKey:(NSString *)key __attribute__((swift_name("getProperty(key:)")));
- (void)savePropertiesProperties:(NSDictionary<NSString *, id> *)properties __attribute__((swift_name("saveProperties(properties:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Koin_coreCoreResolver")))
@interface KMPWMKoin_coreCoreResolver : KMPWMBase
- (instancetype)initWith_koin:(KMPWMKoin_coreKoin *)_koin __attribute__((swift_name("init(_koin:)"))) __attribute__((objc_designated_initializer));
- (void)addResolutionExtensionResolutionExtension:(id<KMPWMKoin_coreResolutionExtension>)resolutionExtension __attribute__((swift_name("addResolutionExtension(resolutionExtension:)")));
- (id _Nullable)resolveFromContextScope:(KMPWMKoin_coreScope *)scope instanceContext:(KMPWMKoin_coreResolutionContext *)instanceContext __attribute__((swift_name("resolveFromContext(scope:instanceContext:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Koin_coreScopeRegistry")))
@interface KMPWMKoin_coreScopeRegistry : KMPWMBase
- (instancetype)initWith_koin:(KMPWMKoin_coreKoin *)_koin __attribute__((swift_name("init(_koin:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMKoin_coreScopeRegistryCompanion *companion __attribute__((swift_name("companion")));
- (void)loadScopesModules:(NSSet<KMPWMKoin_coreModule *> *)modules __attribute__((swift_name("loadScopes(modules:)")));
@property (readonly) KMPWMKoin_coreScope *rootScope __attribute__((swift_name("rootScope")));
@property (readonly) NSSet<id<KMPWMKoin_coreQualifier>> *scopeDefinitions __attribute__((swift_name("scopeDefinitions")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Koin_coreLevel")))
@interface KMPWMKoin_coreLevel : KMPWMKotlinEnum<KMPWMKoin_coreLevel *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) KMPWMKoin_coreLevel *debug __attribute__((swift_name("debug")));
@property (class, readonly) KMPWMKoin_coreLevel *info __attribute__((swift_name("info")));
@property (class, readonly) KMPWMKoin_coreLevel *warning __attribute__((swift_name("warning")));
@property (class, readonly) KMPWMKoin_coreLevel *error __attribute__((swift_name("error")));
@property (class, readonly) KMPWMKoin_coreLevel *none __attribute__((swift_name("none")));
+ (KMPWMKotlinArray<KMPWMKoin_coreLevel *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<KMPWMKoin_coreLevel *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Koin_coreKind")))
@interface KMPWMKoin_coreKind : KMPWMKotlinEnum<KMPWMKoin_coreKind *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) KMPWMKoin_coreKind *singleton __attribute__((swift_name("singleton")));
@property (class, readonly) KMPWMKoin_coreKind *factory __attribute__((swift_name("factory")));
@property (class, readonly) KMPWMKoin_coreKind *scoped __attribute__((swift_name("scoped")));
+ (KMPWMKotlinArray<KMPWMKoin_coreKind *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<KMPWMKoin_coreKind *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Koin_coreCallbacks")))
@interface KMPWMKoin_coreCallbacks<T> : KMPWMBase
- (instancetype)initWithOnClose:(void (^ _Nullable)(T _Nullable))onClose __attribute__((swift_name("init(onClose:)"))) __attribute__((objc_designated_initializer));
- (KMPWMKoin_coreCallbacks<T> *)doCopyOnClose:(void (^ _Nullable)(T _Nullable))onClose __attribute__((swift_name("doCopy(onClose:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) void (^ _Nullable onClose)(T _Nullable) __attribute__((swift_name("onClose")));
@end

__attribute__((swift_name("Koin_coreKoinExtension")))
@protocol KMPWMKoin_coreKoinExtension
@required
- (void)onClose __attribute__((swift_name("onClose()")));
- (void)onRegisterKoin:(KMPWMKoin_coreKoin *)koin __attribute__((swift_name("onRegister(koin:)")));
@end

__attribute__((swift_name("Koin_coreResolutionExtension")))
@protocol KMPWMKoin_coreResolutionExtension
@required
- (id _Nullable)resolveScope:(KMPWMKoin_coreScope *)scope instanceContext:(KMPWMKoin_coreResolutionContext *)instanceContext __attribute__((swift_name("resolve(scope:instanceContext:)")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Koin_coreScopeRegistry.Companion")))
@interface KMPWMKoin_coreScopeRegistryCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKoin_coreScopeRegistryCompanion *shared __attribute__((swift_name("shared")));
@end

#pragma pop_macro("_Nullable_result")
#pragma clang diagnostic pop
NS_ASSUME_NONNULL_END
