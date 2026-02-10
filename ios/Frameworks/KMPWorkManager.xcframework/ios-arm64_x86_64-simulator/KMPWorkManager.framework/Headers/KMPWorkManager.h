#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

@class KMPWMBGTaskType, KMPWMBackoffPolicy, KMPWMBuiltinWorkerRegistry, KMPWMCRC32, KMPWMChainExecutorCompanion, KMPWMChainExecutorExecutionMetrics, KMPWMChainProgress, KMPWMChainProgressCompanion, KMPWMCompressionLevel, KMPWMCompressionLevelCompanion, KMPWMConstraints, KMPWMConstraintsCompanion, KMPWMEventStoreConfig, KMPWMEventSyncManager, KMPWMExactAlarmIOSBehavior, KMPWMExistingPolicy, KMPWMFileCompressionConfig, KMPWMFileCompressionConfigCompanion, KMPWMHttpDownloadConfig, KMPWMHttpDownloadConfigCompanion, KMPWMHttpDownloadWorkerCompanion, KMPWMHttpMethod, KMPWMHttpMethodCompanion, KMPWMHttpRequestConfig, KMPWMHttpRequestConfigCompanion, KMPWMHttpRequestWorkerCompanion, KMPWMHttpSyncConfig, KMPWMHttpSyncConfigCompanion, KMPWMHttpSyncWorkerCompanion, KMPWMHttpUploadConfig, KMPWMHttpUploadConfigCompanion, KMPWMHttpUploadWorkerCompanion, KMPWMInfoPlistReader, KMPWMKmpWorkManagerConfig, KMPWMKoin_coreBeanDefinition<T>, KMPWMKoin_coreCallbacks<T>, KMPWMKoin_coreCoreResolver, KMPWMKoin_coreExtensionManager, KMPWMKoin_coreInstanceFactory<T>, KMPWMKoin_coreInstanceFactoryCompanion, KMPWMKoin_coreInstanceRegistry, KMPWMKoin_coreKind, KMPWMKoin_coreKoin, KMPWMKoin_coreKoinDefinition<R>, KMPWMKoin_coreLevel, KMPWMKoin_coreLockable, KMPWMKoin_coreLogger, KMPWMKoin_coreModule, KMPWMKoin_coreOptionRegistry, KMPWMKoin_coreParametersHolder, KMPWMKoin_corePropertyRegistry, KMPWMKoin_coreResolutionContext, KMPWMKoin_coreScope, KMPWMKoin_coreScopeDSL, KMPWMKoin_coreScopeRegistry, KMPWMKoin_coreScopeRegistryCompanion, KMPWMKoin_coreSingleInstanceFactory<T>, KMPWMKoin_coreTypeQualifier, KMPWMKotlinAbstractCoroutineContextElement, KMPWMKotlinAbstractCoroutineContextKey<B, E>, KMPWMKotlinArray<T>, KMPWMKotlinByteArray, KMPWMKotlinByteIterator, KMPWMKotlinCancellationException, KMPWMKotlinEnum<E>, KMPWMKotlinEnumCompanion, KMPWMKotlinException, KMPWMKotlinIllegalStateException, KMPWMKotlinKTypeProjection, KMPWMKotlinKTypeProjectionCompanion, KMPWMKotlinKVariance, KMPWMKotlinLazyThreadSafetyMode, KMPWMKotlinNothing, KMPWMKotlinRuntimeException, KMPWMKotlinThrowable, KMPWMKotlinUnit, KMPWMKotlinx_coroutines_coreCoroutineDispatcher, KMPWMKotlinx_coroutines_coreCoroutineDispatcherKey, KMPWMKotlinx_serialization_coreSerialKind, KMPWMKotlinx_serialization_coreSerializersModule, KMPWMKotlinx_serialization_jsonJsonElement, KMPWMKotlinx_serialization_jsonJsonElementCompanion, KMPWMKtor_client_coreHttpClient, KMPWMKtor_client_coreHttpClientCall, KMPWMKtor_client_coreHttpClientCallCompanion, KMPWMKtor_client_coreHttpClientConfig<T>, KMPWMKtor_client_coreHttpClientEngineConfig, KMPWMKtor_client_coreHttpReceivePipeline, KMPWMKtor_client_coreHttpReceivePipelinePhases, KMPWMKtor_client_coreHttpRequestBuilder, KMPWMKtor_client_coreHttpRequestBuilderCompanion, KMPWMKtor_client_coreHttpRequestData, KMPWMKtor_client_coreHttpRequestPipeline, KMPWMKtor_client_coreHttpRequestPipelinePhases, KMPWMKtor_client_coreHttpResponse, KMPWMKtor_client_coreHttpResponseContainer, KMPWMKtor_client_coreHttpResponseData, KMPWMKtor_client_coreHttpResponsePipeline, KMPWMKtor_client_coreHttpResponsePipelinePhases, KMPWMKtor_client_coreHttpSendPipeline, KMPWMKtor_client_coreHttpSendPipelinePhases, KMPWMKtor_client_coreProxyConfig, KMPWMKtor_eventsEventDefinition<T>, KMPWMKtor_eventsEvents, KMPWMKtor_httpContentType, KMPWMKtor_httpContentTypeCompanion, KMPWMKtor_httpHeaderValueParam, KMPWMKtor_httpHeaderValueWithParameters, KMPWMKtor_httpHeaderValueWithParametersCompanion, KMPWMKtor_httpHeadersBuilder, KMPWMKtor_httpHttpMethod, KMPWMKtor_httpHttpMethodCompanion, KMPWMKtor_httpHttpProtocolVersion, KMPWMKtor_httpHttpProtocolVersionCompanion, KMPWMKtor_httpHttpStatusCode, KMPWMKtor_httpHttpStatusCodeCompanion, KMPWMKtor_httpOutgoingContent, KMPWMKtor_httpURLBuilder, KMPWMKtor_httpURLBuilderCompanion, KMPWMKtor_httpURLProtocol, KMPWMKtor_httpURLProtocolCompanion, KMPWMKtor_httpUrl, KMPWMKtor_httpUrlCompanion, KMPWMKtor_ioBuffer, KMPWMKtor_ioBufferCompanion, KMPWMKtor_ioByteReadPacket, KMPWMKtor_ioByteReadPacketCompanion, KMPWMKtor_ioChunkBuffer, KMPWMKtor_ioChunkBufferCompanion, KMPWMKtor_ioInput, KMPWMKtor_ioInputCompanion, KMPWMKtor_ioMemory, KMPWMKtor_ioMemoryCompanion, KMPWMKtor_utilsAttributeKey<T>, KMPWMKtor_utilsGMTDate, KMPWMKtor_utilsGMTDateCompanion, KMPWMKtor_utilsMonth, KMPWMKtor_utilsMonthCompanion, KMPWMKtor_utilsPipeline<TSubject, TContext>, KMPWMKtor_utilsPipelinePhase, KMPWMKtor_utilsStringValuesBuilderImpl, KMPWMKtor_utilsTypeInfo, KMPWMKtor_utilsWeekDay, KMPWMKtor_utilsWeekDayCompanion, KMPWMLogTags, KMPWMLogger, KMPWMLoggerLevel, KMPWMMigrationResult, KMPWMOkioBuffer, KMPWMOkioBufferUnsafeCursor, KMPWMOkioByteString, KMPWMOkioByteStringCompanion, KMPWMOkioFileHandle, KMPWMOkioFileMetadata, KMPWMOkioFileSystem, KMPWMOkioFileSystemCompanion, KMPWMOkioLock, KMPWMOkioLockCompanion, KMPWMOkioPath, KMPWMOkioPathCompanion, KMPWMOkioTimeout, KMPWMOkioTimeoutCompanion, KMPWMQos, KMPWMScheduleResult, KMPWMSchedulerStatus, KMPWMSecurityValidator, KMPWMSingleTaskExecutorCompanion, KMPWMStoredEvent, KMPWMStoredEventCompanion, KMPWMSystemConstraint, KMPWMSystemConstraintCompanion, KMPWMSystemHealthReport, KMPWMTaskChain, KMPWMTaskCompletionEvent, KMPWMTaskCompletionEventCompanion, KMPWMTaskEventBus, KMPWMTaskEventManager, KMPWMTaskIds, KMPWMTaskProgressBus, KMPWMTaskProgressEvent, KMPWMTaskProgressEventCompanion, KMPWMTaskRequest, KMPWMTaskRequestCompanion, KMPWMTaskSpec<T>, KMPWMTaskStatusDetail, KMPWMTaskTriggerBatteryLow, KMPWMTaskTriggerBatteryOkay, KMPWMTaskTriggerContentUri, KMPWMTaskTriggerDeviceIdle, KMPWMTaskTriggerExact, KMPWMTaskTriggerOneTime, KMPWMTaskTriggerPeriodic, KMPWMTaskTriggerStorageLow, KMPWMTaskTriggerWindowed, KMPWMWorkerProgress, KMPWMWorkerProgressCompanion, KMPWMWorkerResult, KMPWMWorkerResultFailure, KMPWMWorkerResultSuccess, KMPWMWorkerTypes, NSData;

@protocol KMPWMBackgroundTaskScheduler, KMPWMCloseable, KMPWMCustomLogger, KMPWMEventStore, KMPWMIosWorkerFactory, KMPWMKoin_coreKoinComponent, KMPWMKoin_coreKoinExtension, KMPWMKoin_coreKoinScopeComponent, KMPWMKoin_coreQualifier, KMPWMKoin_coreResolutionExtension, KMPWMKoin_coreScopeCallback, KMPWMKotlinAnnotation, KMPWMKotlinAppendable, KMPWMKotlinComparable, KMPWMKotlinContinuation, KMPWMKotlinContinuationInterceptor, KMPWMKotlinCoroutineContext, KMPWMKotlinCoroutineContextElement, KMPWMKotlinCoroutineContextKey, KMPWMKotlinFunction, KMPWMKotlinIterator, KMPWMKotlinKAnnotatedElement, KMPWMKotlinKClass, KMPWMKotlinKClassifier, KMPWMKotlinKDeclarationContainer, KMPWMKotlinKType, KMPWMKotlinLazy, KMPWMKotlinMapEntry, KMPWMKotlinSequence, KMPWMKotlinSuspendFunction1, KMPWMKotlinSuspendFunction2, KMPWMKotlinx_coroutines_coreChildHandle, KMPWMKotlinx_coroutines_coreChildJob, KMPWMKotlinx_coroutines_coreCoroutineScope, KMPWMKotlinx_coroutines_coreDisposableHandle, KMPWMKotlinx_coroutines_coreFlow, KMPWMKotlinx_coroutines_coreFlowCollector, KMPWMKotlinx_coroutines_coreJob, KMPWMKotlinx_coroutines_coreParentJob, KMPWMKotlinx_coroutines_coreRunnable, KMPWMKotlinx_coroutines_coreSelectClause, KMPWMKotlinx_coroutines_coreSelectClause0, KMPWMKotlinx_coroutines_coreSelectInstance, KMPWMKotlinx_coroutines_coreSharedFlow, KMPWMKotlinx_serialization_coreCompositeDecoder, KMPWMKotlinx_serialization_coreCompositeEncoder, KMPWMKotlinx_serialization_coreDecoder, KMPWMKotlinx_serialization_coreDeserializationStrategy, KMPWMKotlinx_serialization_coreEncoder, KMPWMKotlinx_serialization_coreKSerializer, KMPWMKotlinx_serialization_coreSerialDescriptor, KMPWMKotlinx_serialization_coreSerializationStrategy, KMPWMKotlinx_serialization_coreSerializersModuleCollector, KMPWMKtor_client_coreHttpClientEngine, KMPWMKtor_client_coreHttpClientEngineCapability, KMPWMKtor_client_coreHttpClientPlugin, KMPWMKtor_client_coreHttpRequest, KMPWMKtor_httpHeaders, KMPWMKtor_httpHttpMessage, KMPWMKtor_httpHttpMessageBuilder, KMPWMKtor_httpParameters, KMPWMKtor_httpParametersBuilder, KMPWMKtor_ioByteReadChannel, KMPWMKtor_ioCloseable, KMPWMKtor_ioObjectPool, KMPWMKtor_ioReadSession, KMPWMKtor_utilsAttributes, KMPWMKtor_utilsStringValues, KMPWMKtor_utilsStringValuesBuilder, KMPWMOkioBufferedSink, KMPWMOkioBufferedSource, KMPWMOkioCloseable, KMPWMOkioSink, KMPWMOkioSource, KMPWMProgressListener, KMPWMTaskTrigger, KMPWMWorker, KMPWMWorkerFactory;

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


/**
 * Configuration for KmpWorkManager initialization.
 *
 * Example:
 * ```
 * val config = KmpWorkManagerConfig(
 *     logLevel = Logger.Level.INFO,  // Only log INFO and above in production
 *     customLogger = MyCustomLogger()
 * )
 *
 * startKoin {
 *     androidContext(this@Application)
 *     modules(kmpWorkerModule(workerFactory = MyWorkerFactory(), config = config))
 * }
 * ```
 *
 * @param logLevel Minimum log level to output. Default: INFO (production-friendly)
 * @param customLogger Custom logger implementation for routing logs to analytics/crash reporting. Default: null
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KmpWorkManagerConfig")))
@interface KMPWMKmpWorkManagerConfig : KMPWMBase
- (instancetype)initWithLogLevel:(KMPWMLoggerLevel *)logLevel customLogger:(id<KMPWMCustomLogger> _Nullable)customLogger __attribute__((swift_name("init(logLevel:customLogger:)"))) __attribute__((objc_designated_initializer));
- (KMPWMKmpWorkManagerConfig *)doCopyLogLevel:(KMPWMLoggerLevel *)logLevel customLogger:(id<KMPWMCustomLogger> _Nullable)customLogger __attribute__((swift_name("doCopy(logLevel:customLogger:)")));

/**
 * Configuration for KmpWorkManager initialization.
 *
 * Example:
 * ```
 * val config = KmpWorkManagerConfig(
 *     logLevel = Logger.Level.INFO,  // Only log INFO and above in production
 *     customLogger = MyCustomLogger()
 * )
 *
 * startKoin {
 *     androidContext(this@Application)
 *     modules(kmpWorkerModule(workerFactory = MyWorkerFactory(), config = config))
 * }
 * ```
 *
 * @param logLevel Minimum log level to output. Default: INFO (production-friendly)
 * @param customLogger Custom logger implementation for routing logs to analytics/crash reporting. Default: null
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Configuration for KmpWorkManager initialization.
 *
 * Example:
 * ```
 * val config = KmpWorkManagerConfig(
 *     logLevel = Logger.Level.INFO,  // Only log INFO and above in production
 *     customLogger = MyCustomLogger()
 * )
 *
 * startKoin {
 *     androidContext(this@Application)
 *     modules(kmpWorkerModule(workerFactory = MyWorkerFactory(), config = config))
 * }
 * ```
 *
 * @param logLevel Minimum log level to output. Default: INFO (production-friendly)
 * @param customLogger Custom logger implementation for routing logs to analytics/crash reporting. Default: null
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Configuration for KmpWorkManager initialization.
 *
 * Example:
 * ```
 * val config = KmpWorkManagerConfig(
 *     logLevel = Logger.Level.INFO,  // Only log INFO and above in production
 *     customLogger = MyCustomLogger()
 * )
 *
 * startKoin {
 *     androidContext(this@Application)
 *     modules(kmpWorkerModule(workerFactory = MyWorkerFactory(), config = config))
 * }
 * ```
 *
 * @param logLevel Minimum log level to output. Default: INFO (production-friendly)
 * @param customLogger Custom logger implementation for routing logs to analytics/crash reporting. Default: null
 */
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) id<KMPWMCustomLogger> _Nullable customLogger __attribute__((swift_name("customLogger")));
@property (readonly) KMPWMLoggerLevel *logLevel __attribute__((swift_name("logLevel")));
@end


/**
 * Closeable interface for resource cleanup
 */
__attribute__((swift_name("Closeable")))
@protocol KMPWMCloseable
@required
- (void)close __attribute__((swift_name("close()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ChainExecutor")))
@interface KMPWMChainExecutor : KMPWMBase <KMPWMCloseable>
- (instancetype)initWithWorkerFactory:(id<KMPWMIosWorkerFactory>)workerFactory taskType:(KMPWMBGTaskType *)taskType onContinuationNeeded:(void (^ _Nullable)(void))onContinuationNeeded __attribute__((swift_name("init(workerFactory:taskType:onContinuationNeeded:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMChainExecutorCompanion *companion __attribute__((swift_name("companion")));

/**
 * Cleanup coroutine scope (call when executor is no longer needed)
 *
 * @deprecated Use close() or .use {} pattern instead
 */
- (void)cleanup __attribute__((swift_name("cleanup()"))) __attribute__((deprecated("Use close() or .use {} pattern instead")));

/**
 * Implement Closeable interface
 *
 * This method ensures that:
 * - Coroutine scope is cancelled
 * - Resources are properly released
 * - Subsequent calls are no-ops
 * - Thread-safe with mutex protection
 *
 * **v2.3.1+:** Non-blocking close to prevent deadlocks. Progress flush happens
 * asynchronously. For guaranteed cleanup, use closeAsync() instead.
 */
- (void)close __attribute__((swift_name("close()")));

/**
 * Async version of close() that guarantees cleanup completion.
 * Use this when you need to ensure all resources are flushed before proceeding.
 *
 * **v2.3.1+:** Recommended for critical cleanup paths (app shutdown, etc.)
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)closeAsyncWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("closeAsync(completionHandler:)")));

/**
 * Execute multiple chains from the queue in batch mode.
 * This optimizes iOS BGTask usage by processing as many chains as possible
 * before the OS time limit is reached.
 *
 *
 * **Time-slicing strategy (v2.2.2+ Adaptive):**
 * - Uses adaptive time budget based on measured cleanup duration
 * - Checks minimum time before each chain
 * - Stops early to prevent system kills
 * - Schedules continuation if queue not empty
 *
 * @param maxChains Maximum number of chains to process (default: 3)
 * @param totalTimeoutMs Total timeout for batch processing (default: dynamic based on taskType)
 * @param deadlineEpochMs Absolute BGTask expiration time in epoch milliseconds.
 *   When provided, the effective timeout is clamped so execution stops before this deadline
 *   (minus a grace period for progress saving).  This correctly accounts for cold-start time
 *   already consumed before this method was invoked.  Prefer this over relying solely on
 *   totalTimeoutMs when calling from an iOS BGTask handler.
 * @return Number of successfully executed chains
 * @throws IllegalStateException if executor is closed
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)executeChainsInBatchMaxChains:(int32_t)maxChains totalTimeoutMs:(int64_t)totalTimeoutMs deadlineEpochMs:(KMPWMLong * _Nullable)deadlineEpochMs completionHandler:(void (^)(KMPWMInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("executeChainsInBatch(maxChains:totalTimeoutMs:deadlineEpochMs:completionHandler:)")));

/**
 * Retrieves the next chain ID from the queue and executes it.
 *
 * @return `true` if the chain was executed successfully or if the queue was empty, `false` otherwise.
 * @throws IllegalStateException if executor is closed
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)executeNextChainFromQueueWithCompletionHandler:(void (^)(KMPWMBoolean * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("executeNextChainFromQueue(completionHandler:)")));

/**
 * Returns the current number of chains waiting in the execution queue.
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getChainQueueSizeWithCompletionHandler:(void (^)(KMPWMInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getChainQueueSize(completionHandler:)")));

/**
 * This should be called when iOS signals BGTask expiration.
 *
 * **What it does**:
 * - Sets shutdown flag to stop accepting new chains
 * - Cancels the coroutine scope to interrupt running chains
 * - Running chains will catch CancellationException and save progress
 * - Waits for grace period to allow progress saving
 *
 * **Usage in Swift/Obj-C**:
 * ```swift
 * BGTaskScheduler.shared.register(forTaskWithIdentifier: id) { task in
 *     task.expirationHandler = {
 *         chainExecutor.requestShutdown() // Call this!
 *     }
 *     // ... execute chains ...
 * }
 * ```
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)requestShutdownWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("requestShutdown(completionHandler:)")));

/**
 * Thread-safe version using mutex to prevent race conditions
 *
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

/**
 * Default maximum time for chain execution (50 seconds)
 */
@property (readonly) int64_t CHAIN_TIMEOUT_MS __attribute__((swift_name("CHAIN_TIMEOUT_MS")));

/**
 * Time allowed for saving progress after shutdown signal
 */
@property (readonly) int64_t SHUTDOWN_GRACE_PERIOD_MS __attribute__((swift_name("SHUTDOWN_GRACE_PERIOD_MS")));

/**
 * Default timeout for individual tasks (20 seconds)
 */
@property (readonly) int64_t TASK_TIMEOUT_MS __attribute__((swift_name("TASK_TIMEOUT_MS")));
@end


/**
 * Execution metrics for monitoring and telemetry
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ChainExecutor.ExecutionMetrics")))
@interface KMPWMChainExecutorExecutionMetrics : KMPWMBase
- (instancetype)initWithTaskType:(KMPWMBGTaskType *)taskType startTime:(int64_t)startTime endTime:(int64_t)endTime duration:(int64_t)duration chainsAttempted:(int32_t)chainsAttempted chainsSucceeded:(int32_t)chainsSucceeded chainsFailed:(int32_t)chainsFailed wasKilledBySystem:(BOOL)wasKilledBySystem timeUsagePercentage:(int32_t)timeUsagePercentage queueSizeRemaining:(int32_t)queueSizeRemaining __attribute__((swift_name("init(taskType:startTime:endTime:duration:chainsAttempted:chainsSucceeded:chainsFailed:wasKilledBySystem:timeUsagePercentage:queueSizeRemaining:)"))) __attribute__((objc_designated_initializer));
- (KMPWMChainExecutorExecutionMetrics *)doCopyTaskType:(KMPWMBGTaskType *)taskType startTime:(int64_t)startTime endTime:(int64_t)endTime duration:(int64_t)duration chainsAttempted:(int32_t)chainsAttempted chainsSucceeded:(int32_t)chainsSucceeded chainsFailed:(int32_t)chainsFailed wasKilledBySystem:(BOOL)wasKilledBySystem timeUsagePercentage:(int32_t)timeUsagePercentage queueSizeRemaining:(int32_t)queueSizeRemaining __attribute__((swift_name("doCopy(taskType:startTime:endTime:duration:chainsAttempted:chainsSucceeded:chainsFailed:wasKilledBySystem:timeUsagePercentage:queueSizeRemaining:)")));

/**
 * Execution metrics for monitoring and telemetry
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Execution metrics for monitoring and telemetry
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Execution metrics for monitoring and telemetry
 */
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
 * Tracks the execution progress of a task chain on iOS.
 *
 * When a BGTask is interrupted (timeout, force-quit, etc.), this model
 * allows resuming the chain from where it left off instead of restarting
 * from the beginning.
 *
 * **Use Case:**
 * ```
 * Chain: [Step0, Step1, Step2, Step3, Step4]
 * - Execution starts, Step0 and Step1 complete successfully
 * - BGTask times out during Step2
 * - On next BGTask, resume from Step2 instead of Step0
 * ```
 *
 * **Retry Logic:**
 * - If a step fails, increment retryCount
 * - If retryCount >= maxRetries, abandon the chain
 * - This prevents infinite retry loops for permanently failing chains
 *
 * @property chainId Unique identifier for the chain
 * @property totalSteps Total number of steps in the chain
 * @property completedSteps Indices of successfully completed steps (e.g., [0, 1])
 * @property completedTasksInSteps Per-step tracking of which parallel task indices
 *   completed successfully. Keyed by step index; values are sorted task indices.
 *   Cleared for a step once that step is marked fully completed.
 * @property lastFailedStep Index of the step that last failed, if any
 * @property retryCount Number of times this chain has been retried
 * @property maxRetries Maximum retry attempts before abandoning (default: 3)
 *
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ChainProgress")))
@interface KMPWMChainProgress : KMPWMBase
- (instancetype)initWithChainId:(NSString *)chainId totalSteps:(int32_t)totalSteps completedSteps:(NSArray<KMPWMInt *> *)completedSteps completedTasksInSteps:(NSDictionary<KMPWMInt *, NSArray<KMPWMInt *> *> *)completedTasksInSteps lastFailedStep:(KMPWMInt * _Nullable)lastFailedStep retryCount:(int32_t)retryCount maxRetries:(int32_t)maxRetries __attribute__((swift_name("init(chainId:totalSteps:completedSteps:completedTasksInSteps:lastFailedStep:retryCount:maxRetries:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMChainProgressCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMChainProgress *)doCopyChainId:(NSString *)chainId totalSteps:(int32_t)totalSteps completedSteps:(NSArray<KMPWMInt *> *)completedSteps completedTasksInSteps:(NSDictionary<KMPWMInt *, NSArray<KMPWMInt *> *> *)completedTasksInSteps lastFailedStep:(KMPWMInt * _Nullable)lastFailedStep retryCount:(int32_t)retryCount maxRetries:(int32_t)maxRetries __attribute__((swift_name("doCopy(chainId:totalSteps:completedSteps:completedTasksInSteps:lastFailedStep:retryCount:maxRetries:)")));

/**
 * Tracks the execution progress of a task chain on iOS.
 *
 * When a BGTask is interrupted (timeout, force-quit, etc.), this model
 * allows resuming the chain from where it left off instead of restarting
 * from the beginning.
 *
 * **Use Case:**
 * ```
 * Chain: [Step0, Step1, Step2, Step3, Step4]
 * - Execution starts, Step0 and Step1 complete successfully
 * - BGTask times out during Step2
 * - On next BGTask, resume from Step2 instead of Step0
 * ```
 *
 * **Retry Logic:**
 * - If a step fails, increment retryCount
 * - If retryCount >= maxRetries, abandon the chain
 * - This prevents infinite retry loops for permanently failing chains
 *
 * @property chainId Unique identifier for the chain
 * @property totalSteps Total number of steps in the chain
 * @property completedSteps Indices of successfully completed steps (e.g., [0, 1])
 * @property completedTasksInSteps Per-step tracking of which parallel task indices
 *   completed successfully. Keyed by step index; values are sorted task indices.
 *   Cleared for a step once that step is marked fully completed.
 * @property lastFailedStep Index of the step that last failed, if any
 * @property retryCount Number of times this chain has been retried
 * @property maxRetries Maximum retry attempts before abandoning (default: 3)
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Get completion percentage (0-100).
 */
- (int32_t)getCompletionPercentage __attribute__((swift_name("getCompletionPercentage()")));

/**
 * Get the index of the next step to execute.
 * Returns null if all steps are completed.
 */
- (KMPWMInt * _Nullable)getNextStepIndex __attribute__((swift_name("getNextStepIndex()")));

/**
 * Check if the chain has exceeded max retries.
 */
- (BOOL)hasExceededRetries __attribute__((swift_name("hasExceededRetries()")));

/**
 * Tracks the execution progress of a task chain on iOS.
 *
 * When a BGTask is interrupted (timeout, force-quit, etc.), this model
 * allows resuming the chain from where it left off instead of restarting
 * from the beginning.
 *
 * **Use Case:**
 * ```
 * Chain: [Step0, Step1, Step2, Step3, Step4]
 * - Execution starts, Step0 and Step1 complete successfully
 * - BGTask times out during Step2
 * - On next BGTask, resume from Step2 instead of Step0
 * ```
 *
 * **Retry Logic:**
 * - If a step fails, increment retryCount
 * - If retryCount >= maxRetries, abandon the chain
 * - This prevents infinite retry loops for permanently failing chains
 *
 * @property chainId Unique identifier for the chain
 * @property totalSteps Total number of steps in the chain
 * @property completedSteps Indices of successfully completed steps (e.g., [0, 1])
 * @property completedTasksInSteps Per-step tracking of which parallel task indices
 *   completed successfully. Keyed by step index; values are sorted task indices.
 *   Cleared for a step once that step is marked fully completed.
 * @property lastFailedStep Index of the step that last failed, if any
 * @property retryCount Number of times this chain has been retried
 * @property maxRetries Maximum retry attempts before abandoning (default: 3)
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Check if all steps are completed.
 */
- (BOOL)isComplete __attribute__((swift_name("isComplete()")));

/**
 * Check if a specific step has been completed.
 */
- (BOOL)isStepCompletedStepIndex:(int32_t)stepIndex __attribute__((swift_name("isStepCompleted(stepIndex:)")));

/**
 * Check if a specific task within a parallel step has already completed.
 * Used to skip succeeded tasks when retrying a partially-failed step.
 */
- (BOOL)isTaskInStepCompletedStepIndex:(int32_t)stepIndex taskIndex:(int32_t)taskIndex __attribute__((swift_name("isTaskInStepCompleted(stepIndex:taskIndex:)")));

/**
 * Tracks the execution progress of a task chain on iOS.
 *
 * When a BGTask is interrupted (timeout, force-quit, etc.), this model
 * allows resuming the chain from where it left off instead of restarting
 * from the beginning.
 *
 * **Use Case:**
 * ```
 * Chain: [Step0, Step1, Step2, Step3, Step4]
 * - Execution starts, Step0 and Step1 complete successfully
 * - BGTask times out during Step2
 * - On next BGTask, resume from Step2 instead of Step0
 * ```
 *
 * **Retry Logic:**
 * - If a step fails, increment retryCount
 * - If retryCount >= maxRetries, abandon the chain
 * - This prevents infinite retry loops for permanently failing chains
 *
 * @property chainId Unique identifier for the chain
 * @property totalSteps Total number of steps in the chain
 * @property completedSteps Indices of successfully completed steps (e.g., [0, 1])
 * @property completedTasksInSteps Per-step tracking of which parallel task indices
 *   completed successfully. Keyed by step index; values are sorted task indices.
 *   Cleared for a step once that step is marked fully completed.
 * @property lastFailedStep Index of the step that last failed, if any
 * @property retryCount Number of times this chain has been retried
 * @property maxRetries Maximum retry attempts before abandoning (default: 3)
 */
- (NSString *)description __attribute__((swift_name("description()")));

/**
 * Create a new progress with an additional completed step.
 */
- (KMPWMChainProgress *)withCompletedStepStepIndex:(int32_t)stepIndex __attribute__((swift_name("withCompletedStep(stepIndex:)")));

/**
 * Record that a single task within a parallel step completed successfully.
 */
- (KMPWMChainProgress *)withCompletedTaskInStepStepIndex:(int32_t)stepIndex taskIndex:(int32_t)taskIndex __attribute__((swift_name("withCompletedTaskInStep(stepIndex:taskIndex:)")));

/**
 * Create a new progress with an incremented retry count.
 */
- (KMPWMChainProgress *)withFailureStepIndex:(int32_t)stepIndex __attribute__((swift_name("withFailure(stepIndex:)")));
@property (readonly) NSString *chainId __attribute__((swift_name("chainId")));
@property (readonly) NSArray<KMPWMInt *> *completedSteps __attribute__((swift_name("completedSteps")));
@property (readonly) NSDictionary<KMPWMInt *, NSArray<KMPWMInt *> *> *completedTasksInSteps __attribute__((swift_name("completedTasksInSteps")));
@property (readonly) KMPWMInt * _Nullable lastFailedStep __attribute__((swift_name("lastFailedStep")));
@property (readonly) int32_t maxRetries __attribute__((swift_name("maxRetries")));
@property (readonly) int32_t retryCount __attribute__((swift_name("retryCount")));
@property (readonly) int32_t totalSteps __attribute__((swift_name("totalSteps")));
@end


/**
 * Tracks the execution progress of a task chain on iOS.
 *
 * When a BGTask is interrupted (timeout, force-quit, etc.), this model
 * allows resuming the chain from where it left off instead of restarting
 * from the beginning.
 *
 * **Use Case:**
 * ```
 * Chain: [Step0, Step1, Step2, Step3, Step4]
 * - Execution starts, Step0 and Step1 complete successfully
 * - BGTask times out during Step2
 * - On next BGTask, resume from Step2 instead of Step0
 * ```
 *
 * **Retry Logic:**
 * - If a step fails, increment retryCount
 * - If retryCount >= maxRetries, abandon the chain
 * - This prevents infinite retry loops for permanently failing chains
 *
 * @property chainId Unique identifier for the chain
 * @property totalSteps Total number of steps in the chain
 * @property completedSteps Indices of successfully completed steps (e.g., [0, 1])
 * @property completedTasksInSteps Per-step tracking of which parallel task indices
 *   completed successfully. Keyed by step index; values are sorted task indices.
 *   Cleared for a step once that step is marked fully completed.
 * @property lastFailedStep Index of the step that last failed, if any
 * @property retryCount Number of times this chain has been retried
 * @property maxRetries Maximum retry attempts before abandoning (default: 3)
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ChainProgress.Companion")))
@interface KMPWMChainProgressCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Tracks the execution progress of a task chain on iOS.
 *
 * When a BGTask is interrupted (timeout, force-quit, etc.), this model
 * allows resuming the chain from where it left off instead of restarting
 * from the beginning.
 *
 * **Use Case:**
 * ```
 * Chain: [Step0, Step1, Step2, Step3, Step4]
 * - Execution starts, Step0 and Step1 complete successfully
 * - BGTask times out during Step2
 * - On next BGTask, resume from Step2 instead of Step0
 * ```
 *
 * **Retry Logic:**
 * - If a step fails, increment retryCount
 * - If retryCount >= maxRetries, abandon the chain
 * - This prevents infinite retry loops for permanently failing chains
 *
 * @property chainId Unique identifier for the chain
 * @property totalSteps Total number of steps in the chain
 * @property completedSteps Indices of successfully completed steps (e.g., [0, 1])
 * @property completedTasksInSteps Per-step tracking of which parallel task indices
 *   completed successfully. Keyed by step index; values are sorted task indices.
 *   Cleared for a step once that step is marked fully completed.
 * @property lastFailedStep Index of the step that last failed, if any
 * @property retryCount Number of times this chain has been retried
 * @property maxRetries Maximum retry attempts before abandoning (default: 3)
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMChainProgressCompanion *shared __attribute__((swift_name("shared")));

/**
 * Tracks the execution progress of a task chain on iOS.
 *
 * When a BGTask is interrupted (timeout, force-quit, etc.), this model
 * allows resuming the chain from where it left off instead of restarting
 * from the beginning.
 *
 * **Use Case:**
 * ```
 * Chain: [Step0, Step1, Step2, Step3, Step4]
 * - Execution starts, Step0 and Step1 complete successfully
 * - BGTask times out during Step2
 * - On next BGTask, resume from Step2 instead of Step0
 * ```
 *
 * **Retry Logic:**
 * - If a step fails, increment retryCount
 * - If retryCount >= maxRetries, abandon the chain
 * - This prevents infinite retry loops for permanently failing chains
 *
 * @property chainId Unique identifier for the chain
 * @property totalSteps Total number of steps in the chain
 * @property completedSteps Indices of successfully completed steps (e.g., [0, 1])
 * @property completedTasksInSteps Per-step tracking of which parallel task indices
 *   completed successfully. Keyed by step index; values are sorted task indices.
 *   Cleared for a step once that step is marked fully completed.
 * @property lastFailedStep Index of the step that last failed, if any
 * @property retryCount Number of times this chain has been retried
 * @property maxRetries Maximum retry attempts before abandoning (default: 3)
 */
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


/**
 * Custom exception for queue corruption
 * v2.1.3+
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("CorruptQueueException")))
@interface KMPWMCorruptQueueException : KMPWMKotlinException
- (instancetype)initWithMessage:(NSString *)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)new __attribute__((unavailable));
- (instancetype)initWithCause:(KMPWMKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(KMPWMKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@end


/**
 * Utility to read BGTaskSchedulerPermittedIdentifiers from Info.plist
 *
 * v4.0.0+: Dynamically validates task IDs against Info.plist configuration
 *
 * This eliminates the need to manually synchronize task IDs between:
 * - Info.plist BGTaskSchedulerPermittedIdentifiers
 * - Kotlin code permitted task IDs
 * - Swift BGTaskScheduler registration
 *
 * Example Info.plist:
 * ```xml
 * <key>BGTaskSchedulerPermittedIdentifiers</key>
 * <array>
 *     <string>kmp_chain_executor_task</string>
 *     <string>my-sync-task</string>
 *     <string>my-upload-task</string>
 * </array>
 * ```
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("InfoPlistReader")))
@interface KMPWMInfoPlistReader : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Utility to read BGTaskSchedulerPermittedIdentifiers from Info.plist
 *
 * v4.0.0+: Dynamically validates task IDs against Info.plist configuration
 *
 * This eliminates the need to manually synchronize task IDs between:
 * - Info.plist BGTaskSchedulerPermittedIdentifiers
 * - Kotlin code permitted task IDs
 * - Swift BGTaskScheduler registration
 *
 * Example Info.plist:
 * ```xml
 * <key>BGTaskSchedulerPermittedIdentifiers</key>
 * <array>
 *     <string>kmp_chain_executor_task</string>
 *     <string>my-sync-task</string>
 *     <string>my-upload-task</string>
 * </array>
 * ```
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)infoPlistReader __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMInfoPlistReader *shared __attribute__((swift_name("shared")));

/**
 * Validates that a task ID is present in Info.plist
 *
 * @param taskId Task identifier to validate
 * @return true if task ID is permitted, false otherwise
 */
- (BOOL)isTaskIdPermittedTaskId:(NSString *)taskId __attribute__((swift_name("isTaskIdPermitted(taskId:)")));

/**
 * Reads permitted task identifiers from Info.plist
 *
 * @return Set of permitted task IDs, or empty set if key not found
 */
- (NSSet<NSString *> *)readPermittedTaskIds __attribute__((swift_name("readPermittedTaskIds()")));
@end


/**
 * Exception thrown when insufficient disk space is available
 */
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


/**
 * Platform-agnostic worker interface.
 *
 * Implement this interface for each type of background work.
 * The actual platform implementation will wrap this:
 * - Android: Called from KmpWorker/KmpHeavyWorker/AlarmReceiver
 * - iOS: Implements IosWorker directly
 *
 * v2.3.0+: Changed return type from Boolean to WorkerResult for richer return values
 *
 * Example:
 * ```kotlin
 * class SyncWorker : Worker {
 *     override suspend fun doWork(input: String?): WorkerResult {
 *         return try {
 *             // Your sync logic here
 *             delay(2000)
 *             WorkerResult.Success(
 *                 message = "Sync completed",
 *                 data = mapOf("syncedItems" to 42)
 *             )
 *         } catch (e: Exception) {
 *             WorkerResult.Failure("Sync failed: ${e.message}")
 *         }
 *     }
 * }
 * ```
 */
__attribute__((swift_name("Worker")))
@protocol KMPWMWorker
@required

/**
 * Performs the background work.
 *
 * v2.3.0+: Return type changed from Boolean to WorkerResult
 *
 * @param input Optional input data passed from scheduler.enqueue()
 * @return WorkerResult indicating success/failure with optional data and message
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)doWorkInput:(NSString * _Nullable)input completionHandler:(void (^)(KMPWMWorkerResult * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("doWork(input:completionHandler:)")));
@end


/**
 * iOS Worker interface for background task execution.
 *
 * Implement this interface for each type of background work you want to perform on iOS.
 *
 * v2.3.0+: Changed return type from Boolean to WorkerResult
 * v4.0.0+: Now extends common Worker interface
 *
 * Example:
 * ```kotlin
 * class SyncWorker : IosWorker {
 *     override suspend fun doWork(input: String?): WorkerResult {
 *         return try {
 *             // Your sync logic here
 *             Logger.i(LogTags.WORKER, "Syncing data...")
 *             delay(2000)
 *             WorkerResult.Success(
 *                 message = "Sync completed",
 *                 data = mapOf("syncedCount" to 10)
 *             )
 *         } catch (e: Exception) {
 *             WorkerResult.Failure("Sync failed: ${e.message}")
 *         }
 *     }
 * }
 * ```
 */
__attribute__((swift_name("IosWorker")))
@protocol KMPWMIosWorker <KMPWMWorker>
@required
@end


/**
 * Platform-agnostic worker factory interface.
 *
 * Users implement this interface to provide their custom worker implementations.
 * The library uses this factory to instantiate workers at runtime based on class names.
 *
 * Example (Common code):
 * ```kotlin
 * class MyWorkerFactory : WorkerFactory {
 *     override fun createWorker(workerClassName: String): Worker? {
 *         return when (workerClassName) {
 *             "SyncWorker" -> SyncWorker()
 *             "UploadWorker" -> UploadWorker()
 *             else -> null
 *         }
 *     }
 * }
 * ```
 *
 * v4.0.0+: Replaces hardcoded worker registrations
 */
__attribute__((swift_name("WorkerFactory")))
@protocol KMPWMWorkerFactory
@required

/**
 * Creates a worker instance based on the class name.
 *
 * @param workerClassName The fully qualified class name or simple name
 * @return Worker instance or null if not found
 */
- (id<KMPWMWorker> _Nullable)createWorkerWorkerClassName:(NSString *)workerClassName __attribute__((swift_name("createWorker(workerClassName:)")));
@end


/**
 * Factory interface for creating iOS workers.
 *
 * Implement this to provide your custom worker implementations.
 *
 * v4.0.0+: Now extends common WorkerFactory interface
 *
 * Example:
 * ```kotlin
 * class MyWorkerFactory : IosWorkerFactory {
 *     override fun createWorker(workerClassName: String): IosWorker? {
 *         return when (workerClassName) {
 *             "SyncWorker" -> SyncWorker()
 *             "UploadWorker" -> UploadWorker()
 *             else -> null
 *         }
 *     }
 * }
 * ```
 */
__attribute__((swift_name("IosWorkerFactory")))
@protocol KMPWMIosWorkerFactory <KMPWMWorkerFactory>
@required
@end


/**
 * Result of migration operation
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("MigrationResult")))
@interface KMPWMMigrationResult : KMPWMBase
- (instancetype)initWithSuccess:(BOOL)success message:(NSString *)message chainsMigrated:(int32_t)chainsMigrated metadataMigrated:(int32_t)metadataMigrated __attribute__((swift_name("init(success:message:chainsMigrated:metadataMigrated:)"))) __attribute__((objc_designated_initializer));
- (KMPWMMigrationResult *)doCopySuccess:(BOOL)success message:(NSString *)message chainsMigrated:(int32_t)chainsMigrated metadataMigrated:(int32_t)metadataMigrated __attribute__((swift_name("doCopy(success:message:chainsMigrated:metadataMigrated:)")));

/**
 * Result of migration operation
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Result of migration operation
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Result of migration operation
 */
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int32_t chainsMigrated __attribute__((swift_name("chainsMigrated")));
@property (readonly) NSString *message __attribute__((swift_name("message")));
@property (readonly) int32_t metadataMigrated __attribute__((swift_name("metadataMigrated")));
@property (readonly) BOOL success __attribute__((swift_name("success")));
@end


/**
 * The primary contract (interface) for all background scheduling operations.
 * The rest of the application should only interact with this interface, ensuring a clean, platform-agnostic architecture.
 */
__attribute__((swift_name("BackgroundTaskScheduler")))
@protocol KMPWMBackgroundTaskScheduler
@required

/**
 * Begins a new task chain with a single initial task.
 * @param task The first [TaskRequest] in the chain.
 * @return A [TaskChain] builder instance to append more tasks.
 */
- (KMPWMTaskChain *)beginWithTask:(KMPWMTaskRequest *)task __attribute__((swift_name("beginWith(task:)")));

/**
 * Begins a new task chain with a group of tasks that will run in parallel.
 * @param tasks A list of [TaskRequest]s to run in parallel as the first step.
 * @return A [TaskChain] builder instance to append more tasks.
 */
- (KMPWMTaskChain *)beginWithTasks:(NSArray<KMPWMTaskRequest *> *)tasks __attribute__((swift_name("beginWith(tasks:)")));

/** Cancels a specific pending task by its unique ID. */
- (void)cancelId:(NSString *)id __attribute__((swift_name("cancel(id:)")));

/** Cancels all previously scheduled tasks currently managed by the scheduler. */
- (void)cancelAll __attribute__((swift_name("cancelAll()")));

/**
 * Enqueues a task to be executed in the background.
 * @param id A unique identifier for the task, used for cancellation and replacement.
 * @param trigger The condition that will trigger the task execution.
 * @param workerClassName A unique name identifying the actual work (Worker/Job) to be done on the platform.
 * @param constraints Conditions that must be met for the task to run. Defaults to no constraints.
 * @param inputJson Optional JSON string data to pass as input to the worker. Defaults to null.
 * @param policy How to handle this request if a task with the same ID already exists. Defaults to REPLACE.
 * @return The result of the scheduling operation (ACCEPTED, REJECTED, THROTTLED).
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)enqueueId:(NSString *)id trigger:(id<KMPWMTaskTrigger>)trigger workerClassName:(NSString *)workerClassName constraints:(KMPWMConstraints *)constraints inputJson:(NSString * _Nullable)inputJson policy:(KMPWMExistingPolicy *)policy completionHandler:(void (^)(KMPWMScheduleResult * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("enqueue(id:trigger:workerClassName:constraints:inputJson:policy:completionHandler:)")));

/**
 * Enqueues a constructed [TaskChain] for execution.
 * This method is intended to be called from `TaskChain.enqueue()`.
 *
 * @param chain The task chain to enqueue
 * @param id Unique identifier for the chain (optional, auto-generated if not provided)
 * @param policy How to handle if a chain with the same ID already exists
 */
- (void)enqueueChainChain:(KMPWMTaskChain *)chain id:(NSString * _Nullable)id policy:(KMPWMExistingPolicy *)policy __attribute__((swift_name("enqueueChain(chain:id:policy:)")));
@end


/**
 * iOS implementation of BackgroundTaskScheduler using BGTaskScheduler for background tasks
 * and UNUserNotificationCenter for exact time scheduling (via notifications).
 *
 * Key Features:
 * - BGAppRefreshTask for light tasks (≤30s)
 * - BGProcessingTask for heavy tasks (≤60s)
 * - File-based storage for improved performance and thread safety (v3.0.0+)
 * - Automatic migration from NSUserDefaults (v2.x)
 * - ExistingPolicy support (KEEP/REPLACE)
 * - Task ID validation against Info.plist
 * - Proper error handling with NSError
 *
 * **v2.2.0+ ChainExecutor Usage:**
 *
 * When registering BGTask handlers in Swift/Objective-C, specify the correct BGTaskType:
 *
 * ```swift
 * // For BGAppRefreshTask (30s limit)
 * BGTaskScheduler.shared.register(forTaskWithIdentifier: "app.refresh") { task in
 *     let executor = ChainExecutor(
 *         workerFactory: factory,
 *         taskType: BGTaskType.appRefresh  // ← 20s task timeout, 50s chain timeout
 *     )
 *     // ... execute chains ...
 * }
 *
 * // For BGProcessingTask (5-10 min limit)
 * BGTaskScheduler.shared.register(forTaskWithIdentifier: "chain.processor") { task in
 *     let executor = ChainExecutor(
 *         workerFactory: factory,
 *         taskType: BGTaskType.processing  // ← 120s task timeout, 300s chain timeout
 *     )
 *     // ... execute chains ...
 * }
 * ```
 */
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


/**
 * Executes a single, non-chained background task on the iOS platform.
 *
 * Features:
 * - Automatic timeout protection (25s for BGAppRefreshTask, 55s for BGProcessingTask)
 * - Comprehensive error handling and logging
 * - Task completion event emission
 * - Memory-safe coroutine scope management
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SingleTaskExecutor")))
@interface KMPWMSingleTaskExecutor : KMPWMBase
- (instancetype)initWithWorkerFactory:(id<KMPWMIosWorkerFactory>)workerFactory __attribute__((swift_name("init(workerFactory:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMSingleTaskExecutorCompanion *companion __attribute__((swift_name("companion")));

/**
 * Cleanup coroutine scope (call when executor is no longer needed)
 */
- (void)cleanup __attribute__((swift_name("cleanup()")));

/**
 * Creates and runs a worker based on its class name with timeout protection.
 *
 * v2.3.0+: Returns WorkerResult with data instead of Boolean
 *
 * @param workerClassName The fully qualified name of the worker class.
 * @param input Optional input data for the worker.
 * @param timeoutMs Maximum execution time in milliseconds (default: 25s)
 * @return WorkerResult with success/failure status and optional data
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)executeTaskWorkerClassName:(NSString *)workerClassName input:(NSString * _Nullable)input timeoutMs:(int64_t)timeoutMs completionHandler:(void (^)(KMPWMWorkerResult * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("executeTask(workerClassName:input:timeoutMs:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SingleTaskExecutor.Companion")))
@interface KMPWMSingleTaskExecutorCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMSingleTaskExecutorCompanion *shared __attribute__((swift_name("shared")));

/**
 * Default timeout for task execution (25 seconds)
 * Provides 5s safety margin for BGAppRefreshTask (30s limit)
 * BGProcessingTask has 60s limit, so this is even safer
 */
@property (readonly) int64_t DEFAULT_TIMEOUT_MS __attribute__((swift_name("DEFAULT_TIMEOUT_MS")));
@end


/**
 * Object containing unique string identifiers for various background tasks.
 * The @ObjCName annotation ensures the object is easily accessible from Swift/Objective-C code.
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskIds")))
@interface KMPWMTaskIds : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Object containing unique string identifiers for various background tasks.
 * The @ObjCName annotation ensures the object is easily accessible from Swift/Objective-C code.
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)taskIds __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMTaskIds *shared __attribute__((swift_name("shared")));
@property (readonly) NSString *EXACT_REMINDER __attribute__((swift_name("EXACT_REMINDER")));
@property (readonly) NSString *HEAVY_TASK_1 __attribute__((swift_name("HEAVY_TASK_1")));
@property (readonly) NSString *ONE_TIME_UPLOAD __attribute__((swift_name("ONE_TIME_UPLOAD")));
@property (readonly) NSString *PERIODIC_SYNC_TASK __attribute__((swift_name("PERIODIC_SYNC_TASK")));
@end


/**
 * DEPRECATED in v4.0.0
 *
 * WorkerTypes contained example worker class names that should be in user applications.
 *
 * Migration:
 * Define your own worker identifiers as constants in your app code.
 * ```kotlin
 * // In your app
 * object MyWorkers {
 *     const val SYNC = "SyncWorker"
 *     const val UPLOAD = "UploadWorker"
 * }
 * ```
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("WorkerTypes")))
@interface KMPWMWorkerTypes : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * DEPRECATED in v4.0.0
 *
 * WorkerTypes contained example worker class names that should be in user applications.
 *
 * Migration:
 * Define your own worker identifiers as constants in your app code.
 * ```kotlin
 * // In your app
 * object MyWorkers {
 *     const val SYNC = "SyncWorker"
 *     const val UPLOAD = "UploadWorker"
 * }
 * ```
 */
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


/**
 * iOS Background Task types with different time limits
 *
 * **BGAppRefreshTask:**
 * - Time limit: ~30 seconds
 * - Frequency: System determines (typically every few hours)
 * - Use for: Quick sync, lightweight updates
 * - Restrictions: More aggressive time limit
 *
 * **BGProcessingTask:**
 * - Time limit: 5-10 minutes (up to 30 minutes on power + WiFi)
 * - Frequency: Less frequent, runs when system has resources
 * - Use for: Heavy processing, large uploads/downloads
 * - Restrictions: May not run if battery low or device in use
 *
 * @see [Apple Documentation](https://developer.apple.com/documentation/backgroundtasks)
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("BGTaskType")))
@interface KMPWMBGTaskType : KMPWMKotlinEnum<KMPWMBGTaskType *>
+ (instancetype)alloc __attribute__((unavailable));

/**
 * iOS Background Task types with different time limits
 *
 * **BGAppRefreshTask:**
 * - Time limit: ~30 seconds
 * - Frequency: System determines (typically every few hours)
 * - Use for: Quick sync, lightweight updates
 * - Restrictions: More aggressive time limit
 *
 * **BGProcessingTask:**
 * - Time limit: 5-10 minutes (up to 30 minutes on power + WiFi)
 * - Frequency: Less frequent, runs when system has resources
 * - Use for: Heavy processing, large uploads/downloads
 * - Restrictions: May not run if battery low or device in use
 *
 * @see [Apple Documentation](https://developer.apple.com/documentation/backgroundtasks)
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) KMPWMBGTaskType *appRefresh __attribute__((swift_name("appRefresh")));
@property (class, readonly) KMPWMBGTaskType *processing __attribute__((swift_name("processing")));
+ (KMPWMKotlinArray<KMPWMBGTaskType *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<KMPWMBGTaskType *> *entries __attribute__((swift_name("entries")));
@end


/**
 * Backoff policy for task retry behavior.
 *
 * Used by Android WorkManager to determine retry intervals when tasks fail.
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("BackoffPolicy")))
@interface KMPWMBackoffPolicy : KMPWMKotlinEnum<KMPWMBackoffPolicy *>
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Backoff policy for task retry behavior.
 *
 * Used by Android WorkManager to determine retry intervals when tasks fail.
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) KMPWMBackoffPolicy *linear __attribute__((swift_name("linear")));
@property (class, readonly) KMPWMBackoffPolicy *exponential __attribute__((swift_name("exponential")));
+ (KMPWMKotlinArray<KMPWMBackoffPolicy *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<KMPWMBackoffPolicy *> *entries __attribute__((swift_name("entries")));
@end


/**
 * Defines the constraints under which a background task can run.
 *
 * Constraints allow fine-grained control over when tasks execute,
 * helping optimize battery life and network usage.
 *
 * **Platform Support**:
 * - Most constraints work on both platforms
 * - Some are platform-specific (see individual field docs)
 *
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Constraints")))
@interface KMPWMConstraints : KMPWMBase
- (instancetype)initWithRequiresNetwork:(BOOL)requiresNetwork requiresUnmeteredNetwork:(BOOL)requiresUnmeteredNetwork requiresCharging:(BOOL)requiresCharging allowWhileIdle:(BOOL)allowWhileIdle qos:(KMPWMQos *)qos isHeavyTask:(BOOL)isHeavyTask backoffPolicy:(KMPWMBackoffPolicy *)backoffPolicy backoffDelayMs:(int64_t)backoffDelayMs systemConstraints:(NSSet<KMPWMSystemConstraint *> *)systemConstraints exactAlarmIOSBehavior:(KMPWMExactAlarmIOSBehavior *)exactAlarmIOSBehavior __attribute__((swift_name("init(requiresNetwork:requiresUnmeteredNetwork:requiresCharging:allowWhileIdle:qos:isHeavyTask:backoffPolicy:backoffDelayMs:systemConstraints:exactAlarmIOSBehavior:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMConstraintsCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMConstraints *)doCopyRequiresNetwork:(BOOL)requiresNetwork requiresUnmeteredNetwork:(BOOL)requiresUnmeteredNetwork requiresCharging:(BOOL)requiresCharging allowWhileIdle:(BOOL)allowWhileIdle qos:(KMPWMQos *)qos isHeavyTask:(BOOL)isHeavyTask backoffPolicy:(KMPWMBackoffPolicy *)backoffPolicy backoffDelayMs:(int64_t)backoffDelayMs systemConstraints:(NSSet<KMPWMSystemConstraint *> *)systemConstraints exactAlarmIOSBehavior:(KMPWMExactAlarmIOSBehavior *)exactAlarmIOSBehavior __attribute__((swift_name("doCopy(requiresNetwork:requiresUnmeteredNetwork:requiresCharging:allowWhileIdle:qos:isHeavyTask:backoffPolicy:backoffDelayMs:systemConstraints:exactAlarmIOSBehavior:)")));

/**
 * Defines the constraints under which a background task can run.
 *
 * Constraints allow fine-grained control over when tasks execute,
 * helping optimize battery life and network usage.
 *
 * **Platform Support**:
 * - Most constraints work on both platforms
 * - Some are platform-specific (see individual field docs)
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Defines the constraints under which a background task can run.
 *
 * Constraints allow fine-grained control over when tasks execute,
 * helping optimize battery life and network usage.
 *
 * **Platform Support**:
 * - Most constraints work on both platforms
 * - Some are platform-specific (see individual field docs)
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Defines the constraints under which a background task can run.
 *
 * Constraints allow fine-grained control over when tasks execute,
 * helping optimize battery life and network usage.
 *
 * **Platform Support**:
 * - Most constraints work on both platforms
 * - Some are platform-specific (see individual field docs)
 */
- (NSString *)description __attribute__((swift_name("description()")));

/**
 * Hint to allow execution during device idle/doze mode - **ANDROID ONLY**.
 *
 * **Android**: Used with AlarmManager's `setExactAndAllowWhileIdle()`
 * **iOS**: Not applicable (iOS decides execution timing)
 *
 * **Note**: This is a HINT, not a guarantee. System may still defer.
 *
 * Default: false
 */
@property (readonly) BOOL allowWhileIdle __attribute__((swift_name("allowWhileIdle")));

/**
 * Initial backoff delay in milliseconds when task fails - **ANDROID ONLY**.
 *
 * **Android**: Starting delay before first retry
 * - Minimum: 10,000ms (10 seconds)
 * - Subsequent retries follow backoffPolicy
 *
 * **iOS**: Not applicable
 *
 * **Example**:
 * ```kotlin
 * Constraints(
 *     backoffPolicy = BackoffPolicy.EXPONENTIAL,
 *     backoffDelayMs = 30_000  // Start with 30s, then 60s, 120s, ...
 * )
 * ```
 *
 * Default: 30,000ms (30 seconds)
 */
@property (readonly) int64_t backoffDelayMs __attribute__((swift_name("backoffDelayMs")));

/**
 * Backoff policy when task fails and needs retry - **ANDROID ONLY**.
 *
 * **Android**: Determines retry behavior for failed WorkManager tasks
 * - `EXPONENTIAL`: Delay doubles after each retry (30s, 60s, 120s, ...)
 * - `LINEAR`: Constant delay between retries
 *
 * **iOS**: Not applicable (manual retry required)
 *
 * Default: BackoffPolicy.EXPONENTIAL
 */
@property (readonly) KMPWMBackoffPolicy *backoffPolicy __attribute__((swift_name("backoffPolicy")));

/**
 * iOS-specific behavior for TaskTrigger.Exact alarms - **iOS ONLY**.
 *
 * **v2.1.1+**: Added to provide transparency about iOS exact alarm limitations.
 *
 * **Problem**: iOS does NOT support background code execution at exact times.
 * Android can execute worker code via AlarmManager, but iOS can only:
 * 1. Show notifications (SHOW_NOTIFICATION)
 * 2. Attempt opportunistic background run (ATTEMPT_BACKGROUND_RUN - not guaranteed)
 * 3. Throw error to force developer awareness (THROW_ERROR)
 *
 * **Android**: This field is ignored (Android always executes worker code)
 * **iOS**: Determines how TaskTrigger.Exact is handled
 *
 * **Migration from v2.1.0**:
 * - Old behavior: iOS always showed notification (silent, undocumented)
 * - New behavior: Explicit configuration with fail-fast option
 *
 * **Example - Notification-based (Safe Default)**:
 * ```kotlin
 * scheduler.enqueue(
 *     id = "morning-alarm",
 *     trigger = TaskTrigger.Exact(morningTime),
 *     workerClassName = "AlarmWorker", // Ignored on iOS
 *     constraints = Constraints(
 *         exactAlarmIOSBehavior = ExactAlarmIOSBehavior.SHOW_NOTIFICATION // Default
 *     )
 * )
 * ```
 *
 * **Example - Fail Fast (Development)**:
 * ```kotlin
 * scheduler.enqueue(
 *     id = "critical-task",
 *     trigger = TaskTrigger.Exact(criticalTime),
 *     workerClassName = "CriticalWorker",
 *     constraints = Constraints(
 *         exactAlarmIOSBehavior = ExactAlarmIOSBehavior.THROW_ERROR
 *     )
 * )
 * // Throws on iOS: "iOS does not support exact alarms for code execution"
 * ```
 *
 * Default: ExactAlarmIOSBehavior.SHOW_NOTIFICATION
 */
@property (readonly) KMPWMExactAlarmIOSBehavior *exactAlarmIOSBehavior __attribute__((swift_name("exactAlarmIOSBehavior")));

/**
 * Indicates this is a long-running or heavy task requiring special handling.
 *
 * **Android**: Uses ForegroundService with persistent notification
 * - Task can run indefinitely while service is foreground
 * - Prevents system from killing the task
 * - Requires `FOREGROUND_SERVICE` permission
 * - Shows persistent notification to user
 *
 * **iOS**: Uses `BGProcessingTask` (≤60s) instead of `BGAppRefreshTask` (≤30s)
 * - Double the execution time limit
 * - Better for CPU-intensive work
 * - Still limited by iOS (no indefinite execution)
 *
 * **Use Cases**: File upload, video processing, prime calculation
 *
 * Default: false
 */
@property (readonly) BOOL isHeavyTask __attribute__((swift_name("isHeavyTask")));

/**
 * Quality of Service hint for task priority - **iOS ONLY**.
 *
 * **iOS**: Maps to `DispatchQoS` for task execution priority:
 * - `Utility`: Low priority, user not waiting
 * - `Background`: Default, deferred execution
 * - `UserInitiated`: Important, user may be waiting
 * - `UserInteractive`: Critical, user actively waiting
 *
 * **Android**: Ignored (WorkManager handles priority automatically)
 *
 * Default: Qos.Background
 */
@property (readonly) KMPWMQos *qos __attribute__((swift_name("qos")));

/**
 * Requires device to be charging.
 *
 * **Android**: Uses `setRequiresCharging(true)` constraint
 * **iOS**: Uses `requiresExternalPower` on `BGProcessingTask` only
 *          (BGAppRefreshTask doesn't support charging constraint)
 *
 * **Use Cases**: Heavy processing, large syncs
 *
 * Default: false
 */
@property (readonly) BOOL requiresCharging __attribute__((swift_name("requiresCharging")));

/**
 * Requires any type of network connectivity (Wi-Fi, cellular, etc.).
 *
 * **Android**: Uses `NetworkType.CONNECTED` constraint
 * **iOS**: Uses `requiresNetworkConnectivity` on `BGProcessingTask` only
 *          (BGAppRefreshTask doesn't support network constraint)
 *
 * Default: false
 */
@property (readonly) BOOL requiresNetwork __attribute__((swift_name("requiresNetwork")));

/**
 * Requires unmetered network (typically Wi-Fi) - **ANDROID ONLY**.
 *
 * **Android**: Uses `NetworkType.UNMETERED` constraint
 * **iOS**: Not supported, falls back to `requiresNetwork`
 *
 * **Use Cases**: Large uploads/downloads, video processing
 *
 * Default: false
 */
@property (readonly) BOOL requiresUnmeteredNetwork __attribute__((swift_name("requiresUnmeteredNetwork")));

/**
 * System-level constraints for task execution - **ANDROID ONLY**.
 *
 * **v3.0.0+**: Replaces deprecated TaskTrigger variants (BatteryLow, StorageLow, etc.)
 *
 * **Android**: Maps to WorkManager constraint methods:
 * - `ALLOW_LOW_STORAGE` → `setRequiresStorageNotLow(false)`
 * - `ALLOW_LOW_BATTERY` → `setRequiresBatteryNotLow(false)`
 * - `REQUIRE_BATTERY_NOT_LOW` → `setRequiresBatteryNotLow(true)`
 * - `DEVICE_IDLE` → `setRequiresDeviceIdle(true)`
 *
 * **iOS**: Ignored (no equivalent constraints)
 *
 * **Example**:
 * ```kotlin
 * Constraints(
 *     systemConstraints = setOf(
 *         SystemConstraint.DEVICE_IDLE,
 *         SystemConstraint.REQUIRE_BATTERY_NOT_LOW
 *     )
 * )
 * ```
 *
 * Default: emptySet()
 */
@property (readonly) NSSet<KMPWMSystemConstraint *> *systemConstraints __attribute__((swift_name("systemConstraints")));
@end


/**
 * Defines the constraints under which a background task can run.
 *
 * Constraints allow fine-grained control over when tasks execute,
 * helping optimize battery life and network usage.
 *
 * **Platform Support**:
 * - Most constraints work on both platforms
 * - Some are platform-specific (see individual field docs)
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Constraints.Companion")))
@interface KMPWMConstraintsCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Defines the constraints under which a background task can run.
 *
 * Constraints allow fine-grained control over when tasks execute,
 * helping optimize battery life and network usage.
 *
 * **Platform Support**:
 * - Most constraints work on both platforms
 * - Some are platform-specific (see individual field docs)
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMConstraintsCompanion *shared __attribute__((swift_name("shared")));

/**
 * Defines the constraints under which a background task can run.
 *
 * Constraints allow fine-grained control over when tasks execute,
 * helping optimize battery life and network usage.
 *
 * **Platform Support**:
 * - Most constraints work on both platforms
 * - Some are platform-specific (see individual field docs)
 */
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * Manager for synchronizing missed events on app launch.
 *
 * When the app starts, this manager retrieves all unconsumed events
 * from persistent storage and replays them to the EventBus so the UI
 * can process events that were emitted while the app was not running.
 *
 * Usage:
 * ```kotlin
 * // In Application.onCreate() (Android) or @main (iOS)
 * class MyApplication : Application() {
 *     override fun onCreate() {
 *         super.onCreate()
 *         // Initialize EventStore first
 *         val eventStore = AndroidEventStore(this)
 *         TaskEventManager.initialize(eventStore)
 *
 *         // Sync missed events
 *         lifecycleScope.launch {
 *             EventSyncManager.syncEvents(eventStore)
 *         }
 *     }
 * }
 * ```
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("EventSyncManager")))
@interface KMPWMEventSyncManager : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Manager for synchronizing missed events on app launch.
 *
 * When the app starts, this manager retrieves all unconsumed events
 * from persistent storage and replays them to the EventBus so the UI
 * can process events that were emitted while the app was not running.
 *
 * Usage:
 * ```kotlin
 * // In Application.onCreate() (Android) or @main (iOS)
 * class MyApplication : Application() {
 *     override fun onCreate() {
 *         super.onCreate()
 *         // Initialize EventStore first
 *         val eventStore = AndroidEventStore(this)
 *         TaskEventManager.initialize(eventStore)
 *
 *         // Sync missed events
 *         lifecycleScope.launch {
 *             EventSyncManager.syncEvents(eventStore)
 *         }
 *     }
 * }
 * ```
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)eventSyncManager __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMEventSyncManager *shared __attribute__((swift_name("shared")));

/**
 * Clears old events from storage.
 * Useful for periodic cleanup or manual maintenance.
 *
 * @param eventStore The EventStore instance
 * @param olderThanMs Events older than this timestamp will be deleted
 * @return Number of events deleted
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)clearOldEventsEventStore:(id<KMPWMEventStore>)eventStore olderThanMs:(int64_t)olderThanMs completionHandler:(void (^)(KMPWMInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("clearOldEvents(eventStore:olderThanMs:completionHandler:)")));

/**
 * Synchronizes missed events from persistent storage to EventBus.
 *
 * Flow:
 * 1. Retrieves all unconsumed events from EventStore
 * 2. Replays them to EventBus in chronological order
 * 3. Logs sync statistics
 *
 * @param eventStore The EventStore instance to sync from
 * @return Number of events synchronized
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)syncEventsEventStore:(id<KMPWMEventStore>)eventStore completionHandler:(void (^)(KMPWMInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("syncEvents(eventStore:completionHandler:)")));
@end


/**
 * iOS-specific behavior for TaskTrigger.Exact alarms.
 *
 * **Background**: iOS does not allow background code execution at exact times due to strict
 * background execution policies. This enum provides transparency and control over how exact
 * alarms are handled on iOS.
 *
 * **v2.1.1+**: Added to address platform parity issues and prevent silent failures.
 *
 * **Platform Support**: iOS only (Android always executes code)
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExactAlarmIOSBehavior")))
@interface KMPWMExactAlarmIOSBehavior : KMPWMKotlinEnum<KMPWMExactAlarmIOSBehavior *>
+ (instancetype)alloc __attribute__((unavailable));

/**
 * iOS-specific behavior for TaskTrigger.Exact alarms.
 *
 * **Background**: iOS does not allow background code execution at exact times due to strict
 * background execution policies. This enum provides transparency and control over how exact
 * alarms are handled on iOS.
 *
 * **v2.1.1+**: Added to address platform parity issues and prevent silent failures.
 *
 * **Platform Support**: iOS only (Android always executes code)
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) KMPWMExactAlarmIOSBehavior *showNotification __attribute__((swift_name("showNotification")));
@property (class, readonly) KMPWMExactAlarmIOSBehavior *attemptBackgroundRun __attribute__((swift_name("attemptBackgroundRun")));
@property (class, readonly) KMPWMExactAlarmIOSBehavior *throwError __attribute__((swift_name("throwError")));
+ (KMPWMKotlinArray<KMPWMExactAlarmIOSBehavior *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<KMPWMExactAlarmIOSBehavior *> *entries __attribute__((swift_name("entries")));
@end


/**
 * Policy for handling a new task when one with the same ID already exists.
 *
 * **Both platforms**: Enforced at scheduling time
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ExistingPolicy")))
@interface KMPWMExistingPolicy : KMPWMKotlinEnum<KMPWMExistingPolicy *>
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Policy for handling a new task when one with the same ID already exists.
 *
 * **Both platforms**: Enforced at scheduling time
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) KMPWMExistingPolicy *keep __attribute__((swift_name("keep")));
@property (class, readonly) KMPWMExistingPolicy *replace __attribute__((swift_name("replace")));
+ (KMPWMKotlinArray<KMPWMExistingPolicy *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<KMPWMExistingPolicy *> *entries __attribute__((swift_name("entries")));
@end


/**
 * Interface for receiving progress updates from workers.
 *
 * This is typically implemented by the platform-specific scheduler
 * to emit progress events to the UI via TaskEventBus.
 */
__attribute__((swift_name("ProgressListener")))
@protocol KMPWMProgressListener
@required

/**
 * Called when a worker reports progress.
 *
 * @param progress The current progress state
 */
- (void)onProgressUpdateProgress:(KMPWMWorkerProgress *)progress __attribute__((swift_name("onProgressUpdate(progress:)")));
@end


/**
 * Quality of Service (QoS) enumeration for task priority.
 *
 * Primarily used as a hint for iOS's DispatchQoS task priority system.
 * Android WorkManager handles priority automatically based on constraints.
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Qos")))
@interface KMPWMQos : KMPWMKotlinEnum<KMPWMQos *>
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Quality of Service (QoS) enumeration for task priority.
 *
 * Primarily used as a hint for iOS's DispatchQoS task priority system.
 * Android WorkManager handles priority automatically based on constraints.
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) KMPWMQos *utility __attribute__((swift_name("utility")));
@property (class, readonly) KMPWMQos *background __attribute__((swift_name("background")));
@property (class, readonly) KMPWMQos *userinitiated __attribute__((swift_name("userinitiated")));
@property (class, readonly) KMPWMQos *userinteractive __attribute__((swift_name("userinteractive")));
+ (KMPWMKotlinArray<KMPWMQos *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<KMPWMQos *> *entries __attribute__((swift_name("entries")));
@end


/**
 * Result of a task scheduling operation.
 *
 * Indicates whether the OS accepted, rejected, or throttled the request.
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ScheduleResult")))
@interface KMPWMScheduleResult : KMPWMKotlinEnum<KMPWMScheduleResult *>
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Result of a task scheduling operation.
 *
 * Indicates whether the OS accepted, rejected, or throttled the request.
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) KMPWMScheduleResult *accepted __attribute__((swift_name("accepted")));
@property (class, readonly) KMPWMScheduleResult *rejectedOsPolicy __attribute__((swift_name("rejectedOsPolicy")));
@property (class, readonly) KMPWMScheduleResult *throttled __attribute__((swift_name("throttled")));
+ (KMPWMKotlinArray<KMPWMScheduleResult *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<KMPWMScheduleResult *> *entries __attribute__((swift_name("entries")));
@end


/**
 * Scheduler readiness and queue status
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SchedulerStatus")))
@interface KMPWMSchedulerStatus : KMPWMBase
- (instancetype)initWithIsReady:(BOOL)isReady totalPendingTasks:(int32_t)totalPendingTasks queueSize:(int32_t)queueSize platform:(NSString *)platform timestamp:(int64_t)timestamp __attribute__((swift_name("init(isReady:totalPendingTasks:queueSize:platform:timestamp:)"))) __attribute__((objc_designated_initializer));
- (KMPWMSchedulerStatus *)doCopyIsReady:(BOOL)isReady totalPendingTasks:(int32_t)totalPendingTasks queueSize:(int32_t)queueSize platform:(NSString *)platform timestamp:(int64_t)timestamp __attribute__((swift_name("doCopy(isReady:totalPendingTasks:queueSize:platform:timestamp:)")));

/**
 * Scheduler readiness and queue status
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Scheduler readiness and queue status
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Scheduler readiness and queue status
 */
- (NSString *)description __attribute__((swift_name("description()")));

/**
 * Is scheduler initialized and ready?
 */
@property (readonly) BOOL isReady __attribute__((swift_name("isReady")));

/**
 * Platform identifier (ios, android)
 */
@property (readonly) NSString *platform __attribute__((swift_name("platform")));

/**
 * Queue size (chain queue for iOS, work queue for Android)
 */
@property (readonly) int32_t queueSize __attribute__((swift_name("queueSize")));

/**
 * Timestamp of status snapshot (epoch milliseconds)
 */
@property (readonly) int64_t timestamp __attribute__((swift_name("timestamp")));

/**
 * Total pending tasks in queue
 */
@property (readonly) int32_t totalPendingTasks __attribute__((swift_name("totalPendingTasks")));
@end


/**
 * System-level constraints for task execution.
 * These are conditions that must be met for a task to run.
 *
 * **Platform Support**: Android only (iOS ignores these)
 *
 * **v3.0.0+**: Replaces deprecated TaskTrigger variants (BatteryLow, StorageLow, etc.)
 * which incorrectly represented constraints as triggers.
 *
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SystemConstraint")))
@interface KMPWMSystemConstraint : KMPWMKotlinEnum<KMPWMSystemConstraint *>
+ (instancetype)alloc __attribute__((unavailable));

/**
 * System-level constraints for task execution.
 * These are conditions that must be met for a task to run.
 *
 * **Platform Support**: Android only (iOS ignores these)
 *
 * **v3.0.0+**: Replaces deprecated TaskTrigger variants (BatteryLow, StorageLow, etc.)
 * which incorrectly represented constraints as triggers.
 */
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


/**
 * System-level constraints for task execution.
 * These are conditions that must be met for a task to run.
 *
 * **Platform Support**: Android only (iOS ignores these)
 *
 * **v3.0.0+**: Replaces deprecated TaskTrigger variants (BatteryLow, StorageLow, etc.)
 * which incorrectly represented constraints as triggers.
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SystemConstraint.Companion")))
@interface KMPWMSystemConstraintCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * System-level constraints for task execution.
 * These are conditions that must be met for a task to run.
 *
 * **Platform Support**: Android only (iOS ignores these)
 *
 * **v3.0.0+**: Replaces deprecated TaskTrigger variants (BatteryLow, StorageLow, etc.)
 * which incorrectly represented constraints as triggers.
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMSystemConstraintCompanion *shared __attribute__((swift_name("shared")));

/**
 * System-level constraints for task execution.
 * These are conditions that must be met for a task to run.
 *
 * **Platform Support**: Android only (iOS ignores these)
 *
 * **v3.0.0+**: Replaces deprecated TaskTrigger variants (BatteryLow, StorageLow, etc.)
 * which incorrectly represented constraints as triggers.
 */
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));

/**
 * System-level constraints for task execution.
 * These are conditions that must be met for a task to run.
 *
 * **Platform Support**: Android only (iOS ignores these)
 *
 * **v3.0.0+**: Replaces deprecated TaskTrigger variants (BatteryLow, StorageLow, etc.)
 * which incorrectly represented constraints as triggers.
 */
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializerTypeParamsSerializers:(KMPWMKotlinArray<id<KMPWMKotlinx_serialization_coreKSerializer>> *)typeParamsSerializers __attribute__((swift_name("serializer(typeParamsSerializers:)")));
@end


/**
 * System health metrics affecting task execution
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SystemHealthReport")))
@interface KMPWMSystemHealthReport : KMPWMBase
- (instancetype)initWithTimestamp:(int64_t)timestamp batteryLevel:(int32_t)batteryLevel isCharging:(BOOL)isCharging networkAvailable:(BOOL)networkAvailable storageAvailable:(int64_t)storageAvailable isStorageLow:(BOOL)isStorageLow isLowPowerMode:(BOOL)isLowPowerMode deviceInDozeMode:(BOOL)deviceInDozeMode __attribute__((swift_name("init(timestamp:batteryLevel:isCharging:networkAvailable:storageAvailable:isStorageLow:isLowPowerMode:deviceInDozeMode:)"))) __attribute__((objc_designated_initializer));
- (KMPWMSystemHealthReport *)doCopyTimestamp:(int64_t)timestamp batteryLevel:(int32_t)batteryLevel isCharging:(BOOL)isCharging networkAvailable:(BOOL)networkAvailable storageAvailable:(int64_t)storageAvailable isStorageLow:(BOOL)isStorageLow isLowPowerMode:(BOOL)isLowPowerMode deviceInDozeMode:(BOOL)deviceInDozeMode __attribute__((swift_name("doCopy(timestamp:batteryLevel:isCharging:networkAvailable:storageAvailable:isStorageLow:isLowPowerMode:deviceInDozeMode:)")));

/**
 * System health metrics affecting task execution
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * System health metrics affecting task execution
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * System health metrics affecting task execution
 */
- (NSString *)description __attribute__((swift_name("description()")));

/**
 * Battery level (0-100%)
 */
@property (readonly) int32_t batteryLevel __attribute__((swift_name("batteryLevel")));

/**
 * Android: Is device in doze mode?
 * iOS: Always false
 */
@property (readonly) BOOL deviceInDozeMode __attribute__((swift_name("deviceInDozeMode")));

/**
 * Is device charging?
 */
@property (readonly) BOOL isCharging __attribute__((swift_name("isCharging")));

/**
 * iOS: Is device in low power mode?
 * Android: Always false
 */
@property (readonly) BOOL isLowPowerMode __attribute__((swift_name("isLowPowerMode")));

/**
 * Is storage critically low? (<500MB)
 */
@property (readonly) BOOL isStorageLow __attribute__((swift_name("isStorageLow")));

/**
 * Is network available?
 */
@property (readonly) BOOL networkAvailable __attribute__((swift_name("networkAvailable")));

/**
 * Available storage (bytes)
 */
@property (readonly) int64_t storageAvailable __attribute__((swift_name("storageAvailable")));

/**
 * Timestamp of health check (epoch milliseconds)
 */
@property (readonly) int64_t timestamp __attribute__((swift_name("timestamp")));
@end


/**
 * A builder class for creating a chain of background tasks.
 *
 * This class is not meant to be instantiated directly. Use `BackgroundTaskScheduler.beginWith()` to start a chain.
 * It allows for creating sequential and parallel groups of tasks.
 *
 * @property scheduler The scheduler instance used to enqueue the chain.
 * @property steps A mutable list where each element is a list of tasks to be run in parallel at that step.
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskChain")))
@interface KMPWMTaskChain : KMPWMBase

/**
 * Enqueues the constructed task chain for execution.
 * The actual scheduling is delegated to the `BackgroundTaskScheduler`.
 */
- (void)enqueue __attribute__((swift_name("enqueue()")));

/**
 * Appends a single task to be executed sequentially after all previous tasks in the chain have completed.
 *
 * @param task The [TaskRequest] to add to the chain.
 * @return The current [TaskChain] instance for fluent chaining.
 */
- (KMPWMTaskChain *)thenTask:(KMPWMTaskRequest *)task __attribute__((swift_name("then(task:)")));

/**
 * Appends a group of tasks to be executed in parallel after all previous tasks in the chain have completed.
 *
 * @param tasks A list of [TaskRequest]s to add to the chain.
 * @return The current [TaskChain] instance for fluent chaining.
 * @throws IllegalArgumentException if the tasks list is empty.
 */
- (KMPWMTaskChain *)thenTasks:(NSArray<KMPWMTaskRequest *> *)tasks __attribute__((swift_name("then(tasks:)")));

/**
 * Sets a unique ID for this chain and specifies the ExistingPolicy.
 *
 * @param id Unique identifier for the chain
 * @param policy How to handle if a chain with this ID already exists
 * @return A new [TaskChain] instance with the specified ID and policy
 */
- (KMPWMTaskChain *)withIdId:(NSString *)id policy:(KMPWMExistingPolicy *)policy __attribute__((swift_name("withId(id:policy:)")));
@end


/**
 * Event emitted when a background task completes.
 *
 * v2.3.0+: Added outputData field to support returning data from workers
 *
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskCompletionEvent")))
@interface KMPWMTaskCompletionEvent : KMPWMBase
- (instancetype)initWithTaskName:(NSString *)taskName success:(BOOL)success message:(NSString *)message outputData:(NSDictionary<NSString *, id> * _Nullable)outputData __attribute__((swift_name("init(taskName:success:message:outputData:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMTaskCompletionEventCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMTaskCompletionEvent *)doCopyTaskName:(NSString *)taskName success:(BOOL)success message:(NSString *)message outputData:(NSDictionary<NSString *, id> * _Nullable)outputData __attribute__((swift_name("doCopy(taskName:success:message:outputData:)")));

/**
 * Event emitted when a background task completes.
 *
 * v2.3.0+: Added outputData field to support returning data from workers
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Event emitted when a background task completes.
 *
 * v2.3.0+: Added outputData field to support returning data from workers
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Event emitted when a background task completes.
 *
 * v2.3.0+: Added outputData field to support returning data from workers
 */
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *message __attribute__((swift_name("message")));
@property (readonly) NSDictionary<NSString *, id> * _Nullable outputData __attribute__((swift_name("outputData")));
@property (readonly) BOOL success __attribute__((swift_name("success")));
@property (readonly) NSString *taskName __attribute__((swift_name("taskName")));
@end


/**
 * Event emitted when a background task completes.
 *
 * v2.3.0+: Added outputData field to support returning data from workers
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskCompletionEvent.Companion")))
@interface KMPWMTaskCompletionEventCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Event emitted when a background task completes.
 *
 * v2.3.0+: Added outputData field to support returning data from workers
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMTaskCompletionEventCompanion *shared __attribute__((swift_name("shared")));

/**
 * Event emitted when a background task completes.
 *
 * v2.3.0+: Added outputData field to support returning data from workers
 */
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * Global event bus for task completion events.
 * Workers can emit events here, and the UI can listen to them.
 *
 * Configuration:
 * - replay=5: Keeps last 5 events in memory for late subscribers (~1-2 minutes of history)
 * - extraBufferCapacity=64: Additional buffer for high-frequency events
 *
 * Note: For long-term event persistence across app restarts, see EventStore (Issue #1).
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskEventBus")))
@interface KMPWMTaskEventBus : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Global event bus for task completion events.
 * Workers can emit events here, and the UI can listen to them.
 *
 * Configuration:
 * - replay=5: Keeps last 5 events in memory for late subscribers (~1-2 minutes of history)
 * - extraBufferCapacity=64: Additional buffer for high-frequency events
 *
 * Note: For long-term event persistence across app restarts, see EventStore (Issue #1).
 */
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


/**
 * Central manager for task completion events.
 *
 * Responsibilities:
 * - Persists events to storage for zero event loss
 * - Emits events to EventBus for live UI updates
 *
 * Usage:
 * ```kotlin
 * // In worker after task completion
 * TaskEventManager.emit(TaskCompletionEvent(
 *     taskName = "MyTask",
 *     success = true,
 *     message = "Task completed successfully"
 * ))
 * ```
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskEventManager")))
@interface KMPWMTaskEventManager : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Central manager for task completion events.
 *
 * Responsibilities:
 * - Persists events to storage for zero event loss
 * - Emits events to EventBus for live UI updates
 *
 * Usage:
 * ```kotlin
 * // In worker after task completion
 * TaskEventManager.emit(TaskCompletionEvent(
 *     taskName = "MyTask",
 *     success = true,
 *     message = "Task completed successfully"
 * ))
 * ```
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)taskEventManager __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMTaskEventManager *shared __attribute__((swift_name("shared")));

/**
 * Emits a task completion event.
 *
 * Flow:
 * 1. Saves event to persistent storage (survives app restart)
 * 2. Emits event to EventBus (for live UI)
 *
 * @param event The task completion event to emit
 * @return Event ID if saved successfully, null otherwise
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)emitEvent:(KMPWMTaskCompletionEvent *)event completionHandler:(void (^)(NSString * _Nullable_result, NSError * _Nullable))completionHandler __attribute__((swift_name("emit(event:completionHandler:)")));

/**
 * Initializes the event manager with an EventStore implementation.
 * Must be called during app initialization.
 *
 * @param store The EventStore instance to use for persistence
 */
- (void)initializeStore:(id<KMPWMEventStore>)store __attribute__((swift_name("initialize(store:)")));
@end


/**
 * Global event bus for task progress events.
 * Workers can emit progress updates here, and the UI can listen to them in real-time.
 *
 * Configuration:
 * - replay=1: Keeps the last progress update for late subscribers
 * - extraBufferCapacity=32: Buffer for rapid progress updates
 *
 * **Usage in UI:**
 * ```kotlin
 * LaunchedEffect(Unit) {
 *     TaskProgressBus.events.collect { event ->
 *         when (event.taskId) {
 *             "my-task" -> {
 *                 progressBar.value = event.progress.progress / 100f
 *                 statusText.value = event.progress.message
 *             }
 *         }
 *     }
 * }
 * ```
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskProgressBus")))
@interface KMPWMTaskProgressBus : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Global event bus for task progress events.
 * Workers can emit progress updates here, and the UI can listen to them in real-time.
 *
 * Configuration:
 * - replay=1: Keeps the last progress update for late subscribers
 * - extraBufferCapacity=32: Buffer for rapid progress updates
 *
 * **Usage in UI:**
 * ```kotlin
 * LaunchedEffect(Unit) {
 *     TaskProgressBus.events.collect { event ->
 *         when (event.taskId) {
 *             "my-task" -> {
 *                 progressBar.value = event.progress.progress / 100f
 *                 statusText.value = event.progress.message
 *             }
 *         }
 *     }
 * }
 * ```
 */
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
 * Event emitted when a task reports progress.
 *
 * Subscribe to this via TaskProgressBus to receive real-time progress updates in the UI.
 *
 * @property taskId The ID of the task reporting progress
 * @property taskName The name/class of the worker
 * @property progress The progress information
 *
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskProgressEvent")))
@interface KMPWMTaskProgressEvent : KMPWMBase
- (instancetype)initWithTaskId:(NSString *)taskId taskName:(NSString *)taskName progress:(KMPWMWorkerProgress *)progress __attribute__((swift_name("init(taskId:taskName:progress:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMTaskProgressEventCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMTaskProgressEvent *)doCopyTaskId:(NSString *)taskId taskName:(NSString *)taskName progress:(KMPWMWorkerProgress *)progress __attribute__((swift_name("doCopy(taskId:taskName:progress:)")));

/**
 * Event emitted when a task reports progress.
 *
 * Subscribe to this via TaskProgressBus to receive real-time progress updates in the UI.
 *
 * @property taskId The ID of the task reporting progress
 * @property taskName The name/class of the worker
 * @property progress The progress information
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Event emitted when a task reports progress.
 *
 * Subscribe to this via TaskProgressBus to receive real-time progress updates in the UI.
 *
 * @property taskId The ID of the task reporting progress
 * @property taskName The name/class of the worker
 * @property progress The progress information
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Event emitted when a task reports progress.
 *
 * Subscribe to this via TaskProgressBus to receive real-time progress updates in the UI.
 *
 * @property taskId The ID of the task reporting progress
 * @property taskName The name/class of the worker
 * @property progress The progress information
 */
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) KMPWMWorkerProgress *progress __attribute__((swift_name("progress")));
@property (readonly) NSString *taskId __attribute__((swift_name("taskId")));
@property (readonly) NSString *taskName __attribute__((swift_name("taskName")));
@end


/**
 * Event emitted when a task reports progress.
 *
 * Subscribe to this via TaskProgressBus to receive real-time progress updates in the UI.
 *
 * @property taskId The ID of the task reporting progress
 * @property taskName The name/class of the worker
 * @property progress The progress information
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskProgressEvent.Companion")))
@interface KMPWMTaskProgressEventCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Event emitted when a task reports progress.
 *
 * Subscribe to this via TaskProgressBus to receive real-time progress updates in the UI.
 *
 * @property taskId The ID of the task reporting progress
 * @property taskName The name/class of the worker
 * @property progress The progress information
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMTaskProgressEventCompanion *shared __attribute__((swift_name("shared")));

/**
 * Event emitted when a task reports progress.
 *
 * Subscribe to this via TaskProgressBus to receive real-time progress updates in the UI.
 *
 * @property taskId The ID of the task reporting progress
 * @property taskName The name/class of the worker
 * @property progress The progress information
 */
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * Represents a single, non-periodic task to be executed as part of a chain.
 *
 * @property workerClassName A unique name identifying the actual work to be done.
 * @property inputJson Optional JSON string data to pass as input to the worker.
 *
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskRequest")))
@interface KMPWMTaskRequest : KMPWMBase
- (instancetype)initWithWorkerClassName:(NSString *)workerClassName inputJson:(NSString * _Nullable)inputJson constraints:(KMPWMConstraints * _Nullable)constraints __attribute__((swift_name("init(workerClassName:inputJson:constraints:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMTaskRequestCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMTaskRequest *)doCopyWorkerClassName:(NSString *)workerClassName inputJson:(NSString * _Nullable)inputJson constraints:(KMPWMConstraints * _Nullable)constraints __attribute__((swift_name("doCopy(workerClassName:inputJson:constraints:)")));

/**
 * Represents a single, non-periodic task to be executed as part of a chain.
 *
 * @property workerClassName A unique name identifying the actual work to be done.
 * @property inputJson Optional JSON string data to pass as input to the worker.
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Represents a single, non-periodic task to be executed as part of a chain.
 *
 * @property workerClassName A unique name identifying the actual work to be done.
 * @property inputJson Optional JSON string data to pass as input to the worker.
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Represents a single, non-periodic task to be executed as part of a chain.
 *
 * @property workerClassName A unique name identifying the actual work to be done.
 * @property inputJson Optional JSON string data to pass as input to the worker.
 */
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) KMPWMConstraints * _Nullable constraints __attribute__((swift_name("constraints")));
@property (readonly) NSString * _Nullable inputJson __attribute__((swift_name("inputJson")));
@property (readonly) NSString *workerClassName __attribute__((swift_name("workerClassName")));
@end


/**
 * Represents a single, non-periodic task to be executed as part of a chain.
 *
 * @property workerClassName A unique name identifying the actual work to be done.
 * @property inputJson Optional JSON string data to pass as input to the worker.
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskRequest.Companion")))
@interface KMPWMTaskRequestCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Represents a single, non-periodic task to be executed as part of a chain.
 *
 * @property workerClassName A unique name identifying the actual work to be done.
 * @property inputJson Optional JSON string data to pass as input to the worker.
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMTaskRequestCompanion *shared __attribute__((swift_name("shared")));

/**
 * Represents a single, non-periodic task to be executed as part of a chain.
 *
 * @property workerClassName A unique name identifying the actual work to be done.
 * @property inputJson Optional JSON string data to pass as input to the worker.
 */
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * Type-safe task specification for parallel chain execution.
 *
 * @param T The type of input data (must be annotated with @Serializable)
 * @param workerClassName Fully qualified worker class name
 * @param constraints Execution constraints
 * @param input Optional typed input data
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskSpec")))
@interface KMPWMTaskSpec<T> : KMPWMBase
- (instancetype)initWithWorkerClassName:(NSString *)workerClassName constraints:(KMPWMConstraints *)constraints input:(T _Nullable)input __attribute__((swift_name("init(workerClassName:constraints:input:)"))) __attribute__((objc_designated_initializer));
- (KMPWMTaskSpec<T> *)doCopyWorkerClassName:(NSString *)workerClassName constraints:(KMPWMConstraints *)constraints input:(T _Nullable)input __attribute__((swift_name("doCopy(workerClassName:constraints:input:)")));

/**
 * Type-safe task specification for parallel chain execution.
 *
 * @param T The type of input data (must be annotated with @Serializable)
 * @param workerClassName Fully qualified worker class name
 * @param constraints Execution constraints
 * @param input Optional typed input data
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Type-safe task specification for parallel chain execution.
 *
 * @param T The type of input data (must be annotated with @Serializable)
 * @param workerClassName Fully qualified worker class name
 * @param constraints Execution constraints
 * @param input Optional typed input data
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Type-safe task specification for parallel chain execution.
 *
 * @param T The type of input data (must be annotated with @Serializable)
 * @param workerClassName Fully qualified worker class name
 * @param constraints Execution constraints
 * @param input Optional typed input data
 */
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) KMPWMConstraints *constraints __attribute__((swift_name("constraints")));
@property (readonly) T _Nullable input __attribute__((swift_name("input")));
@property (readonly) NSString *workerClassName __attribute__((swift_name("workerClassName")));
@end


/**
 * Detailed status for a specific task
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskStatusDetail")))
@interface KMPWMTaskStatusDetail : KMPWMBase
- (instancetype)initWithTaskId:(NSString *)taskId workerClassName:(NSString *)workerClassName state:(NSString *)state retryCount:(int32_t)retryCount lastExecutionTime:(KMPWMLong * _Nullable)lastExecutionTime lastError:(NSString * _Nullable)lastError __attribute__((swift_name("init(taskId:workerClassName:state:retryCount:lastExecutionTime:lastError:)"))) __attribute__((objc_designated_initializer));
- (KMPWMTaskStatusDetail *)doCopyTaskId:(NSString *)taskId workerClassName:(NSString *)workerClassName state:(NSString *)state retryCount:(int32_t)retryCount lastExecutionTime:(KMPWMLong * _Nullable)lastExecutionTime lastError:(NSString * _Nullable)lastError __attribute__((swift_name("doCopy(taskId:workerClassName:state:retryCount:lastExecutionTime:lastError:)")));

/**
 * Detailed status for a specific task
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Detailed status for a specific task
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Detailed status for a specific task
 */
- (NSString *)description __attribute__((swift_name("description()")));

/**
 * Last error message (null if no error)
 */
@property (readonly) NSString * _Nullable lastError __attribute__((swift_name("lastError")));

/**
 * Last execution timestamp (epoch milliseconds, null if never executed)
 */
@property (readonly) KMPWMLong * _Nullable lastExecutionTime __attribute__((swift_name("lastExecutionTime")));

/**
 * Number of retry attempts
 */
@property (readonly) int32_t retryCount __attribute__((swift_name("retryCount")));

/**
 * Current state (PENDING, RUNNING, COMPLETED, FAILED)
 */
@property (readonly) NSString *state __attribute__((swift_name("state")));

/**
 * Task ID
 */
@property (readonly) NSString *taskId __attribute__((swift_name("taskId")));

/**
 * Worker class name
 */
@property (readonly) NSString *workerClassName __attribute__((swift_name("workerClassName")));
@end


/**
 * Defines the trigger condition for a background task.
 *
 * This sealed interface provides a type-safe way to specify when and how
 * background tasks should be executed. Each trigger type has different
 * platform support and scheduling characteristics.
 *
 * Platform Support Matrix:
 * - Periodic, OneTime, Exact, Windowed: ✅ Android ✅ iOS
 * - ContentUri, Battery*, Storage*, DeviceIdle: ✅ Android only
 *
 * **Note on Windowed (iOS)**: iOS only supports `earliest` time via `earliestBeginDate`.
 * The `latest` time is logged but not enforced - iOS decides when to run opportunistically.
 */
__attribute__((swift_name("TaskTrigger")))
@protocol KMPWMTaskTrigger
@required
@end


/**
 * Triggers when battery is low - **ANDROID ONLY**.
 *
 * **⚠️ DEPRECATED**: Use `Constraints(systemConstraints = setOf(SystemConstraint.ALLOW_LOW_BATTERY))` instead.
 *
 * **Migration**:
 * ```kotlin
 * // Old (v2.x):
 * scheduler.enqueue(id, trigger = TaskTrigger.BatteryLow, ...)
 *
 * // New (v3.0.0+):
 * scheduler.enqueue(
 *     id,
 *     trigger = TaskTrigger.OneTime(),
 *     constraints = Constraints(systemConstraints = setOf(SystemConstraint.ALLOW_LOW_BATTERY))
 * )
 * ```
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskTriggerBatteryLow")))
@interface KMPWMTaskTriggerBatteryLow : KMPWMBase <KMPWMTaskTrigger>
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Triggers when battery is low - **ANDROID ONLY**.
 *
 * **⚠️ DEPRECATED**: Use `Constraints(systemConstraints = setOf(SystemConstraint.ALLOW_LOW_BATTERY))` instead.
 *
 * **Migration**:
 * ```kotlin
 * // Old (v2.x):
 * scheduler.enqueue(id, trigger = TaskTrigger.BatteryLow, ...)
 *
 * // New (v3.0.0+):
 * scheduler.enqueue(
 *     id,
 *     trigger = TaskTrigger.OneTime(),
 *     constraints = Constraints(systemConstraints = setOf(SystemConstraint.ALLOW_LOW_BATTERY))
 * )
 * ```
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)batteryLow __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMTaskTriggerBatteryLow *shared __attribute__((swift_name("shared")));

/**
 * Triggers when battery is low - **ANDROID ONLY**.
 *
 * **⚠️ DEPRECATED**: Use `Constraints(systemConstraints = setOf(SystemConstraint.ALLOW_LOW_BATTERY))` instead.
 *
 * **Migration**:
 * ```kotlin
 * // Old (v2.x):
 * scheduler.enqueue(id, trigger = TaskTrigger.BatteryLow, ...)
 *
 * // New (v3.0.0+):
 * scheduler.enqueue(
 *     id,
 *     trigger = TaskTrigger.OneTime(),
 *     constraints = Constraints(systemConstraints = setOf(SystemConstraint.ALLOW_LOW_BATTERY))
 * )
 * ```
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Triggers when battery is low - **ANDROID ONLY**.
 *
 * **⚠️ DEPRECATED**: Use `Constraints(systemConstraints = setOf(SystemConstraint.ALLOW_LOW_BATTERY))` instead.
 *
 * **Migration**:
 * ```kotlin
 * // Old (v2.x):
 * scheduler.enqueue(id, trigger = TaskTrigger.BatteryLow, ...)
 *
 * // New (v3.0.0+):
 * scheduler.enqueue(
 *     id,
 *     trigger = TaskTrigger.OneTime(),
 *     constraints = Constraints(systemConstraints = setOf(SystemConstraint.ALLOW_LOW_BATTERY))
 * )
 * ```
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Triggers when battery is low - **ANDROID ONLY**.
 *
 * **⚠️ DEPRECATED**: Use `Constraints(systemConstraints = setOf(SystemConstraint.ALLOW_LOW_BATTERY))` instead.
 *
 * **Migration**:
 * ```kotlin
 * // Old (v2.x):
 * scheduler.enqueue(id, trigger = TaskTrigger.BatteryLow, ...)
 *
 * // New (v3.0.0+):
 * scheduler.enqueue(
 *     id,
 *     trigger = TaskTrigger.OneTime(),
 *     constraints = Constraints(systemConstraints = setOf(SystemConstraint.ALLOW_LOW_BATTERY))
 * )
 * ```
 */
- (NSString *)description __attribute__((swift_name("description()")));
@end


/**
 * Triggers when battery is okay/not low - **ANDROID ONLY**.
 *
 * **⚠️ DEPRECATED**: Use `Constraints(systemConstraints = setOf(SystemConstraint.REQUIRE_BATTERY_NOT_LOW))` instead.
 *
 * **Migration**:
 * ```kotlin
 * // Old (v2.x):
 * scheduler.enqueue(id, trigger = TaskTrigger.BatteryOkay, ...)
 *
 * // New (v3.0.0+):
 * scheduler.enqueue(
 *     id,
 *     trigger = TaskTrigger.OneTime(),
 *     constraints = Constraints(systemConstraints = setOf(SystemConstraint.REQUIRE_BATTERY_NOT_LOW))
 * )
 * ```
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskTriggerBatteryOkay")))
@interface KMPWMTaskTriggerBatteryOkay : KMPWMBase <KMPWMTaskTrigger>
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Triggers when battery is okay/not low - **ANDROID ONLY**.
 *
 * **⚠️ DEPRECATED**: Use `Constraints(systemConstraints = setOf(SystemConstraint.REQUIRE_BATTERY_NOT_LOW))` instead.
 *
 * **Migration**:
 * ```kotlin
 * // Old (v2.x):
 * scheduler.enqueue(id, trigger = TaskTrigger.BatteryOkay, ...)
 *
 * // New (v3.0.0+):
 * scheduler.enqueue(
 *     id,
 *     trigger = TaskTrigger.OneTime(),
 *     constraints = Constraints(systemConstraints = setOf(SystemConstraint.REQUIRE_BATTERY_NOT_LOW))
 * )
 * ```
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)batteryOkay __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMTaskTriggerBatteryOkay *shared __attribute__((swift_name("shared")));

/**
 * Triggers when battery is okay/not low - **ANDROID ONLY**.
 *
 * **⚠️ DEPRECATED**: Use `Constraints(systemConstraints = setOf(SystemConstraint.REQUIRE_BATTERY_NOT_LOW))` instead.
 *
 * **Migration**:
 * ```kotlin
 * // Old (v2.x):
 * scheduler.enqueue(id, trigger = TaskTrigger.BatteryOkay, ...)
 *
 * // New (v3.0.0+):
 * scheduler.enqueue(
 *     id,
 *     trigger = TaskTrigger.OneTime(),
 *     constraints = Constraints(systemConstraints = setOf(SystemConstraint.REQUIRE_BATTERY_NOT_LOW))
 * )
 * ```
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Triggers when battery is okay/not low - **ANDROID ONLY**.
 *
 * **⚠️ DEPRECATED**: Use `Constraints(systemConstraints = setOf(SystemConstraint.REQUIRE_BATTERY_NOT_LOW))` instead.
 *
 * **Migration**:
 * ```kotlin
 * // Old (v2.x):
 * scheduler.enqueue(id, trigger = TaskTrigger.BatteryOkay, ...)
 *
 * // New (v3.0.0+):
 * scheduler.enqueue(
 *     id,
 *     trigger = TaskTrigger.OneTime(),
 *     constraints = Constraints(systemConstraints = setOf(SystemConstraint.REQUIRE_BATTERY_NOT_LOW))
 * )
 * ```
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Triggers when battery is okay/not low - **ANDROID ONLY**.
 *
 * **⚠️ DEPRECATED**: Use `Constraints(systemConstraints = setOf(SystemConstraint.REQUIRE_BATTERY_NOT_LOW))` instead.
 *
 * **Migration**:
 * ```kotlin
 * // Old (v2.x):
 * scheduler.enqueue(id, trigger = TaskTrigger.BatteryOkay, ...)
 *
 * // New (v3.0.0+):
 * scheduler.enqueue(
 *     id,
 *     trigger = TaskTrigger.OneTime(),
 *     constraints = Constraints(systemConstraints = setOf(SystemConstraint.REQUIRE_BATTERY_NOT_LOW))
 * )
 * ```
 */
- (NSString *)description __attribute__((swift_name("description()")));
@end


/**
 * Triggers when a content URI changes - **ANDROID ONLY**.
 *
 * **Use Cases**: React to MediaStore changes, Contact updates, file modifications
 *
 * **Android Implementation**:
 * - Uses `WorkManager` with `ContentUriTriggers`
 * - Monitors content provider via `ContentObserver`
 * - Common URIs: `content://media/external/images/media`, `content://contacts`
 *
 * **iOS**: Returns `ScheduleResult.REJECTED_OS_POLICY`
 *
 * @param uriString Content URI to observe (e.g., "content://media/external/images/media")
 * @param triggerForDescendants If true, triggers for changes in descendant URIs as well
 *
 * **Example**:
 * ```kotlin
 * @OptIn(AndroidOnly::class)
 * TaskTrigger.ContentUri(
 *     uriString = "content://media/external/images/media",
 *     triggerForDescendants = true
 * )
 * ```
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskTriggerContentUri")))
@interface KMPWMTaskTriggerContentUri : KMPWMBase <KMPWMTaskTrigger>
- (instancetype)initWithUriString:(NSString *)uriString triggerForDescendants:(BOOL)triggerForDescendants __attribute__((swift_name("init(uriString:triggerForDescendants:)"))) __attribute__((objc_designated_initializer));
- (KMPWMTaskTriggerContentUri *)doCopyUriString:(NSString *)uriString triggerForDescendants:(BOOL)triggerForDescendants __attribute__((swift_name("doCopy(uriString:triggerForDescendants:)")));

/**
 * Triggers when a content URI changes - **ANDROID ONLY**.
 *
 * **Use Cases**: React to MediaStore changes, Contact updates, file modifications
 *
 * **Android Implementation**:
 * - Uses `WorkManager` with `ContentUriTriggers`
 * - Monitors content provider via `ContentObserver`
 * - Common URIs: `content://media/external/images/media`, `content://contacts`
 *
 * **iOS**: Returns `ScheduleResult.REJECTED_OS_POLICY`
 *
 * @param uriString Content URI to observe (e.g., "content://media/external/images/media")
 * @param triggerForDescendants If true, triggers for changes in descendant URIs as well
 *
 * **Example**:
 * ```kotlin
 * @OptIn(AndroidOnly::class)
 * TaskTrigger.ContentUri(
 *     uriString = "content://media/external/images/media",
 *     triggerForDescendants = true
 * )
 * ```
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Triggers when a content URI changes - **ANDROID ONLY**.
 *
 * **Use Cases**: React to MediaStore changes, Contact updates, file modifications
 *
 * **Android Implementation**:
 * - Uses `WorkManager` with `ContentUriTriggers`
 * - Monitors content provider via `ContentObserver`
 * - Common URIs: `content://media/external/images/media`, `content://contacts`
 *
 * **iOS**: Returns `ScheduleResult.REJECTED_OS_POLICY`
 *
 * @param uriString Content URI to observe (e.g., "content://media/external/images/media")
 * @param triggerForDescendants If true, triggers for changes in descendant URIs as well
 *
 * **Example**:
 * ```kotlin
 * @OptIn(AndroidOnly::class)
 * TaskTrigger.ContentUri(
 *     uriString = "content://media/external/images/media",
 *     triggerForDescendants = true
 * )
 * ```
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Triggers when a content URI changes - **ANDROID ONLY**.
 *
 * **Use Cases**: React to MediaStore changes, Contact updates, file modifications
 *
 * **Android Implementation**:
 * - Uses `WorkManager` with `ContentUriTriggers`
 * - Monitors content provider via `ContentObserver`
 * - Common URIs: `content://media/external/images/media`, `content://contacts`
 *
 * **iOS**: Returns `ScheduleResult.REJECTED_OS_POLICY`
 *
 * @param uriString Content URI to observe (e.g., "content://media/external/images/media")
 * @param triggerForDescendants If true, triggers for changes in descendant URIs as well
 *
 * **Example**:
 * ```kotlin
 * @OptIn(AndroidOnly::class)
 * TaskTrigger.ContentUri(
 *     uriString = "content://media/external/images/media",
 *     triggerForDescendants = true
 * )
 * ```
 */
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) BOOL triggerForDescendants __attribute__((swift_name("triggerForDescendants")));
@property (readonly) NSString *uriString __attribute__((swift_name("uriString")));
@end


/**
 * Triggers when device is idle/dozing - **ANDROID ONLY**.
 *
 * **⚠️ DEPRECATED**: Use `Constraints(systemConstraints = setOf(SystemConstraint.DEVICE_IDLE))` instead.
 *
 * **Migration**:
 * ```kotlin
 * // Old (v2.x):
 * scheduler.enqueue(id, trigger = TaskTrigger.DeviceIdle, ...)
 *
 * // New (v3.0.0+):
 * scheduler.enqueue(
 *     id,
 *     trigger = TaskTrigger.OneTime(),
 *     constraints = Constraints(systemConstraints = setOf(SystemConstraint.DEVICE_IDLE))
 * )
 * ```
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskTriggerDeviceIdle")))
@interface KMPWMTaskTriggerDeviceIdle : KMPWMBase <KMPWMTaskTrigger>
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Triggers when device is idle/dozing - **ANDROID ONLY**.
 *
 * **⚠️ DEPRECATED**: Use `Constraints(systemConstraints = setOf(SystemConstraint.DEVICE_IDLE))` instead.
 *
 * **Migration**:
 * ```kotlin
 * // Old (v2.x):
 * scheduler.enqueue(id, trigger = TaskTrigger.DeviceIdle, ...)
 *
 * // New (v3.0.0+):
 * scheduler.enqueue(
 *     id,
 *     trigger = TaskTrigger.OneTime(),
 *     constraints = Constraints(systemConstraints = setOf(SystemConstraint.DEVICE_IDLE))
 * )
 * ```
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)deviceIdle __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMTaskTriggerDeviceIdle *shared __attribute__((swift_name("shared")));

/**
 * Triggers when device is idle/dozing - **ANDROID ONLY**.
 *
 * **⚠️ DEPRECATED**: Use `Constraints(systemConstraints = setOf(SystemConstraint.DEVICE_IDLE))` instead.
 *
 * **Migration**:
 * ```kotlin
 * // Old (v2.x):
 * scheduler.enqueue(id, trigger = TaskTrigger.DeviceIdle, ...)
 *
 * // New (v3.0.0+):
 * scheduler.enqueue(
 *     id,
 *     trigger = TaskTrigger.OneTime(),
 *     constraints = Constraints(systemConstraints = setOf(SystemConstraint.DEVICE_IDLE))
 * )
 * ```
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Triggers when device is idle/dozing - **ANDROID ONLY**.
 *
 * **⚠️ DEPRECATED**: Use `Constraints(systemConstraints = setOf(SystemConstraint.DEVICE_IDLE))` instead.
 *
 * **Migration**:
 * ```kotlin
 * // Old (v2.x):
 * scheduler.enqueue(id, trigger = TaskTrigger.DeviceIdle, ...)
 *
 * // New (v3.0.0+):
 * scheduler.enqueue(
 *     id,
 *     trigger = TaskTrigger.OneTime(),
 *     constraints = Constraints(systemConstraints = setOf(SystemConstraint.DEVICE_IDLE))
 * )
 * ```
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Triggers when device is idle/dozing - **ANDROID ONLY**.
 *
 * **⚠️ DEPRECATED**: Use `Constraints(systemConstraints = setOf(SystemConstraint.DEVICE_IDLE))` instead.
 *
 * **Migration**:
 * ```kotlin
 * // Old (v2.x):
 * scheduler.enqueue(id, trigger = TaskTrigger.DeviceIdle, ...)
 *
 * // New (v3.0.0+):
 * scheduler.enqueue(
 *     id,
 *     trigger = TaskTrigger.OneTime(),
 *     constraints = Constraints(systemConstraints = setOf(SystemConstraint.DEVICE_IDLE))
 * )
 * ```
 */
- (NSString *)description __attribute__((swift_name("description()")));
@end


/**
 * Triggers at a precise moment in time using exact alarm.
 *
 * **Use Cases**: Alarms, reminders, time-critical user-facing events
 *
 * **Android Implementation**:
 * - Uses `AlarmManager.setExactAndAllowWhileIdle()`
 * - Requires `SCHEDULE_EXACT_ALARM` permission on Android 12+ (API 31+)
 * - Can wake device from doze mode
 * - Accuracy: ±1 minute window on API 31+
 *
 * **iOS Implementation**:
 * - Uses `UNUserNotificationCenter` for scheduled local notifications
 * - Displays notification at exact time
 * - Does not execute code in background (notification-based)
 *
 * @param atEpochMillis Unix timestamp in milliseconds when alarm should trigger
 *
 * **Example**:
 * ```kotlin
 * val targetTime = Clock.System.now().plus(1.hours).toEpochMilliseconds()
 * TaskTrigger.Exact(atEpochMillis = targetTime)
 * ```
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskTriggerExact")))
@interface KMPWMTaskTriggerExact : KMPWMBase <KMPWMTaskTrigger>
- (instancetype)initWithAtEpochMillis:(int64_t)atEpochMillis __attribute__((swift_name("init(atEpochMillis:)"))) __attribute__((objc_designated_initializer));
- (KMPWMTaskTriggerExact *)doCopyAtEpochMillis:(int64_t)atEpochMillis __attribute__((swift_name("doCopy(atEpochMillis:)")));

/**
 * Triggers at a precise moment in time using exact alarm.
 *
 * **Use Cases**: Alarms, reminders, time-critical user-facing events
 *
 * **Android Implementation**:
 * - Uses `AlarmManager.setExactAndAllowWhileIdle()`
 * - Requires `SCHEDULE_EXACT_ALARM` permission on Android 12+ (API 31+)
 * - Can wake device from doze mode
 * - Accuracy: ±1 minute window on API 31+
 *
 * **iOS Implementation**:
 * - Uses `UNUserNotificationCenter` for scheduled local notifications
 * - Displays notification at exact time
 * - Does not execute code in background (notification-based)
 *
 * @param atEpochMillis Unix timestamp in milliseconds when alarm should trigger
 *
 * **Example**:
 * ```kotlin
 * val targetTime = Clock.System.now().plus(1.hours).toEpochMilliseconds()
 * TaskTrigger.Exact(atEpochMillis = targetTime)
 * ```
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Triggers at a precise moment in time using exact alarm.
 *
 * **Use Cases**: Alarms, reminders, time-critical user-facing events
 *
 * **Android Implementation**:
 * - Uses `AlarmManager.setExactAndAllowWhileIdle()`
 * - Requires `SCHEDULE_EXACT_ALARM` permission on Android 12+ (API 31+)
 * - Can wake device from doze mode
 * - Accuracy: ±1 minute window on API 31+
 *
 * **iOS Implementation**:
 * - Uses `UNUserNotificationCenter` for scheduled local notifications
 * - Displays notification at exact time
 * - Does not execute code in background (notification-based)
 *
 * @param atEpochMillis Unix timestamp in milliseconds when alarm should trigger
 *
 * **Example**:
 * ```kotlin
 * val targetTime = Clock.System.now().plus(1.hours).toEpochMilliseconds()
 * TaskTrigger.Exact(atEpochMillis = targetTime)
 * ```
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Triggers at a precise moment in time using exact alarm.
 *
 * **Use Cases**: Alarms, reminders, time-critical user-facing events
 *
 * **Android Implementation**:
 * - Uses `AlarmManager.setExactAndAllowWhileIdle()`
 * - Requires `SCHEDULE_EXACT_ALARM` permission on Android 12+ (API 31+)
 * - Can wake device from doze mode
 * - Accuracy: ±1 minute window on API 31+
 *
 * **iOS Implementation**:
 * - Uses `UNUserNotificationCenter` for scheduled local notifications
 * - Displays notification at exact time
 * - Does not execute code in background (notification-based)
 *
 * @param atEpochMillis Unix timestamp in milliseconds when alarm should trigger
 *
 * **Example**:
 * ```kotlin
 * val targetTime = Clock.System.now().plus(1.hours).toEpochMilliseconds()
 * TaskTrigger.Exact(atEpochMillis = targetTime)
 * ```
 */
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int64_t atEpochMillis __attribute__((swift_name("atEpochMillis")));
@end


/**
 * Triggers once after an optional initial delay.
 *
 * **Use Cases**: One-time upload, deferred processing, delayed execution
 *
 * **Android Implementation**:
 * - Uses `WorkManager.OneTimeWorkRequest`
 * - Constraints-aware (network, battery, etc.)
 * - Survives app restart and device reboot
 * - Can use ForegroundService for long-running tasks (isHeavyTask = true)
 *
 * **iOS Implementation**:
 * - Uses `BGAppRefreshTask` (≤30s) or `BGProcessingTask` (≤60s)
 * - iOS decides actual execution time (can be delayed)
 * - `earliestBeginDate` = now + initialDelayMs
 * - Execution not guaranteed if app is force-quit by user
 *
 * @param initialDelayMs Delay before execution in milliseconds (default: 0 = immediate)
 *
 * **Example**:
 * ```kotlin
 * // Upload data after 5 seconds
 * TaskTrigger.OneTime(initialDelayMs = 5000)
 * ```
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskTriggerOneTime")))
@interface KMPWMTaskTriggerOneTime : KMPWMBase <KMPWMTaskTrigger>
- (instancetype)initWithInitialDelayMs:(int64_t)initialDelayMs __attribute__((swift_name("init(initialDelayMs:)"))) __attribute__((objc_designated_initializer));
- (KMPWMTaskTriggerOneTime *)doCopyInitialDelayMs:(int64_t)initialDelayMs __attribute__((swift_name("doCopy(initialDelayMs:)")));

/**
 * Triggers once after an optional initial delay.
 *
 * **Use Cases**: One-time upload, deferred processing, delayed execution
 *
 * **Android Implementation**:
 * - Uses `WorkManager.OneTimeWorkRequest`
 * - Constraints-aware (network, battery, etc.)
 * - Survives app restart and device reboot
 * - Can use ForegroundService for long-running tasks (isHeavyTask = true)
 *
 * **iOS Implementation**:
 * - Uses `BGAppRefreshTask` (≤30s) or `BGProcessingTask` (≤60s)
 * - iOS decides actual execution time (can be delayed)
 * - `earliestBeginDate` = now + initialDelayMs
 * - Execution not guaranteed if app is force-quit by user
 *
 * @param initialDelayMs Delay before execution in milliseconds (default: 0 = immediate)
 *
 * **Example**:
 * ```kotlin
 * // Upload data after 5 seconds
 * TaskTrigger.OneTime(initialDelayMs = 5000)
 * ```
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Triggers once after an optional initial delay.
 *
 * **Use Cases**: One-time upload, deferred processing, delayed execution
 *
 * **Android Implementation**:
 * - Uses `WorkManager.OneTimeWorkRequest`
 * - Constraints-aware (network, battery, etc.)
 * - Survives app restart and device reboot
 * - Can use ForegroundService for long-running tasks (isHeavyTask = true)
 *
 * **iOS Implementation**:
 * - Uses `BGAppRefreshTask` (≤30s) or `BGProcessingTask` (≤60s)
 * - iOS decides actual execution time (can be delayed)
 * - `earliestBeginDate` = now + initialDelayMs
 * - Execution not guaranteed if app is force-quit by user
 *
 * @param initialDelayMs Delay before execution in milliseconds (default: 0 = immediate)
 *
 * **Example**:
 * ```kotlin
 * // Upload data after 5 seconds
 * TaskTrigger.OneTime(initialDelayMs = 5000)
 * ```
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Triggers once after an optional initial delay.
 *
 * **Use Cases**: One-time upload, deferred processing, delayed execution
 *
 * **Android Implementation**:
 * - Uses `WorkManager.OneTimeWorkRequest`
 * - Constraints-aware (network, battery, etc.)
 * - Survives app restart and device reboot
 * - Can use ForegroundService for long-running tasks (isHeavyTask = true)
 *
 * **iOS Implementation**:
 * - Uses `BGAppRefreshTask` (≤30s) or `BGProcessingTask` (≤60s)
 * - iOS decides actual execution time (can be delayed)
 * - `earliestBeginDate` = now + initialDelayMs
 * - Execution not guaranteed if app is force-quit by user
 *
 * @param initialDelayMs Delay before execution in milliseconds (default: 0 = immediate)
 *
 * **Example**:
 * ```kotlin
 * // Upload data after 5 seconds
 * TaskTrigger.OneTime(initialDelayMs = 5000)
 * ```
 */
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int64_t initialDelayMs __attribute__((swift_name("initialDelayMs")));
@end


/**
 * Triggers periodically at regular intervals.
 *
 * **Use Cases**: Data sync, content refresh, periodic maintenance
 *
 * **Android Implementation**:
 * - Uses `WorkManager.PeriodicWorkRequest`
 * - **Minimum interval: 15 minutes (900,000ms)**
 * - Actual execution time is opportunistic (OS decides best time)
 * - Survives app restart and device reboot
 * - `flexMs` creates execution window: [intervalMs - flexMs, intervalMs]
 *
 * **iOS Implementation**:
 * - Uses `BGAppRefreshTask` (light tasks) or `BGProcessingTask` (heavy tasks)
 * - **No minimum interval**, but iOS decides actual execution time
 * - Execution heavily influenced by battery, usage patterns
 * - Must manually re-schedule after each execution
 * - Low Power Mode may defer execution significantly
 *
 * @param intervalMs Repetition interval in milliseconds (Android min: 900,000ms / 15min)
 * @param flexMs Android-only: Flex window in milliseconds for execution optimization.
 *               Task can execute anytime within [intervalMs - flexMs, intervalMs].
 *               Helps battery by batching multiple tasks. iOS ignores this parameter.
 *
 * **Example**:
 * ```kotlin
 * // Sync every 15 minutes with 5-minute flex window
 * TaskTrigger.Periodic(
 *     intervalMs = 900_000,  // 15 minutes
 *     flexMs = 300_000       // 5 minutes flex
 * )
 * ```
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskTriggerPeriodic")))
@interface KMPWMTaskTriggerPeriodic : KMPWMBase <KMPWMTaskTrigger>
- (instancetype)initWithIntervalMs:(int64_t)intervalMs flexMs:(KMPWMLong * _Nullable)flexMs __attribute__((swift_name("init(intervalMs:flexMs:)"))) __attribute__((objc_designated_initializer));
- (KMPWMTaskTriggerPeriodic *)doCopyIntervalMs:(int64_t)intervalMs flexMs:(KMPWMLong * _Nullable)flexMs __attribute__((swift_name("doCopy(intervalMs:flexMs:)")));

/**
 * Triggers periodically at regular intervals.
 *
 * **Use Cases**: Data sync, content refresh, periodic maintenance
 *
 * **Android Implementation**:
 * - Uses `WorkManager.PeriodicWorkRequest`
 * - **Minimum interval: 15 minutes (900,000ms)**
 * - Actual execution time is opportunistic (OS decides best time)
 * - Survives app restart and device reboot
 * - `flexMs` creates execution window: [intervalMs - flexMs, intervalMs]
 *
 * **iOS Implementation**:
 * - Uses `BGAppRefreshTask` (light tasks) or `BGProcessingTask` (heavy tasks)
 * - **No minimum interval**, but iOS decides actual execution time
 * - Execution heavily influenced by battery, usage patterns
 * - Must manually re-schedule after each execution
 * - Low Power Mode may defer execution significantly
 *
 * @param intervalMs Repetition interval in milliseconds (Android min: 900,000ms / 15min)
 * @param flexMs Android-only: Flex window in milliseconds for execution optimization.
 *               Task can execute anytime within [intervalMs - flexMs, intervalMs].
 *               Helps battery by batching multiple tasks. iOS ignores this parameter.
 *
 * **Example**:
 * ```kotlin
 * // Sync every 15 minutes with 5-minute flex window
 * TaskTrigger.Periodic(
 *     intervalMs = 900_000,  // 15 minutes
 *     flexMs = 300_000       // 5 minutes flex
 * )
 * ```
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Triggers periodically at regular intervals.
 *
 * **Use Cases**: Data sync, content refresh, periodic maintenance
 *
 * **Android Implementation**:
 * - Uses `WorkManager.PeriodicWorkRequest`
 * - **Minimum interval: 15 minutes (900,000ms)**
 * - Actual execution time is opportunistic (OS decides best time)
 * - Survives app restart and device reboot
 * - `flexMs` creates execution window: [intervalMs - flexMs, intervalMs]
 *
 * **iOS Implementation**:
 * - Uses `BGAppRefreshTask` (light tasks) or `BGProcessingTask` (heavy tasks)
 * - **No minimum interval**, but iOS decides actual execution time
 * - Execution heavily influenced by battery, usage patterns
 * - Must manually re-schedule after each execution
 * - Low Power Mode may defer execution significantly
 *
 * @param intervalMs Repetition interval in milliseconds (Android min: 900,000ms / 15min)
 * @param flexMs Android-only: Flex window in milliseconds for execution optimization.
 *               Task can execute anytime within [intervalMs - flexMs, intervalMs].
 *               Helps battery by batching multiple tasks. iOS ignores this parameter.
 *
 * **Example**:
 * ```kotlin
 * // Sync every 15 minutes with 5-minute flex window
 * TaskTrigger.Periodic(
 *     intervalMs = 900_000,  // 15 minutes
 *     flexMs = 300_000       // 5 minutes flex
 * )
 * ```
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Triggers periodically at regular intervals.
 *
 * **Use Cases**: Data sync, content refresh, periodic maintenance
 *
 * **Android Implementation**:
 * - Uses `WorkManager.PeriodicWorkRequest`
 * - **Minimum interval: 15 minutes (900,000ms)**
 * - Actual execution time is opportunistic (OS decides best time)
 * - Survives app restart and device reboot
 * - `flexMs` creates execution window: [intervalMs - flexMs, intervalMs]
 *
 * **iOS Implementation**:
 * - Uses `BGAppRefreshTask` (light tasks) or `BGProcessingTask` (heavy tasks)
 * - **No minimum interval**, but iOS decides actual execution time
 * - Execution heavily influenced by battery, usage patterns
 * - Must manually re-schedule after each execution
 * - Low Power Mode may defer execution significantly
 *
 * @param intervalMs Repetition interval in milliseconds (Android min: 900,000ms / 15min)
 * @param flexMs Android-only: Flex window in milliseconds for execution optimization.
 *               Task can execute anytime within [intervalMs - flexMs, intervalMs].
 *               Helps battery by batching multiple tasks. iOS ignores this parameter.
 *
 * **Example**:
 * ```kotlin
 * // Sync every 15 minutes with 5-minute flex window
 * TaskTrigger.Periodic(
 *     intervalMs = 900_000,  // 15 minutes
 *     flexMs = 300_000       // 5 minutes flex
 * )
 * ```
 */
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) KMPWMLong * _Nullable flexMs __attribute__((swift_name("flexMs")));
@property (readonly) int64_t intervalMs __attribute__((swift_name("intervalMs")));
@end


/**
 * Triggers when device storage is low - **ANDROID ONLY**.
 *
 * **⚠️ DEPRECATED**: Use `Constraints(systemConstraints = setOf(SystemConstraint.ALLOW_LOW_STORAGE))` instead.
 *
 * This incorrectly represented a constraint as a trigger. The new API correctly models this
 * as a constraint that allows tasks to run when storage is low.
 *
 * **Migration**:
 * ```kotlin
 * // Old (v2.x):
 * scheduler.enqueue(id, trigger = TaskTrigger.StorageLow, ...)
 *
 * // New (v3.0.0+):
 * scheduler.enqueue(
 *     id,
 *     trigger = TaskTrigger.OneTime(),
 *     constraints = Constraints(systemConstraints = setOf(SystemConstraint.ALLOW_LOW_STORAGE))
 * )
 * ```
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskTriggerStorageLow")))
@interface KMPWMTaskTriggerStorageLow : KMPWMBase <KMPWMTaskTrigger>
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Triggers when device storage is low - **ANDROID ONLY**.
 *
 * **⚠️ DEPRECATED**: Use `Constraints(systemConstraints = setOf(SystemConstraint.ALLOW_LOW_STORAGE))` instead.
 *
 * This incorrectly represented a constraint as a trigger. The new API correctly models this
 * as a constraint that allows tasks to run when storage is low.
 *
 * **Migration**:
 * ```kotlin
 * // Old (v2.x):
 * scheduler.enqueue(id, trigger = TaskTrigger.StorageLow, ...)
 *
 * // New (v3.0.0+):
 * scheduler.enqueue(
 *     id,
 *     trigger = TaskTrigger.OneTime(),
 *     constraints = Constraints(systemConstraints = setOf(SystemConstraint.ALLOW_LOW_STORAGE))
 * )
 * ```
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)storageLow __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMTaskTriggerStorageLow *shared __attribute__((swift_name("shared")));

/**
 * Triggers when device storage is low - **ANDROID ONLY**.
 *
 * **⚠️ DEPRECATED**: Use `Constraints(systemConstraints = setOf(SystemConstraint.ALLOW_LOW_STORAGE))` instead.
 *
 * This incorrectly represented a constraint as a trigger. The new API correctly models this
 * as a constraint that allows tasks to run when storage is low.
 *
 * **Migration**:
 * ```kotlin
 * // Old (v2.x):
 * scheduler.enqueue(id, trigger = TaskTrigger.StorageLow, ...)
 *
 * // New (v3.0.0+):
 * scheduler.enqueue(
 *     id,
 *     trigger = TaskTrigger.OneTime(),
 *     constraints = Constraints(systemConstraints = setOf(SystemConstraint.ALLOW_LOW_STORAGE))
 * )
 * ```
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Triggers when device storage is low - **ANDROID ONLY**.
 *
 * **⚠️ DEPRECATED**: Use `Constraints(systemConstraints = setOf(SystemConstraint.ALLOW_LOW_STORAGE))` instead.
 *
 * This incorrectly represented a constraint as a trigger. The new API correctly models this
 * as a constraint that allows tasks to run when storage is low.
 *
 * **Migration**:
 * ```kotlin
 * // Old (v2.x):
 * scheduler.enqueue(id, trigger = TaskTrigger.StorageLow, ...)
 *
 * // New (v3.0.0+):
 * scheduler.enqueue(
 *     id,
 *     trigger = TaskTrigger.OneTime(),
 *     constraints = Constraints(systemConstraints = setOf(SystemConstraint.ALLOW_LOW_STORAGE))
 * )
 * ```
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Triggers when device storage is low - **ANDROID ONLY**.
 *
 * **⚠️ DEPRECATED**: Use `Constraints(systemConstraints = setOf(SystemConstraint.ALLOW_LOW_STORAGE))` instead.
 *
 * This incorrectly represented a constraint as a trigger. The new API correctly models this
 * as a constraint that allows tasks to run when storage is low.
 *
 * **Migration**:
 * ```kotlin
 * // Old (v2.x):
 * scheduler.enqueue(id, trigger = TaskTrigger.StorageLow, ...)
 *
 * // New (v3.0.0+):
 * scheduler.enqueue(
 *     id,
 *     trigger = TaskTrigger.OneTime(),
 *     constraints = Constraints(systemConstraints = setOf(SystemConstraint.ALLOW_LOW_STORAGE))
 * )
 * ```
 */
- (NSString *)description __attribute__((swift_name("description()")));
@end


/**
 * Triggers within a time window - **NOT IMPLEMENTED**.
 *
 * Allows the OS to optimize execution by choosing best time within window.
 *
 * @param earliest Earliest time to execute (Unix epoch milliseconds)
 * @param latest Latest time to execute (Unix epoch milliseconds)
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskTriggerWindowed")))
@interface KMPWMTaskTriggerWindowed : KMPWMBase <KMPWMTaskTrigger>
- (instancetype)initWithEarliest:(int64_t)earliest latest:(int64_t)latest __attribute__((swift_name("init(earliest:latest:)"))) __attribute__((objc_designated_initializer));
- (KMPWMTaskTriggerWindowed *)doCopyEarliest:(int64_t)earliest latest:(int64_t)latest __attribute__((swift_name("doCopy(earliest:latest:)")));

/**
 * Triggers within a time window - **NOT IMPLEMENTED**.
 *
 * Allows the OS to optimize execution by choosing best time within window.
 *
 * @param earliest Earliest time to execute (Unix epoch milliseconds)
 * @param latest Latest time to execute (Unix epoch milliseconds)
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Triggers within a time window - **NOT IMPLEMENTED**.
 *
 * Allows the OS to optimize execution by choosing best time within window.
 *
 * @param earliest Earliest time to execute (Unix epoch milliseconds)
 * @param latest Latest time to execute (Unix epoch milliseconds)
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Triggers within a time window - **NOT IMPLEMENTED**.
 *
 * Allows the OS to optimize execution by choosing best time within window.
 *
 * @param earliest Earliest time to execute (Unix epoch milliseconds)
 * @param latest Latest time to execute (Unix epoch milliseconds)
 */
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int64_t earliest __attribute__((swift_name("earliest")));
@property (readonly) int64_t latest __attribute__((swift_name("latest")));
@end


/**
 * Worker diagnostics interface for debugging "why didn't my task run?"
 * v2.2.2+ feature to improve developer experience
 *
 * **Use cases:**
 * - Debug screen in sample app
 * - Production monitoring dashboards
 * - Customer support diagnostics
 * - Automated health checks
 *
 * **Example:**
 * ```kotlin
 * val diagnostics = WorkerDiagnostics.getInstance()
 * val health = diagnostics.getSystemHealth()
 *
 * if (health.isLowPowerMode) {
 *     println("BGTasks may be throttled - device in low power mode")
 * }
 * if (health.isStorageLow) {
 *     println("Storage critical - tasks may fail")
 * }
 * ```
 */
__attribute__((swift_name("WorkerDiagnostics")))
@protocol KMPWMWorkerDiagnostics
@required

/**
 * Get current scheduler status
 * @return Scheduler status snapshot
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getSchedulerStatusWithCompletionHandler:(void (^)(KMPWMSchedulerStatus * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getSchedulerStatus(completionHandler:)")));

/**
 * Get system health report (battery, storage, network, power mode)
 * @return System health snapshot
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getSystemHealthWithCompletionHandler:(void (^)(KMPWMSystemHealthReport * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getSystemHealth(completionHandler:)")));

/**
 * Get detailed status for a specific task
 * @param id Task ID
 * @return Task status or null if not found
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getTaskStatusId:(NSString *)id completionHandler:(void (^)(KMPWMTaskStatusDetail * _Nullable_result, NSError * _Nullable))completionHandler __attribute__((swift_name("getTaskStatus(id:completionHandler:)")));
@end


/**
 * Represents the progress of a background task.
 *
 * Workers can report progress to provide real-time feedback to the UI,
 * especially important for long-running operations like:
 * - File downloads/uploads
 * - Data processing
 * - Batch operations
 * - Image compression
 *
 * **Usage in Worker (v2.3.0+):**
 * ```kotlin
 * class FileDownloadWorker(
 *     private val progressListener: ProgressListener?
 * ) : Worker {
 *     override suspend fun doWork(input: String?): WorkerResult {
 *         return try {
 *             val totalBytes = getTotalFileSize()
 *             var downloaded = 0L
 *
 *             while (downloaded < totalBytes) {
 *                 val chunk = downloadChunk()
 *                 downloaded += chunk.size
 *
 *                 val progress = (downloaded * 100 / totalBytes).toInt()
 *                 progressListener?.onProgressUpdate(
 *                     WorkerProgress(
 *                         progress = progress,
 *                         message = "Downloaded $downloaded / $totalBytes bytes"
 *                     )
 *                 )
 *             }
 *
 *             WorkerResult.Success(
 *                 message = "Downloaded $totalBytes bytes",
 *                 data = mapOf("fileSize" to totalBytes)
 *             )
 *         } catch (e: Exception) {
 *             WorkerResult.Failure("Download failed: ${e.message}")
 *         }
 *     }
 * }
 * ```
 *
 * **Usage in UI:**
 * ```kotlin
 * val progressFlow = TaskEventBus.events.filterIsInstance<TaskProgressEvent>()
 *
 * LaunchedEffect(Unit) {
 *     progressFlow.collect { event ->
 *         progressBar.value = event.progress.progress
 *         statusText.value = event.progress.message
 *     }
 * }
 * ```
 *
 * @property progress Progress percentage (0-100)
 * @property message Optional human-readable progress message
 * @property currentStep Optional current step in multi-step process
 * @property totalSteps Optional total number of steps
 *
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("WorkerProgress")))
@interface KMPWMWorkerProgress : KMPWMBase
- (instancetype)initWithProgress:(int32_t)progress message:(NSString * _Nullable)message currentStep:(KMPWMInt * _Nullable)currentStep totalSteps:(KMPWMInt * _Nullable)totalSteps __attribute__((swift_name("init(progress:message:currentStep:totalSteps:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMWorkerProgressCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMWorkerProgress *)doCopyProgress:(int32_t)progress message:(NSString * _Nullable)message currentStep:(KMPWMInt * _Nullable)currentStep totalSteps:(KMPWMInt * _Nullable)totalSteps __attribute__((swift_name("doCopy(progress:message:currentStep:totalSteps:)")));

/**
 * Represents the progress of a background task.
 *
 * Workers can report progress to provide real-time feedback to the UI,
 * especially important for long-running operations like:
 * - File downloads/uploads
 * - Data processing
 * - Batch operations
 * - Image compression
 *
 * **Usage in Worker (v2.3.0+):**
 * ```kotlin
 * class FileDownloadWorker(
 *     private val progressListener: ProgressListener?
 * ) : Worker {
 *     override suspend fun doWork(input: String?): WorkerResult {
 *         return try {
 *             val totalBytes = getTotalFileSize()
 *             var downloaded = 0L
 *
 *             while (downloaded < totalBytes) {
 *                 val chunk = downloadChunk()
 *                 downloaded += chunk.size
 *
 *                 val progress = (downloaded * 100 / totalBytes).toInt()
 *                 progressListener?.onProgressUpdate(
 *                     WorkerProgress(
 *                         progress = progress,
 *                         message = "Downloaded $downloaded / $totalBytes bytes"
 *                     )
 *                 )
 *             }
 *
 *             WorkerResult.Success(
 *                 message = "Downloaded $totalBytes bytes",
 *                 data = mapOf("fileSize" to totalBytes)
 *             )
 *         } catch (e: Exception) {
 *             WorkerResult.Failure("Download failed: ${e.message}")
 *         }
 *     }
 * }
 * ```
 *
 * **Usage in UI:**
 * ```kotlin
 * val progressFlow = TaskEventBus.events.filterIsInstance<TaskProgressEvent>()
 *
 * LaunchedEffect(Unit) {
 *     progressFlow.collect { event ->
 *         progressBar.value = event.progress.progress
 *         statusText.value = event.progress.message
 *     }
 * }
 * ```
 *
 * @property progress Progress percentage (0-100)
 * @property message Optional human-readable progress message
 * @property currentStep Optional current step in multi-step process
 * @property totalSteps Optional total number of steps
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Represents the progress of a background task.
 *
 * Workers can report progress to provide real-time feedback to the UI,
 * especially important for long-running operations like:
 * - File downloads/uploads
 * - Data processing
 * - Batch operations
 * - Image compression
 *
 * **Usage in Worker (v2.3.0+):**
 * ```kotlin
 * class FileDownloadWorker(
 *     private val progressListener: ProgressListener?
 * ) : Worker {
 *     override suspend fun doWork(input: String?): WorkerResult {
 *         return try {
 *             val totalBytes = getTotalFileSize()
 *             var downloaded = 0L
 *
 *             while (downloaded < totalBytes) {
 *                 val chunk = downloadChunk()
 *                 downloaded += chunk.size
 *
 *                 val progress = (downloaded * 100 / totalBytes).toInt()
 *                 progressListener?.onProgressUpdate(
 *                     WorkerProgress(
 *                         progress = progress,
 *                         message = "Downloaded $downloaded / $totalBytes bytes"
 *                     )
 *                 )
 *             }
 *
 *             WorkerResult.Success(
 *                 message = "Downloaded $totalBytes bytes",
 *                 data = mapOf("fileSize" to totalBytes)
 *             )
 *         } catch (e: Exception) {
 *             WorkerResult.Failure("Download failed: ${e.message}")
 *         }
 *     }
 * }
 * ```
 *
 * **Usage in UI:**
 * ```kotlin
 * val progressFlow = TaskEventBus.events.filterIsInstance<TaskProgressEvent>()
 *
 * LaunchedEffect(Unit) {
 *     progressFlow.collect { event ->
 *         progressBar.value = event.progress.progress
 *         statusText.value = event.progress.message
 *     }
 * }
 * ```
 *
 * @property progress Progress percentage (0-100)
 * @property message Optional human-readable progress message
 * @property currentStep Optional current step in multi-step process
 * @property totalSteps Optional total number of steps
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Get a formatted progress string for display.
 *
 * Examples:
 * - "50%"
 * - "50% - Downloading file"
 * - "Step 3/5 - Processing data"
 */
- (NSString *)toDisplayString __attribute__((swift_name("toDisplayString()")));

/**
 * Represents the progress of a background task.
 *
 * Workers can report progress to provide real-time feedback to the UI,
 * especially important for long-running operations like:
 * - File downloads/uploads
 * - Data processing
 * - Batch operations
 * - Image compression
 *
 * **Usage in Worker (v2.3.0+):**
 * ```kotlin
 * class FileDownloadWorker(
 *     private val progressListener: ProgressListener?
 * ) : Worker {
 *     override suspend fun doWork(input: String?): WorkerResult {
 *         return try {
 *             val totalBytes = getTotalFileSize()
 *             var downloaded = 0L
 *
 *             while (downloaded < totalBytes) {
 *                 val chunk = downloadChunk()
 *                 downloaded += chunk.size
 *
 *                 val progress = (downloaded * 100 / totalBytes).toInt()
 *                 progressListener?.onProgressUpdate(
 *                     WorkerProgress(
 *                         progress = progress,
 *                         message = "Downloaded $downloaded / $totalBytes bytes"
 *                     )
 *                 )
 *             }
 *
 *             WorkerResult.Success(
 *                 message = "Downloaded $totalBytes bytes",
 *                 data = mapOf("fileSize" to totalBytes)
 *             )
 *         } catch (e: Exception) {
 *             WorkerResult.Failure("Download failed: ${e.message}")
 *         }
 *     }
 * }
 * ```
 *
 * **Usage in UI:**
 * ```kotlin
 * val progressFlow = TaskEventBus.events.filterIsInstance<TaskProgressEvent>()
 *
 * LaunchedEffect(Unit) {
 *     progressFlow.collect { event ->
 *         progressBar.value = event.progress.progress
 *         statusText.value = event.progress.message
 *     }
 * }
 * ```
 *
 * @property progress Progress percentage (0-100)
 * @property message Optional human-readable progress message
 * @property currentStep Optional current step in multi-step process
 * @property totalSteps Optional total number of steps
 */
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

/**
 * Create progress for a specific step in a multi-step process.
 */
- (KMPWMWorkerProgress *)forStepStep:(int32_t)step totalSteps:(int32_t)totalSteps message:(NSString * _Nullable)message __attribute__((swift_name("forStep(step:totalSteps:message:)")));
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * Result type for Worker execution.
 *
 * This sealed class provides a rich return type for workers, allowing them to:
 * - Return success/failure status
 * - Include optional messages
 * - Pass output data back to the caller
 * - Control retry behavior
 *
 * v2.3.0+: Introduced to support returning data from workers
 *
 * Example:
 * ```kotlin
 * class DataFetchWorker : Worker {
 *     override suspend fun doWork(input: String?): WorkerResult {
 *         return try {
 *             val data = fetchData()
 *             WorkerResult.Success(
 *                 message = "Fetched ${data.size} items",
 *                 data = mapOf(
 *                     "count" to data.size,
 *                     "items" to data
 *                 )
 *             )
 *         } catch (e: Exception) {
 *             WorkerResult.Failure(
 *                 message = "Failed: ${e.message}",
 *                 shouldRetry = true
 *             )
 *         }
 *     }
 * }
 * ```
 */
__attribute__((swift_name("WorkerResult")))
@interface KMPWMWorkerResult : KMPWMBase
@end


/**
 * Represents failed worker execution.
 *
 * @param message Error message describing the failure
 * @param shouldRetry Whether the task should be retried (hint for future retry logic)
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("WorkerResult.Failure")))
@interface KMPWMWorkerResultFailure : KMPWMWorkerResult
- (instancetype)initWithMessage:(NSString *)message shouldRetry:(BOOL)shouldRetry __attribute__((swift_name("init(message:shouldRetry:)"))) __attribute__((objc_designated_initializer));
- (KMPWMWorkerResultFailure *)doCopyMessage:(NSString *)message shouldRetry:(BOOL)shouldRetry __attribute__((swift_name("doCopy(message:shouldRetry:)")));

/**
 * Represents failed worker execution.
 *
 * @param message Error message describing the failure
 * @param shouldRetry Whether the task should be retried (hint for future retry logic)
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Represents failed worker execution.
 *
 * @param message Error message describing the failure
 * @param shouldRetry Whether the task should be retried (hint for future retry logic)
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Represents failed worker execution.
 *
 * @param message Error message describing the failure
 * @param shouldRetry Whether the task should be retried (hint for future retry logic)
 */
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *message __attribute__((swift_name("message")));
@property (readonly) BOOL shouldRetry __attribute__((swift_name("shouldRetry")));
@end


/**
 * Represents successful worker execution.
 *
 * @param message Optional success message
 * @param data Optional output data to be passed to listeners via TaskCompletionEvent
 * @param dataClass Optional hint for the data class name (for future typed deserialization)
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("WorkerResult.Success")))
@interface KMPWMWorkerResultSuccess : KMPWMWorkerResult
- (instancetype)initWithMessage:(NSString * _Nullable)message data:(NSDictionary<NSString *, id> * _Nullable)data dataClass:(NSString * _Nullable)dataClass __attribute__((swift_name("init(message:data:dataClass:)"))) __attribute__((objc_designated_initializer));
- (KMPWMWorkerResultSuccess *)doCopyMessage:(NSString * _Nullable)message data:(NSDictionary<NSString *, id> * _Nullable)data dataClass:(NSString * _Nullable)dataClass __attribute__((swift_name("doCopy(message:data:dataClass:)")));

/**
 * Represents successful worker execution.
 *
 * @param message Optional success message
 * @param data Optional output data to be passed to listeners via TaskCompletionEvent
 * @param dataClass Optional hint for the data class name (for future typed deserialization)
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Represents successful worker execution.
 *
 * @param message Optional success message
 * @param data Optional output data to be passed to listeners via TaskCompletionEvent
 * @param dataClass Optional hint for the data class name (for future typed deserialization)
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Represents successful worker execution.
 *
 * @param message Optional success message
 * @param data Optional output data to be passed to listeners via TaskCompletionEvent
 * @param dataClass Optional hint for the data class name (for future typed deserialization)
 */
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSDictionary<NSString *, id> * _Nullable data __attribute__((swift_name("data")));
@property (readonly) NSString * _Nullable dataClass __attribute__((swift_name("dataClass")));
@property (readonly) NSString * _Nullable message __attribute__((swift_name("message")));
@end


/**
 * Persistent storage for task completion events.
 *
 * Events are stored to survive app restarts and force-quits,
 * ensuring no event loss when UI is not actively listening.
 *
 * Implementation Strategy:
 * - Android: SQLDelight with SQLite database
 * - iOS: File-based storage (IosFileStorage) for consistency
 *
 * Lifecycle:
 * 1. Worker completes task → emit to EventBus + saveEvent()
 * 2. App launches → getUnconsumedEvents() + replay to EventBus
 * 3. UI processes event → markEventConsumed()
 * 4. Periodic cleanup → clearOldEvents()
 *
 * Performance:
 * - Target: <100ms for getUnconsumedEvents()
 * - Auto-cleanup events older than 7 days
 * - Maximum 1000 events stored
 */
__attribute__((swift_name("EventStore")))
@protocol KMPWMEventStore
@required

/**
 * Deletes all events from storage.
 * Use with caution - primarily for testing.
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)clearAllWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("clearAll(completionHandler:)")));

/**
 * Removes events older than the specified time.
 *
 * @param olderThanMs Timestamp in milliseconds (events older than this are deleted)
 * @return Number of events deleted
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)clearOldEventsOlderThanMs:(int64_t)olderThanMs completionHandler:(void (^)(KMPWMInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("clearOldEvents(olderThanMs:completionHandler:)")));

/**
 * Returns the total number of events in storage.
 * Useful for monitoring and debugging.
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getEventCountWithCompletionHandler:(void (^)(KMPWMInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getEventCount(completionHandler:)")));

/**
 * Retrieves all events that have not been consumed by the UI.
 *
 * Events are ordered by timestamp (oldest first).
 *
 * @return List of unconsumed events
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)getUnconsumedEventsWithCompletionHandler:(void (^)(NSArray<KMPWMStoredEvent *> * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getUnconsumedEvents(completionHandler:)")));

/**
 * Marks an event as consumed by the UI.
 *
 * Consumed events are eligible for cleanup but remain in storage
 * for a grace period (configurable, default 1 hour).
 *
 * @param eventId The ID of the event to mark as consumed
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)markEventConsumedEventId:(NSString *)eventId completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("markEventConsumed(eventId:completionHandler:)")));

/**
 * Saves an event to persistent storage.
 *
 * @param event The event to save
 * @return Unique event ID for tracking
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)saveEventEvent:(KMPWMTaskCompletionEvent *)event completionHandler:(void (^)(NSString * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("saveEvent(event:completionHandler:)")));
@end


/**
 * Configuration for event storage behavior.
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("EventStoreConfig")))
@interface KMPWMEventStoreConfig : KMPWMBase
- (instancetype)initWithMaxEvents:(int32_t)maxEvents consumedEventRetentionMs:(int64_t)consumedEventRetentionMs unconsumedEventRetentionMs:(int64_t)unconsumedEventRetentionMs autoCleanup:(BOOL)autoCleanup cleanupIntervalMs:(int64_t)cleanupIntervalMs cleanupFileSizeThresholdBytes:(int64_t)cleanupFileSizeThresholdBytes __attribute__((swift_name("init(maxEvents:consumedEventRetentionMs:unconsumedEventRetentionMs:autoCleanup:cleanupIntervalMs:cleanupFileSizeThresholdBytes:)"))) __attribute__((objc_designated_initializer));
- (KMPWMEventStoreConfig *)doCopyMaxEvents:(int32_t)maxEvents consumedEventRetentionMs:(int64_t)consumedEventRetentionMs unconsumedEventRetentionMs:(int64_t)unconsumedEventRetentionMs autoCleanup:(BOOL)autoCleanup cleanupIntervalMs:(int64_t)cleanupIntervalMs cleanupFileSizeThresholdBytes:(int64_t)cleanupFileSizeThresholdBytes __attribute__((swift_name("doCopy(maxEvents:consumedEventRetentionMs:unconsumedEventRetentionMs:autoCleanup:cleanupIntervalMs:cleanupFileSizeThresholdBytes:)")));

/**
 * Configuration for event storage behavior.
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Configuration for event storage behavior.
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Configuration for event storage behavior.
 */
- (NSString *)description __attribute__((swift_name("description()")));

/**
 * Whether to auto-cleanup on each write operation.
 * If false, cleanup must be triggered manually.
 */
@property (readonly) BOOL autoCleanup __attribute__((swift_name("autoCleanup")));

/**
 * FIX: File size threshold for cleanup (v2.2.2+)
 * Trigger cleanup when file size exceeds this threshold (in bytes).
 * Default: 1MB (1048576 bytes)
 */
@property (readonly) int64_t cleanupFileSizeThresholdBytes __attribute__((swift_name("cleanupFileSizeThresholdBytes")));

/**
 * FIX: Deterministic cleanup interval (v2.2.2+)
 * Minimum time between cleanup runs (in milliseconds).
 * Default: 5 minutes (300000ms)
 * Replaces probabilistic 10% cleanup with time-based strategy.
 */
@property (readonly) int64_t cleanupIntervalMs __attribute__((swift_name("cleanupIntervalMs")));

/**
 * How long to keep consumed events (in milliseconds).
 * Default: 1 hour
 */
@property (readonly) int64_t consumedEventRetentionMs __attribute__((swift_name("consumedEventRetentionMs")));

/**
 * Maximum number of events to keep in storage.
 * Oldest events are deleted when limit is exceeded.
 */
@property (readonly) int32_t maxEvents __attribute__((swift_name("maxEvents")));

/**
 * How long to keep unconsumed events (in milliseconds).
 * Default: 7 days
 */
@property (readonly) int64_t unconsumedEventRetentionMs __attribute__((swift_name("unconsumedEventRetentionMs")));
@end


/**
 * iOS implementation of EventStore using file-based storage.
 *
 * Features:
 * - JSONL (JSON Lines) format for efficient append operations
 * - Thread-safe operations using Mutex + NSFileCoordinator
 * - Atomic writes using NSFileCoordinator for coordination
 * - Automatic cleanup of old/consumed events
 * - Zero external dependencies (uses Foundation APIs)
 *
 * Storage Location:
 * Library/Application Support/dev.brewkits.kmpworkmanager/events/events.jsonl
 *
 * Performance:
 * - Write: ~5ms (append to file)
 * - Read: ~50ms (scan 1000 events)
 * - Storage: ~200KB (1000 events × 200 bytes)
 */
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
 * Event with additional metadata for persistence.
 *
 * @property id Unique identifier for this event
 * @property event The actual task completion event
 * @property timestamp When the event was created (milliseconds since epoch)
 * @property consumed Whether the UI has processed this event
 *
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("StoredEvent")))
@interface KMPWMStoredEvent : KMPWMBase
- (instancetype)initWithId:(NSString *)id event:(KMPWMTaskCompletionEvent *)event timestamp:(int64_t)timestamp consumed:(BOOL)consumed __attribute__((swift_name("init(id:event:timestamp:consumed:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMStoredEventCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMStoredEvent *)doCopyId:(NSString *)id event:(KMPWMTaskCompletionEvent *)event timestamp:(int64_t)timestamp consumed:(BOOL)consumed __attribute__((swift_name("doCopy(id:event:timestamp:consumed:)")));

/**
 * Event with additional metadata for persistence.
 *
 * @property id Unique identifier for this event
 * @property event The actual task completion event
 * @property timestamp When the event was created (milliseconds since epoch)
 * @property consumed Whether the UI has processed this event
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Event with additional metadata for persistence.
 *
 * @property id Unique identifier for this event
 * @property event The actual task completion event
 * @property timestamp When the event was created (milliseconds since epoch)
 * @property consumed Whether the UI has processed this event
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Event with additional metadata for persistence.
 *
 * @property id Unique identifier for this event
 * @property event The actual task completion event
 * @property timestamp When the event was created (milliseconds since epoch)
 * @property consumed Whether the UI has processed this event
 */
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) BOOL consumed __attribute__((swift_name("consumed")));
@property (readonly) KMPWMTaskCompletionEvent *event __attribute__((swift_name("event")));
@property (readonly) NSString *id __attribute__((swift_name("id")));
@property (readonly) int64_t timestamp __attribute__((swift_name("timestamp")));
@end


/**
 * Event with additional metadata for persistence.
 *
 * @property id Unique identifier for this event
 * @property event The actual task completion event
 * @property timestamp When the event was created (milliseconds since epoch)
 * @property consumed Whether the UI has processed this event
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("StoredEvent.Companion")))
@interface KMPWMStoredEventCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Event with additional metadata for persistence.
 *
 * @property id Unique identifier for this event
 * @property event The actual task completion event
 * @property timestamp When the event was created (milliseconds since epoch)
 * @property consumed Whether the UI has processed this event
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMStoredEventCompanion *shared __attribute__((swift_name("shared")));

/**
 * Event with additional metadata for persistence.
 *
 * @property id Unique identifier for this event
 * @property event The actual task completion event
 * @property timestamp When the event was created (milliseconds since epoch)
 * @property consumed Whether the UI has processed this event
 */
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * CRC32 checksum calculator for data integrity verification
 *
 * **v2.2.2 Performance Upgrade:**
 * - Now uses platform-native implementations for 5-10x speedup
 * - iOS: zlib.crc32 (native C implementation)
 * - Android: java.util.zip.CRC32 (optimized JVM implementation)
 * - Maintains 100% API compatibility with pure Kotlin version
 *
 * **Features:**
 * - IEEE 802.3 polynomial (0xEDB88320)
 * - Platform-optimized implementations
 * - Extension functions for convenience
 * - Validates data integrity in append-only queue
 *
 * **Usage:**
 * ```kotlin
 * val data = "Hello, World!".encodeToByteArray()
 * val checksum = CRC32.calculate(data)
 *
 * // Or use extension function
 * val checksum2 = data.crc32()
 *
 * // Verification
 * val isValid = CRC32.verify(data, checksum)
 * ```
 *
 * **Performance:**
 * - iOS (zlib): ~0.2ms for 1MB, ~2ms for 10MB (5-10x faster than pure Kotlin)
 * - Android (java.util.zip): ~0.1ms for 1MB, ~1ms for 10MB (10x faster than pure Kotlin)
 * - Benchmark results on iPhone 13 Pro / Pixel 7 Pro
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("CRC32")))
@interface KMPWMCRC32 : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * CRC32 checksum calculator for data integrity verification
 *
 * **v2.2.2 Performance Upgrade:**
 * - Now uses platform-native implementations for 5-10x speedup
 * - iOS: zlib.crc32 (native C implementation)
 * - Android: java.util.zip.CRC32 (optimized JVM implementation)
 * - Maintains 100% API compatibility with pure Kotlin version
 *
 * **Features:**
 * - IEEE 802.3 polynomial (0xEDB88320)
 * - Platform-optimized implementations
 * - Extension functions for convenience
 * - Validates data integrity in append-only queue
 *
 * **Usage:**
 * ```kotlin
 * val data = "Hello, World!".encodeToByteArray()
 * val checksum = CRC32.calculate(data)
 *
 * // Or use extension function
 * val checksum2 = data.crc32()
 *
 * // Verification
 * val isValid = CRC32.verify(data, checksum)
 * ```
 *
 * **Performance:**
 * - iOS (zlib): ~0.2ms for 1MB, ~2ms for 10MB (5-10x faster than pure Kotlin)
 * - Android (java.util.zip): ~0.1ms for 1MB, ~1ms for 10MB (10x faster than pure Kotlin)
 * - Benchmark results on iPhone 13 Pro / Pixel 7 Pro
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)cRC32 __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMCRC32 *shared __attribute__((swift_name("shared")));

/**
 * Calculate CRC32 checksum for a byte array using platform-native implementation
 *
 * @param data Input data
 * @return CRC32 checksum (32-bit unsigned integer)
 */
- (uint32_t)calculateData:(KMPWMKotlinByteArray *)data __attribute__((swift_name("calculate(data:)")));

/**
 * Calculate CRC32 checksum for a string (UTF-8 encoded)
 *
 * @param data Input string
 * @return CRC32 checksum (32-bit unsigned integer)
 */
- (uint32_t)calculateData_:(NSString *)data __attribute__((swift_name("calculate(data_:)")));

/**
 * Verify CRC32 checksum
 *
 * @param data Input data
 * @param expectedCrc Expected checksum value
 * @return true if checksum matches, false otherwise
 */
- (BOOL)verifyData:(KMPWMKotlinByteArray *)data expectedCrc:(uint32_t)expectedCrc __attribute__((swift_name("verify(data:expectedCrc:)")));

/**
 * Verify CRC32 checksum for a string
 *
 * @param data Input string
 * @param expectedCrc Expected checksum value
 * @return true if checksum matches, false otherwise
 */
- (BOOL)verifyData:(NSString *)data expectedCrc_:(uint32_t)expectedCrc __attribute__((swift_name("verify(data:expectedCrc_:)")));
@end


/**
 * Custom logger interface for delegating log output.
 * Implement this interface to send logs to custom destinations (analytics, crash reporting, etc.)
 *
 * Example:
 * ```
 * class FirebaseLogger : CustomLogger {
 *     override fun log(level: Logger.Level, tag: String, message: String, throwable: Throwable?) {
 *         when (level) {
 *             Logger.Level.ERROR -> FirebaseCrashlytics.log("ERROR: [$tag] $message")
 *             Logger.Level.WARN -> FirebaseCrashlytics.log("WARN: [$tag] $message")
 *             else -> println("[$tag] $message")
 *         }
 *         throwable?.let { FirebaseCrashlytics.recordException(it) }
 *     }
 * }
 * ```
 */
__attribute__((swift_name("CustomLogger")))
@protocol KMPWMCustomLogger
@required

/**
 * Log a message with the specified level, tag, and optional throwable.
 *
 * @param level The log level (VERBOSE, DEBUG_LEVEL, INFO, WARN, ERROR)
 * @param tag The log tag for categorization
 * @param message The log message
 * @param throwable Optional exception to log
 */
- (void)logLevel:(KMPWMLoggerLevel *)level tag:(NSString *)tag message:(NSString *)message throwable:(KMPWMKotlinThrowable * _Nullable)throwable __attribute__((swift_name("log(level:tag:message:throwable:)")));
@end


/**
 * Predefined log tags for consistent logging across the app
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("LogTags")))
@interface KMPWMLogTags : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Predefined log tags for consistent logging across the app
 */
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


/**
 * Professional logging utility for KMP WorkManager.
 * Provides structured logging with levels, tags, and platform-specific formatting.
 *
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Logger")))
@interface KMPWMLogger : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Professional logging utility for KMP WorkManager.
 * Provides structured logging with levels, tags, and platform-specific formatting.
 *
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)logger __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMLogger *shared __attribute__((swift_name("shared")));

/**
 * Log debug message - verbose information for development
 */
- (void)dTag:(NSString *)tag message:(NSString *)message throwable:(KMPWMKotlinThrowable * _Nullable)throwable __attribute__((swift_name("d(tag:message:throwable:)")));

/**
 * Log error message - error events that might still allow the app to continue
 */
- (void)eTag:(NSString *)tag message:(NSString *)message throwable:(KMPWMKotlinThrowable * _Nullable)throwable __attribute__((swift_name("e(tag:message:throwable:)")));

/**
 * Log info message - general informational messages
 */
- (void)iTag:(NSString *)tag message:(NSString *)message throwable:(KMPWMKotlinThrowable * _Nullable)throwable __attribute__((swift_name("i(tag:message:throwable:)")));

/**
 * Set a custom logger implementation. All logs will be delegated to this logger.
 *
 * Example:
 * ```
 * Logger.setCustomLogger(object : CustomLogger {
 *     override fun log(level: Logger.Level, tag: String, message: String, throwable: Throwable?) {
 *         // Send to analytics service
 *     }
 * })
 * ```
 */
- (void)setCustomLoggerLogger:(id<KMPWMCustomLogger> _Nullable)logger __attribute__((swift_name("setCustomLogger(logger:)")));

/**
 * Set the minimum log level. Logs below this level will be filtered out.
 *
 * Example:
 * ```
 * Logger.setMinLevel(Logger.Level.INFO)  // Only log INFO, WARN, ERROR
 * ```
 */
- (void)setMinLevelLevel:(KMPWMLoggerLevel *)level __attribute__((swift_name("setMinLevel(level:)")));

/**
 * Log verbose message - high-frequency operational details
 *
 * Examples: Individual enqueue/dequeue operations, byte-level I/O
 */
- (void)vTag:(NSString *)tag message:(NSString *)message throwable:(KMPWMKotlinThrowable * _Nullable)throwable __attribute__((swift_name("v(tag:message:throwable:)")));

/**
 * Log warning message - potentially harmful situations
 */
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


/**
 * Registry for built-in workers provided by KMP WorkManager.
 *
 * This factory can be used standalone or composed with your custom worker factory.
 *
 * **Built-in Workers:**
 * - `HttpRequestWorker`: Generic HTTP requests (GET, POST, PUT, DELETE, PATCH)
 * - `HttpSyncWorker`: JSON synchronization (POST/GET JSON data)
 * - `HttpDownloadWorker`: Download files from HTTP/HTTPS URLs
 * - `HttpUploadWorker`: Upload files using multipart/form-data
 * - `FileCompressionWorker`: Compress files/directories into ZIP archives
 *
 * **Usage (Standalone):**
 * ```kotlin
 * KmpWorkManager.initialize(
 *     context = this,
 *     workerFactory = BuiltinWorkerRegistry
 * )
 * ```
 *
 * **Usage (Composed with Custom Workers):**
 * ```kotlin
 * class MyWorkerFactory : WorkerFactory {
 *     override fun createWorker(workerClassName: String): Worker? {
 *         return when(workerClassName) {
 *             "MyCustomWorker" -> MyCustomWorker()
 *             else -> null
 *         }
 *     }
 * }
 *
 * // Compose custom factory with built-in workers
 * KmpWorkManager.initialize(
 *     context = this,
 *     workerFactory = CompositeWorkerFactory(
 *         MyWorkerFactory(),
 *         BuiltinWorkerRegistry
 *     )
 * )
 * ```
 *
 * **Supported Worker Class Names:**
 * - "HttpRequestWorker" or "dev.brewkits.kmpworkmanager.workers.builtins.HttpRequestWorker"
 * - "HttpSyncWorker" or "dev.brewkits.kmpworkmanager.workers.builtins.HttpSyncWorker"
 * - "HttpDownloadWorker" or "dev.brewkits.kmpworkmanager.workers.builtins.HttpDownloadWorker"
 * - "HttpUploadWorker" or "dev.brewkits.kmpworkmanager.workers.builtins.HttpUploadWorker"
 * - "FileCompressionWorker" or "dev.brewkits.kmpworkmanager.workers.builtins.FileCompressionWorker"
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("BuiltinWorkerRegistry")))
@interface KMPWMBuiltinWorkerRegistry : KMPWMBase <KMPWMWorkerFactory>
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Registry for built-in workers provided by KMP WorkManager.
 *
 * This factory can be used standalone or composed with your custom worker factory.
 *
 * **Built-in Workers:**
 * - `HttpRequestWorker`: Generic HTTP requests (GET, POST, PUT, DELETE, PATCH)
 * - `HttpSyncWorker`: JSON synchronization (POST/GET JSON data)
 * - `HttpDownloadWorker`: Download files from HTTP/HTTPS URLs
 * - `HttpUploadWorker`: Upload files using multipart/form-data
 * - `FileCompressionWorker`: Compress files/directories into ZIP archives
 *
 * **Usage (Standalone):**
 * ```kotlin
 * KmpWorkManager.initialize(
 *     context = this,
 *     workerFactory = BuiltinWorkerRegistry
 * )
 * ```
 *
 * **Usage (Composed with Custom Workers):**
 * ```kotlin
 * class MyWorkerFactory : WorkerFactory {
 *     override fun createWorker(workerClassName: String): Worker? {
 *         return when(workerClassName) {
 *             "MyCustomWorker" -> MyCustomWorker()
 *             else -> null
 *         }
 *     }
 * }
 *
 * // Compose custom factory with built-in workers
 * KmpWorkManager.initialize(
 *     context = this,
 *     workerFactory = CompositeWorkerFactory(
 *         MyWorkerFactory(),
 *         BuiltinWorkerRegistry
 *     )
 * )
 * ```
 *
 * **Supported Worker Class Names:**
 * - "HttpRequestWorker" or "dev.brewkits.kmpworkmanager.workers.builtins.HttpRequestWorker"
 * - "HttpSyncWorker" or "dev.brewkits.kmpworkmanager.workers.builtins.HttpSyncWorker"
 * - "HttpDownloadWorker" or "dev.brewkits.kmpworkmanager.workers.builtins.HttpDownloadWorker"
 * - "HttpUploadWorker" or "dev.brewkits.kmpworkmanager.workers.builtins.HttpUploadWorker"
 * - "FileCompressionWorker" or "dev.brewkits.kmpworkmanager.workers.builtins.FileCompressionWorker"
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)builtinWorkerRegistry __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMBuiltinWorkerRegistry *shared __attribute__((swift_name("shared")));

/**
 * Creates a built-in worker instance based on the class name.
 *
 * Supports both simple class names (e.g., "HttpRequestWorker") and
 * fully qualified names (e.g., "dev.brewkits.kmpworkmanager.workers.builtins.HttpRequestWorker").
 *
 * @param workerClassName The class name of the worker
 * @return Worker instance or null if not a built-in worker
 */
- (id<KMPWMWorker> _Nullable)createWorkerWorkerClassName:(NSString *)workerClassName __attribute__((swift_name("createWorker(workerClassName:)")));

/**
 * Returns a list of all built-in worker class names.
 *
 * @return List of fully qualified class names for all built-in workers
 */
- (NSArray<NSString *> *)listWorkers __attribute__((swift_name("listWorkers()")));
@end


/**
 * Composite worker factory that tries multiple factories in order.
 *
 * This allows you to combine your custom workers with built-in workers.
 * The first factory to return a non-null worker wins.
 *
 * **Usage:**
 * ```kotlin
 * class MyWorkerFactory : WorkerFactory {
 *     override fun createWorker(workerClassName: String): Worker? {
 *         return when(workerClassName) {
 *             "MyWorker" -> MyWorker()
 *             else -> null
 *         }
 *     }
 * }
 *
 * val compositeFactory = CompositeWorkerFactory(
 *     MyWorkerFactory(),      // Try custom workers first
 *     BuiltinWorkerRegistry   // Fall back to built-in workers
 * )
 * ```
 *
 * @property factories List of worker factories to try in order
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("CompositeWorkerFactory")))
@interface KMPWMCompositeWorkerFactory : KMPWMBase <KMPWMWorkerFactory>
- (instancetype)initWithFactories:(KMPWMKotlinArray<id<KMPWMWorkerFactory>> *)factories __attribute__((swift_name("init(factories:)"))) __attribute__((objc_designated_initializer));
- (id<KMPWMWorker> _Nullable)createWorkerWorkerClassName:(NSString *)workerClassName __attribute__((swift_name("createWorker(workerClassName:)")));
@end


/**
 * Built-in worker for compressing files and directories into ZIP archives.
 *
 * Features:
 * - Recursive directory compression
 * - Three compression levels: low (fast), medium (balanced), high (best compression)
 * - Exclude patterns support (*.tmp, .DS_Store, etc.)
 * - Optional deletion of original files after compression
 * - Compression statistics logging
 *
 * **Platform Support:**
 * - Android: Uses java.util.zip.ZipOutputStream
 * - iOS: Uses platform ZIP APIs
 *
 * **Configuration Example:**
 * ```json
 * {
 *   "inputPath": "/path/to/file/or/directory",
 *   "outputPath": "/path/to/output.zip",
 *   "compressionLevel": "medium",
 *   "excludePatterns": ["*.tmp", ".DS_Store", "*.log"],
 *   "deleteOriginal": false
 * }
 * ```
 *
 * **Usage:**
 * ```kotlin
 * val config = Json.encodeToString(FileCompressionConfig.serializer(), FileCompressionConfig(
 *     inputPath = "/storage/logs",
 *     outputPath = "/storage/logs_backup.zip",
 *     compressionLevel = "high",
 *     excludePatterns = listOf("*.tmp", ".DS_Store")
 * ))
 *
 * scheduler.enqueue(
 *     id = "compress-logs",
 *     trigger = TaskTrigger.OneTime(),
 *     workerClassName = "FileCompressionWorker",
 *     inputJson = config
 * )
 * ```
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("FileCompressionWorker")))
@interface KMPWMFileCompressionWorker : KMPWMBase <KMPWMWorker>

/**
 * Built-in worker for compressing files and directories into ZIP archives.
 *
 * Features:
 * - Recursive directory compression
 * - Three compression levels: low (fast), medium (balanced), high (best compression)
 * - Exclude patterns support (*.tmp, .DS_Store, etc.)
 * - Optional deletion of original files after compression
 * - Compression statistics logging
 *
 * **Platform Support:**
 * - Android: Uses java.util.zip.ZipOutputStream
 * - iOS: Uses platform ZIP APIs
 *
 * **Configuration Example:**
 * ```json
 * {
 *   "inputPath": "/path/to/file/or/directory",
 *   "outputPath": "/path/to/output.zip",
 *   "compressionLevel": "medium",
 *   "excludePatterns": ["*.tmp", ".DS_Store", "*.log"],
 *   "deleteOriginal": false
 * }
 * ```
 *
 * **Usage:**
 * ```kotlin
 * val config = Json.encodeToString(FileCompressionConfig.serializer(), FileCompressionConfig(
 *     inputPath = "/storage/logs",
 *     outputPath = "/storage/logs_backup.zip",
 *     compressionLevel = "high",
 *     excludePatterns = listOf("*.tmp", ".DS_Store")
 * ))
 *
 * scheduler.enqueue(
 *     id = "compress-logs",
 *     trigger = TaskTrigger.OneTime(),
 *     workerClassName = "FileCompressionWorker",
 *     inputJson = config
 * )
 * ```
 */
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));

/**
 * Built-in worker for compressing files and directories into ZIP archives.
 *
 * Features:
 * - Recursive directory compression
 * - Three compression levels: low (fast), medium (balanced), high (best compression)
 * - Exclude patterns support (*.tmp, .DS_Store, etc.)
 * - Optional deletion of original files after compression
 * - Compression statistics logging
 *
 * **Platform Support:**
 * - Android: Uses java.util.zip.ZipOutputStream
 * - iOS: Uses platform ZIP APIs
 *
 * **Configuration Example:**
 * ```json
 * {
 *   "inputPath": "/path/to/file/or/directory",
 *   "outputPath": "/path/to/output.zip",
 *   "compressionLevel": "medium",
 *   "excludePatterns": ["*.tmp", ".DS_Store", "*.log"],
 *   "deleteOriginal": false
 * }
 * ```
 *
 * **Usage:**
 * ```kotlin
 * val config = Json.encodeToString(FileCompressionConfig.serializer(), FileCompressionConfig(
 *     inputPath = "/storage/logs",
 *     outputPath = "/storage/logs_backup.zip",
 *     compressionLevel = "high",
 *     excludePatterns = listOf("*.tmp", ".DS_Store")
 * ))
 *
 * scheduler.enqueue(
 *     id = "compress-logs",
 *     trigger = TaskTrigger.OneTime(),
 *     workerClassName = "FileCompressionWorker",
 *     inputJson = config
 * )
 * ```
 */
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)doWorkInput:(NSString * _Nullable)input completionHandler:(void (^)(KMPWMWorkerResult * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("doWork(input:completionHandler:)")));
@end


/**
 * Built-in worker for downloading files from HTTP/HTTPS URLs.
 *
 * Features:
 * - Streaming downloads (constant ~3-5MB RAM regardless of file size)
 * - Atomic file operations (writes to .tmp then renames)
 * - Auto-creates parent directories
 * - Progress tracking support
 * - Handles large files (GB+) efficiently
 *
 * **Memory Usage:** ~3-5MB RAM
 * **Default Timeout:** 300 seconds (5 minutes)
 *
 * **Configuration Example:**
 * ```json
 * {
 *   "url": "https://example.com/large-file.zip",
 *   "savePath": "/path/to/save/file.zip",
 *   "headers": {
 *     "Authorization": "Bearer token"
 *   },
 *   "timeoutMs": 300000
 * }
 * ```
 *
 * **Usage:**
 * ```kotlin
 * val config = Json.encodeToString(HttpDownloadConfig.serializer(), HttpDownloadConfig(
 *     url = "https://example.com/file.zip",
 *     savePath = "/path/to/file.zip"
 * ))
 *
 * scheduler.enqueue(
 *     id = "download-file",
 *     trigger = TaskTrigger.OneTime(),
 *     workerClassName = "HttpDownloadWorker",
 *     inputJson = config
 * )
 * ```
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HttpDownloadWorker")))
@interface KMPWMHttpDownloadWorker : KMPWMBase <KMPWMWorker>
- (instancetype)initWithHttpClient:(KMPWMKtor_client_coreHttpClient * _Nullable)httpClient fileSystem:(KMPWMOkioFileSystem *)fileSystem progressListener:(id<KMPWMProgressListener> _Nullable)progressListener __attribute__((swift_name("init(httpClient:fileSystem:progressListener:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMHttpDownloadWorkerCompanion *companion __attribute__((swift_name("companion")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)doWorkInput:(NSString * _Nullable)input completionHandler:(void (^)(KMPWMWorkerResult * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("doWork(input:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HttpDownloadWorker.Companion")))
@interface KMPWMHttpDownloadWorkerCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMHttpDownloadWorkerCompanion *shared __attribute__((swift_name("shared")));

/**
 * Creates a default HTTP client with reasonable timeouts.
 */
- (KMPWMKtor_client_coreHttpClient *)createDefaultHttpClient __attribute__((swift_name("createDefaultHttpClient()")));
@end


/**
 * Built-in worker for executing HTTP requests (GET, POST, PUT, DELETE, PATCH).
 *
 * This is a fire-and-forget worker that executes HTTP requests without returning
 * the response body. It's ideal for:
 * - Analytics events
 * - Health check pings
 * - Webhook notifications
 * - Simple API calls
 *
 * **Memory Usage:** ~2-3MB RAM
 * **Startup Time:** <50ms
 *
 * **Configuration Example:**
 * ```json
 * {
 *   "url": "https://api.example.com/endpoint",
 *   "method": "POST",
 *   "headers": {
 *     "Authorization": "Bearer token",
 *     "Content-Type": "application/json"
 *   },
 *   "body": "{\"key\":\"value\"}",
 *   "timeoutMs": 30000
 * }
 * ```
 *
 * **Usage:**
 * ```kotlin
 * val config = Json.encodeToString(HttpRequestConfig.serializer(), HttpRequestConfig(
 *     url = "https://api.example.com/ping",
 *     method = "POST",
 *     headers = mapOf("Authorization" to "Bearer token"),
 *     body = "{\"status\":\"active\"}"
 * ))
 *
 * scheduler.enqueue(
 *     id = "ping-api",
 *     trigger = TaskTrigger.OneTime(),
 *     workerClassName = "HttpRequestWorker",
 *     inputJson = config
 * )
 * ```
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HttpRequestWorker")))
@interface KMPWMHttpRequestWorker : KMPWMBase <KMPWMWorker>
- (instancetype)initWithHttpClient:(KMPWMKtor_client_coreHttpClient * _Nullable)httpClient __attribute__((swift_name("init(httpClient:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMHttpRequestWorkerCompanion *companion __attribute__((swift_name("companion")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)doWorkInput:(NSString * _Nullable)input completionHandler:(void (^)(KMPWMWorkerResult * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("doWork(input:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HttpRequestWorker.Companion")))
@interface KMPWMHttpRequestWorkerCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMHttpRequestWorkerCompanion *shared __attribute__((swift_name("shared")));

/**
 * Creates a default HTTP client with reasonable timeouts.
 */
- (KMPWMKtor_client_coreHttpClient *)createDefaultHttpClient __attribute__((swift_name("createDefaultHttpClient()")));
@end


/**
 * Built-in worker for JSON synchronization (POST/GET JSON data).
 *
 * Optimized for JSON request/response scenarios. Automatically sets Content-Type to
 * application/json and handles JSON encoding/decoding.
 *
 * Ideal for:
 * - Data synchronization with server
 * - Batch analytics uploads
 * - Periodic data sync
 * - API sync endpoints
 *
 * **Memory Usage:** ~3-5MB RAM
 * **Startup Time:** <50ms
 * **Default Timeout:** 60 seconds
 *
 * **Configuration Example:**
 * ```json
 * {
 *   "url": "https://api.example.com/sync",
 *   "method": "POST",
 *   "headers": {
 *     "Authorization": "Bearer token"
 *   },
 *   "requestBody": {
 *     "lastSyncTime": 1234567890,
 *     "data": [...]
 *   },
 *   "timeoutMs": 60000
 * }
 * ```
 *
 * **Usage:**
 * ```kotlin
 * val config = Json.encodeToString(HttpSyncConfig.serializer(), HttpSyncConfig(
 *     url = "https://api.example.com/sync",
 *     method = "POST",
 *     headers = mapOf("Authorization" to "Bearer token"),
 *     requestBody = buildJsonObject {
 *         put("lastSync", System.currentTimeMillis())
 *         put("deviceId", "device123")
 *     }
 * ))
 *
 * scheduler.enqueue(
 *     id = "data-sync",
 *     trigger = TaskTrigger.Periodic(intervalMs = 3600000), // Every hour
 *     workerClassName = "HttpSyncWorker",
 *     inputJson = config
 * )
 * ```
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HttpSyncWorker")))
@interface KMPWMHttpSyncWorker : KMPWMBase <KMPWMWorker>
- (instancetype)initWithHttpClient:(KMPWMKtor_client_coreHttpClient * _Nullable)httpClient __attribute__((swift_name("init(httpClient:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMHttpSyncWorkerCompanion *companion __attribute__((swift_name("companion")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)doWorkInput:(NSString * _Nullable)input completionHandler:(void (^)(KMPWMWorkerResult * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("doWork(input:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HttpSyncWorker.Companion")))
@interface KMPWMHttpSyncWorkerCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMHttpSyncWorkerCompanion *shared __attribute__((swift_name("shared")));

/**
 * Creates a default HTTP client with reasonable timeouts.
 */
- (KMPWMKtor_client_coreHttpClient *)createDefaultHttpClient __attribute__((swift_name("createDefaultHttpClient()")));
@end


/**
 * Built-in worker for uploading files using multipart/form-data.
 *
 * Features:
 * - Multipart/form-data encoding
 * - Custom MIME type support
 * - Additional form fields
 * - Progress tracking support
 * - Memory efficient streaming
 *
 * **Memory Usage:** ~5-7MB RAM
 * **Default Timeout:** 120 seconds (2 minutes)
 *
 * **Configuration Example:**
 * ```json
 * {
 *   "url": "https://api.example.com/upload",
 *   "filePath": "/path/to/file.jpg",
 *   "fileFieldName": "photo",
 *   "fileName": "profile.jpg",
 *   "mimeType": "image/jpeg",
 *   "headers": {
 *     "Authorization": "Bearer token"
 *   },
 *   "fields": {
 *     "userId": "123",
 *     "description": "Profile photo"
 *   },
 *   "timeoutMs": 120000
 * }
 * ```
 *
 * **Usage:**
 * ```kotlin
 * val config = Json.encodeToString(HttpUploadConfig.serializer(), HttpUploadConfig(
 *     url = "https://api.example.com/upload",
 *     filePath = "/storage/photo.jpg",
 *     fileFieldName = "photo",
 *     fields = mapOf("userId" to "123")
 * ))
 *
 * scheduler.enqueue(
 *     id = "upload-photo",
 *     trigger = TaskTrigger.OneTime(),
 *     workerClassName = "HttpUploadWorker",
 *     inputJson = config
 * )
 * ```
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HttpUploadWorker")))
@interface KMPWMHttpUploadWorker : KMPWMBase <KMPWMWorker>
- (instancetype)initWithHttpClient:(KMPWMKtor_client_coreHttpClient * _Nullable)httpClient fileSystem:(KMPWMOkioFileSystem *)fileSystem progressListener:(id<KMPWMProgressListener> _Nullable)progressListener __attribute__((swift_name("init(httpClient:fileSystem:progressListener:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMHttpUploadWorkerCompanion *companion __attribute__((swift_name("companion")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)doWorkInput:(NSString * _Nullable)input completionHandler:(void (^)(KMPWMWorkerResult * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("doWork(input:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HttpUploadWorker.Companion")))
@interface KMPWMHttpUploadWorkerCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMHttpUploadWorkerCompanion *shared __attribute__((swift_name("shared")));

/**
 * Creates a default HTTP client with reasonable timeouts.
 */
- (KMPWMKtor_client_coreHttpClient *)createDefaultHttpClient __attribute__((swift_name("createDefaultHttpClient()")));
@end


/**
 * Compression level for ZIP archives.
 *
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("CompressionLevel")))
@interface KMPWMCompressionLevel : KMPWMKotlinEnum<KMPWMCompressionLevel *>
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Compression level for ZIP archives.
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) KMPWMCompressionLevelCompanion *companion __attribute__((swift_name("companion")));
@property (class, readonly) KMPWMCompressionLevel *low __attribute__((swift_name("low")));
@property (class, readonly) KMPWMCompressionLevel *medium __attribute__((swift_name("medium")));
@property (class, readonly) KMPWMCompressionLevel *high __attribute__((swift_name("high")));
+ (KMPWMKotlinArray<KMPWMCompressionLevel *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<KMPWMCompressionLevel *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("CompressionLevel.Companion")))
@interface KMPWMCompressionLevelCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMCompressionLevelCompanion *shared __attribute__((swift_name("shared")));
- (KMPWMCompressionLevel *)fromStringLevel:(NSString *)level __attribute__((swift_name("fromString(level:)")));
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializerTypeParamsSerializers:(KMPWMKotlinArray<id<KMPWMKotlinx_serialization_coreKSerializer>> *)typeParamsSerializers __attribute__((swift_name("serializer(typeParamsSerializers:)")));
@end


/**
 * Configuration for FileCompressionWorker.
 *
 * @property inputPath Absolute path to file or directory to compress
 * @property outputPath Absolute path for the output ZIP file
 * @property compressionLevel Compression level (low, medium, high) - default: medium
 * @property excludePatterns List of patterns to exclude (e.g., "*.tmp", ".DS_Store")
 * @property deleteOriginal Whether to delete original files after compression - default: false
 *
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("FileCompressionConfig")))
@interface KMPWMFileCompressionConfig : KMPWMBase
- (instancetype)initWithInputPath:(NSString *)inputPath outputPath:(NSString *)outputPath compressionLevel:(NSString *)compressionLevel excludePatterns:(NSArray<NSString *> * _Nullable)excludePatterns deleteOriginal:(BOOL)deleteOriginal __attribute__((swift_name("init(inputPath:outputPath:compressionLevel:excludePatterns:deleteOriginal:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMFileCompressionConfigCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMFileCompressionConfig *)doCopyInputPath:(NSString *)inputPath outputPath:(NSString *)outputPath compressionLevel:(NSString *)compressionLevel excludePatterns:(NSArray<NSString *> * _Nullable)excludePatterns deleteOriginal:(BOOL)deleteOriginal __attribute__((swift_name("doCopy(inputPath:outputPath:compressionLevel:excludePatterns:deleteOriginal:)")));

/**
 * Configuration for FileCompressionWorker.
 *
 * @property inputPath Absolute path to file or directory to compress
 * @property outputPath Absolute path for the output ZIP file
 * @property compressionLevel Compression level (low, medium, high) - default: medium
 * @property excludePatterns List of patterns to exclude (e.g., "*.tmp", ".DS_Store")
 * @property deleteOriginal Whether to delete original files after compression - default: false
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Configuration for FileCompressionWorker.
 *
 * @property inputPath Absolute path to file or directory to compress
 * @property outputPath Absolute path for the output ZIP file
 * @property compressionLevel Compression level (low, medium, high) - default: medium
 * @property excludePatterns List of patterns to exclude (e.g., "*.tmp", ".DS_Store")
 * @property deleteOriginal Whether to delete original files after compression - default: false
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Configuration for FileCompressionWorker.
 *
 * @property inputPath Absolute path to file or directory to compress
 * @property outputPath Absolute path for the output ZIP file
 * @property compressionLevel Compression level (low, medium, high) - default: medium
 * @property excludePatterns List of patterns to exclude (e.g., "*.tmp", ".DS_Store")
 * @property deleteOriginal Whether to delete original files after compression - default: false
 */
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *compressionLevel __attribute__((swift_name("compressionLevel")));
@property (readonly) BOOL deleteOriginal __attribute__((swift_name("deleteOriginal")));
@property (readonly) NSArray<NSString *> * _Nullable excludePatterns __attribute__((swift_name("excludePatterns")));
@property (readonly) NSString *inputPath __attribute__((swift_name("inputPath")));
@property (readonly) KMPWMCompressionLevel *level __attribute__((swift_name("level")));
@property (readonly) NSString *outputPath __attribute__((swift_name("outputPath")));
@end


/**
 * Configuration for FileCompressionWorker.
 *
 * @property inputPath Absolute path to file or directory to compress
 * @property outputPath Absolute path for the output ZIP file
 * @property compressionLevel Compression level (low, medium, high) - default: medium
 * @property excludePatterns List of patterns to exclude (e.g., "*.tmp", ".DS_Store")
 * @property deleteOriginal Whether to delete original files after compression - default: false
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("FileCompressionConfig.Companion")))
@interface KMPWMFileCompressionConfigCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Configuration for FileCompressionWorker.
 *
 * @property inputPath Absolute path to file or directory to compress
 * @property outputPath Absolute path for the output ZIP file
 * @property compressionLevel Compression level (low, medium, high) - default: medium
 * @property excludePatterns List of patterns to exclude (e.g., "*.tmp", ".DS_Store")
 * @property deleteOriginal Whether to delete original files after compression - default: false
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMFileCompressionConfigCompanion *shared __attribute__((swift_name("shared")));

/**
 * Configuration for FileCompressionWorker.
 *
 * @property inputPath Absolute path to file or directory to compress
 * @property outputPath Absolute path for the output ZIP file
 * @property compressionLevel Compression level (low, medium, high) - default: medium
 * @property excludePatterns List of patterns to exclude (e.g., "*.tmp", ".DS_Store")
 * @property deleteOriginal Whether to delete original files after compression - default: false
 */
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * Configuration for HttpDownloadWorker.
 *
 * @property url The HTTP/HTTPS URL to download from
 * @property savePath Absolute path where to save the downloaded file
 * @property headers Optional HTTP headers
 * @property timeoutMs Download timeout in milliseconds (default: 300000ms = 5 minutes)
 *
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HttpDownloadConfig")))
@interface KMPWMHttpDownloadConfig : KMPWMBase
- (instancetype)initWithUrl:(NSString *)url savePath:(NSString *)savePath headers:(NSDictionary<NSString *, NSString *> * _Nullable)headers timeoutMs:(int64_t)timeoutMs __attribute__((swift_name("init(url:savePath:headers:timeoutMs:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMHttpDownloadConfigCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMHttpDownloadConfig *)doCopyUrl:(NSString *)url savePath:(NSString *)savePath headers:(NSDictionary<NSString *, NSString *> * _Nullable)headers timeoutMs:(int64_t)timeoutMs __attribute__((swift_name("doCopy(url:savePath:headers:timeoutMs:)")));

/**
 * Configuration for HttpDownloadWorker.
 *
 * @property url The HTTP/HTTPS URL to download from
 * @property savePath Absolute path where to save the downloaded file
 * @property headers Optional HTTP headers
 * @property timeoutMs Download timeout in milliseconds (default: 300000ms = 5 minutes)
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Configuration for HttpDownloadWorker.
 *
 * @property url The HTTP/HTTPS URL to download from
 * @property savePath Absolute path where to save the downloaded file
 * @property headers Optional HTTP headers
 * @property timeoutMs Download timeout in milliseconds (default: 300000ms = 5 minutes)
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Configuration for HttpDownloadWorker.
 *
 * @property url The HTTP/HTTPS URL to download from
 * @property savePath Absolute path where to save the downloaded file
 * @property headers Optional HTTP headers
 * @property timeoutMs Download timeout in milliseconds (default: 300000ms = 5 minutes)
 */
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSDictionary<NSString *, NSString *> * _Nullable headers __attribute__((swift_name("headers")));
@property (readonly) NSString *savePath __attribute__((swift_name("savePath")));
@property (readonly) int64_t timeoutMs __attribute__((swift_name("timeoutMs")));
@property (readonly) NSString *url __attribute__((swift_name("url")));
@end


/**
 * Configuration for HttpDownloadWorker.
 *
 * @property url The HTTP/HTTPS URL to download from
 * @property savePath Absolute path where to save the downloaded file
 * @property headers Optional HTTP headers
 * @property timeoutMs Download timeout in milliseconds (default: 300000ms = 5 minutes)
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HttpDownloadConfig.Companion")))
@interface KMPWMHttpDownloadConfigCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Configuration for HttpDownloadWorker.
 *
 * @property url The HTTP/HTTPS URL to download from
 * @property savePath Absolute path where to save the downloaded file
 * @property headers Optional HTTP headers
 * @property timeoutMs Download timeout in milliseconds (default: 300000ms = 5 minutes)
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMHttpDownloadConfigCompanion *shared __attribute__((swift_name("shared")));

/**
 * Configuration for HttpDownloadWorker.
 *
 * @property url The HTTP/HTTPS URL to download from
 * @property savePath Absolute path where to save the downloaded file
 * @property headers Optional HTTP headers
 * @property timeoutMs Download timeout in milliseconds (default: 300000ms = 5 minutes)
 */
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * Supported HTTP methods for built-in HTTP workers.
 *
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HttpMethod")))
@interface KMPWMHttpMethod : KMPWMKotlinEnum<KMPWMHttpMethod *>
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Supported HTTP methods for built-in HTTP workers.
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) KMPWMHttpMethodCompanion *companion __attribute__((swift_name("companion")));
@property (class, readonly) KMPWMHttpMethod *get __attribute__((swift_name("get")));
@property (class, readonly) KMPWMHttpMethod *post __attribute__((swift_name("post")));
@property (class, readonly) KMPWMHttpMethod *put __attribute__((swift_name("put")));
@property (class, readonly) KMPWMHttpMethod *delete_ __attribute__((swift_name("delete_")));
@property (class, readonly) KMPWMHttpMethod *patch __attribute__((swift_name("patch")));
+ (KMPWMKotlinArray<KMPWMHttpMethod *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<KMPWMHttpMethod *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HttpMethod.Companion")))
@interface KMPWMHttpMethodCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMHttpMethodCompanion *shared __attribute__((swift_name("shared")));
- (KMPWMHttpMethod *)fromStringMethod:(NSString *)method __attribute__((swift_name("fromString(method:)")));
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializerTypeParamsSerializers:(KMPWMKotlinArray<id<KMPWMKotlinx_serialization_coreKSerializer>> *)typeParamsSerializers __attribute__((swift_name("serializer(typeParamsSerializers:)")));
@end


/**
 * Configuration for HttpRequestWorker.
 *
 * @property url The HTTP/HTTPS URL to request
 * @property method HTTP method (GET, POST, PUT, DELETE, PATCH)
 * @property headers Optional HTTP headers
 * @property body Optional request body (for POST, PUT, PATCH)
 * @property timeoutMs Request timeout in milliseconds (default: 30000ms = 30s)
 *
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HttpRequestConfig")))
@interface KMPWMHttpRequestConfig : KMPWMBase
- (instancetype)initWithUrl:(NSString *)url method:(NSString *)method headers:(NSDictionary<NSString *, NSString *> * _Nullable)headers body:(NSString * _Nullable)body timeoutMs:(int64_t)timeoutMs __attribute__((swift_name("init(url:method:headers:body:timeoutMs:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMHttpRequestConfigCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMHttpRequestConfig *)doCopyUrl:(NSString *)url method:(NSString *)method headers:(NSDictionary<NSString *, NSString *> * _Nullable)headers body:(NSString * _Nullable)body timeoutMs:(int64_t)timeoutMs __attribute__((swift_name("doCopy(url:method:headers:body:timeoutMs:)")));

/**
 * Configuration for HttpRequestWorker.
 *
 * @property url The HTTP/HTTPS URL to request
 * @property method HTTP method (GET, POST, PUT, DELETE, PATCH)
 * @property headers Optional HTTP headers
 * @property body Optional request body (for POST, PUT, PATCH)
 * @property timeoutMs Request timeout in milliseconds (default: 30000ms = 30s)
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Configuration for HttpRequestWorker.
 *
 * @property url The HTTP/HTTPS URL to request
 * @property method HTTP method (GET, POST, PUT, DELETE, PATCH)
 * @property headers Optional HTTP headers
 * @property body Optional request body (for POST, PUT, PATCH)
 * @property timeoutMs Request timeout in milliseconds (default: 30000ms = 30s)
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Configuration for HttpRequestWorker.
 *
 * @property url The HTTP/HTTPS URL to request
 * @property method HTTP method (GET, POST, PUT, DELETE, PATCH)
 * @property headers Optional HTTP headers
 * @property body Optional request body (for POST, PUT, PATCH)
 * @property timeoutMs Request timeout in milliseconds (default: 30000ms = 30s)
 */
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString * _Nullable body __attribute__((swift_name("body")));
@property (readonly) NSDictionary<NSString *, NSString *> * _Nullable headers __attribute__((swift_name("headers")));
@property (readonly) KMPWMHttpMethod *httpMethod __attribute__((swift_name("httpMethod")));
@property (readonly) NSString *method __attribute__((swift_name("method")));
@property (readonly) int64_t timeoutMs __attribute__((swift_name("timeoutMs")));
@property (readonly) NSString *url __attribute__((swift_name("url")));
@end


/**
 * Configuration for HttpRequestWorker.
 *
 * @property url The HTTP/HTTPS URL to request
 * @property method HTTP method (GET, POST, PUT, DELETE, PATCH)
 * @property headers Optional HTTP headers
 * @property body Optional request body (for POST, PUT, PATCH)
 * @property timeoutMs Request timeout in milliseconds (default: 30000ms = 30s)
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HttpRequestConfig.Companion")))
@interface KMPWMHttpRequestConfigCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Configuration for HttpRequestWorker.
 *
 * @property url The HTTP/HTTPS URL to request
 * @property method HTTP method (GET, POST, PUT, DELETE, PATCH)
 * @property headers Optional HTTP headers
 * @property body Optional request body (for POST, PUT, PATCH)
 * @property timeoutMs Request timeout in milliseconds (default: 30000ms = 30s)
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMHttpRequestConfigCompanion *shared __attribute__((swift_name("shared")));

/**
 * Configuration for HttpRequestWorker.
 *
 * @property url The HTTP/HTTPS URL to request
 * @property method HTTP method (GET, POST, PUT, DELETE, PATCH)
 * @property headers Optional HTTP headers
 * @property body Optional request body (for POST, PUT, PATCH)
 * @property timeoutMs Request timeout in milliseconds (default: 30000ms = 30s)
 */
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * Configuration for HttpSyncWorker.
 *
 * @property url The HTTP/HTTPS URL for synchronization endpoint
 * @property method HTTP method (GET, POST, PUT, PATCH) - default: POST
 * @property headers Optional HTTP headers
 * @property requestBody Optional JSON request body (will be serialized automatically)
 * @property timeoutMs Request timeout in milliseconds (default: 60000ms = 1 minute)
 *
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HttpSyncConfig")))
@interface KMPWMHttpSyncConfig : KMPWMBase
- (instancetype)initWithUrl:(NSString *)url method:(NSString *)method headers:(NSDictionary<NSString *, NSString *> * _Nullable)headers requestBody:(KMPWMKotlinx_serialization_jsonJsonElement * _Nullable)requestBody timeoutMs:(int64_t)timeoutMs __attribute__((swift_name("init(url:method:headers:requestBody:timeoutMs:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMHttpSyncConfigCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMHttpSyncConfig *)doCopyUrl:(NSString *)url method:(NSString *)method headers:(NSDictionary<NSString *, NSString *> * _Nullable)headers requestBody:(KMPWMKotlinx_serialization_jsonJsonElement * _Nullable)requestBody timeoutMs:(int64_t)timeoutMs __attribute__((swift_name("doCopy(url:method:headers:requestBody:timeoutMs:)")));

/**
 * Configuration for HttpSyncWorker.
 *
 * @property url The HTTP/HTTPS URL for synchronization endpoint
 * @property method HTTP method (GET, POST, PUT, PATCH) - default: POST
 * @property headers Optional HTTP headers
 * @property requestBody Optional JSON request body (will be serialized automatically)
 * @property timeoutMs Request timeout in milliseconds (default: 60000ms = 1 minute)
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Configuration for HttpSyncWorker.
 *
 * @property url The HTTP/HTTPS URL for synchronization endpoint
 * @property method HTTP method (GET, POST, PUT, PATCH) - default: POST
 * @property headers Optional HTTP headers
 * @property requestBody Optional JSON request body (will be serialized automatically)
 * @property timeoutMs Request timeout in milliseconds (default: 60000ms = 1 minute)
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Configuration for HttpSyncWorker.
 *
 * @property url The HTTP/HTTPS URL for synchronization endpoint
 * @property method HTTP method (GET, POST, PUT, PATCH) - default: POST
 * @property headers Optional HTTP headers
 * @property requestBody Optional JSON request body (will be serialized automatically)
 * @property timeoutMs Request timeout in milliseconds (default: 60000ms = 1 minute)
 */
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSDictionary<NSString *, NSString *> * _Nullable headers __attribute__((swift_name("headers")));
@property (readonly) KMPWMHttpMethod *httpMethod __attribute__((swift_name("httpMethod")));
@property (readonly) NSString *method __attribute__((swift_name("method")));
@property (readonly) KMPWMKotlinx_serialization_jsonJsonElement * _Nullable requestBody __attribute__((swift_name("requestBody")));
@property (readonly) int64_t timeoutMs __attribute__((swift_name("timeoutMs")));
@property (readonly) NSString *url __attribute__((swift_name("url")));
@end


/**
 * Configuration for HttpSyncWorker.
 *
 * @property url The HTTP/HTTPS URL for synchronization endpoint
 * @property method HTTP method (GET, POST, PUT, PATCH) - default: POST
 * @property headers Optional HTTP headers
 * @property requestBody Optional JSON request body (will be serialized automatically)
 * @property timeoutMs Request timeout in milliseconds (default: 60000ms = 1 minute)
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HttpSyncConfig.Companion")))
@interface KMPWMHttpSyncConfigCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Configuration for HttpSyncWorker.
 *
 * @property url The HTTP/HTTPS URL for synchronization endpoint
 * @property method HTTP method (GET, POST, PUT, PATCH) - default: POST
 * @property headers Optional HTTP headers
 * @property requestBody Optional JSON request body (will be serialized automatically)
 * @property timeoutMs Request timeout in milliseconds (default: 60000ms = 1 minute)
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMHttpSyncConfigCompanion *shared __attribute__((swift_name("shared")));

/**
 * Configuration for HttpSyncWorker.
 *
 * @property url The HTTP/HTTPS URL for synchronization endpoint
 * @property method HTTP method (GET, POST, PUT, PATCH) - default: POST
 * @property headers Optional HTTP headers
 * @property requestBody Optional JSON request body (will be serialized automatically)
 * @property timeoutMs Request timeout in milliseconds (default: 60000ms = 1 minute)
 */
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * Configuration for HttpUploadWorker.
 *
 * @property url The HTTP/HTTPS URL to upload to
 * @property filePath Absolute path to the file to upload
 * @property fileFieldName Form field name for the file (default: "file")
 * @property fileName Override the uploaded filename (optional)
 * @property mimeType Override MIME type (optional, auto-detected if not provided)
 * @property headers Optional HTTP headers
 * @property fields Additional form fields to include
 * @property timeoutMs Upload timeout in milliseconds (default: 120000ms = 2 minutes)
 *
 * @note annotations
 *   kotlinx.serialization.Serializable
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HttpUploadConfig")))
@interface KMPWMHttpUploadConfig : KMPWMBase
- (instancetype)initWithUrl:(NSString *)url filePath:(NSString *)filePath fileFieldName:(NSString *)fileFieldName fileName:(NSString * _Nullable)fileName mimeType:(NSString * _Nullable)mimeType headers:(NSDictionary<NSString *, NSString *> * _Nullable)headers fields:(NSDictionary<NSString *, NSString *> * _Nullable)fields timeoutMs:(int64_t)timeoutMs __attribute__((swift_name("init(url:filePath:fileFieldName:fileName:mimeType:headers:fields:timeoutMs:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMHttpUploadConfigCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMHttpUploadConfig *)doCopyUrl:(NSString *)url filePath:(NSString *)filePath fileFieldName:(NSString *)fileFieldName fileName:(NSString * _Nullable)fileName mimeType:(NSString * _Nullable)mimeType headers:(NSDictionary<NSString *, NSString *> * _Nullable)headers fields:(NSDictionary<NSString *, NSString *> * _Nullable)fields timeoutMs:(int64_t)timeoutMs __attribute__((swift_name("doCopy(url:filePath:fileFieldName:fileName:mimeType:headers:fields:timeoutMs:)")));

/**
 * Configuration for HttpUploadWorker.
 *
 * @property url The HTTP/HTTPS URL to upload to
 * @property filePath Absolute path to the file to upload
 * @property fileFieldName Form field name for the file (default: "file")
 * @property fileName Override the uploaded filename (optional)
 * @property mimeType Override MIME type (optional, auto-detected if not provided)
 * @property headers Optional HTTP headers
 * @property fields Additional form fields to include
 * @property timeoutMs Upload timeout in milliseconds (default: 120000ms = 2 minutes)
 */
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));

/**
 * Configuration for HttpUploadWorker.
 *
 * @property url The HTTP/HTTPS URL to upload to
 * @property filePath Absolute path to the file to upload
 * @property fileFieldName Form field name for the file (default: "file")
 * @property fileName Override the uploaded filename (optional)
 * @property mimeType Override MIME type (optional, auto-detected if not provided)
 * @property headers Optional HTTP headers
 * @property fields Additional form fields to include
 * @property timeoutMs Upload timeout in milliseconds (default: 120000ms = 2 minutes)
 */
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/**
 * Configuration for HttpUploadWorker.
 *
 * @property url The HTTP/HTTPS URL to upload to
 * @property filePath Absolute path to the file to upload
 * @property fileFieldName Form field name for the file (default: "file")
 * @property fileName Override the uploaded filename (optional)
 * @property mimeType Override MIME type (optional, auto-detected if not provided)
 * @property headers Optional HTTP headers
 * @property fields Additional form fields to include
 * @property timeoutMs Upload timeout in milliseconds (default: 120000ms = 2 minutes)
 */
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSDictionary<NSString *, NSString *> * _Nullable fields __attribute__((swift_name("fields")));
@property (readonly) NSString *fileFieldName __attribute__((swift_name("fileFieldName")));
@property (readonly) NSString * _Nullable fileName __attribute__((swift_name("fileName")));
@property (readonly) NSString *filePath __attribute__((swift_name("filePath")));
@property (readonly) NSDictionary<NSString *, NSString *> * _Nullable headers __attribute__((swift_name("headers")));
@property (readonly) NSString * _Nullable mimeType __attribute__((swift_name("mimeType")));
@property (readonly) int64_t timeoutMs __attribute__((swift_name("timeoutMs")));
@property (readonly) NSString *url __attribute__((swift_name("url")));
@end


/**
 * Configuration for HttpUploadWorker.
 *
 * @property url The HTTP/HTTPS URL to upload to
 * @property filePath Absolute path to the file to upload
 * @property fileFieldName Form field name for the file (default: "file")
 * @property fileName Override the uploaded filename (optional)
 * @property mimeType Override MIME type (optional, auto-detected if not provided)
 * @property headers Optional HTTP headers
 * @property fields Additional form fields to include
 * @property timeoutMs Upload timeout in milliseconds (default: 120000ms = 2 minutes)
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("HttpUploadConfig.Companion")))
@interface KMPWMHttpUploadConfigCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Configuration for HttpUploadWorker.
 *
 * @property url The HTTP/HTTPS URL to upload to
 * @property filePath Absolute path to the file to upload
 * @property fileFieldName Form field name for the file (default: "file")
 * @property fileName Override the uploaded filename (optional)
 * @property mimeType Override MIME type (optional, auto-detected if not provided)
 * @property headers Optional HTTP headers
 * @property fields Additional form fields to include
 * @property timeoutMs Upload timeout in milliseconds (default: 120000ms = 2 minutes)
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMHttpUploadConfigCompanion *shared __attribute__((swift_name("shared")));

/**
 * Configuration for HttpUploadWorker.
 *
 * @property url The HTTP/HTTPS URL to upload to
 * @property filePath Absolute path to the file to upload
 * @property fileFieldName Form field name for the file (default: "file")
 * @property fileName Override the uploaded filename (optional)
 * @property mimeType Override MIME type (optional, auto-detected if not provided)
 * @property headers Optional HTTP headers
 * @property fields Additional form fields to include
 * @property timeoutMs Upload timeout in milliseconds (default: 120000ms = 2 minutes)
 */
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
@end


/**
 * Security validation utilities for built-in workers.
 *
 * Provides centralized validation for:
 * - URL schemes (http/https only)
 * - File path validation
 * - Request/response size limits
 * - Safe logging (truncation, redaction)
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("SecurityValidator")))
@interface KMPWMSecurityValidator : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Security validation utilities for built-in workers.
 *
 * Provides centralized validation for:
 * - URL schemes (http/https only)
 * - File path validation
 * - Request/response size limits
 * - Safe logging (truncation, redaction)
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)securityValidator __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMSecurityValidator *shared __attribute__((swift_name("shared")));

/**
 * Formats byte size for human-readable output.
 *
 * @param bytes The size in bytes
 * @return Formatted string (e.g., "1.5 MB", "512 KB")
 */
- (NSString *)formatByteSizeBytes:(int64_t)bytes __attribute__((swift_name("formatByteSize(bytes:)")));

/**
 * Redacts query parameters from URL for safe logging.
 * Example: "https://api.com/data?key=secret" -> "https://api.com/data?[REDACTED]"
 *
 * @param url The URL to sanitize
 * @return Sanitized URL safe for logging
 */
- (NSString *)sanitizedURLUrl:(NSString *)url __attribute__((swift_name("sanitizedURL(url:)")));

/**
 * Truncates a string for safe logging.
 *
 * @param string The string to truncate
 * @param maxLength Maximum length (default: 200 characters)
 * @return Truncated string
 */
- (NSString *)truncateForLoggingString:(NSString *)string maxLength:(int32_t)maxLength __attribute__((swift_name("truncateForLogging(string:maxLength:)")));

/**
 * Validates that a file path doesn't contain path traversal attempts.
 *
 * @param path The file path to validate
 * @return true if path is safe, false if it contains ".." or other suspicious patterns
 */
- (BOOL)validateFilePathPath:(NSString *)path __attribute__((swift_name("validateFilePath(path:)")));

/**
 * Validates request body size doesn't exceed the limit.
 *
 * @param data The data to validate
 * @return true if size is acceptable
 */
- (BOOL)validateRequestSizeData:(KMPWMKotlinByteArray *)data __attribute__((swift_name("validateRequestSize(data:)")));

/**
 * Validates response body size doesn't exceed the limit.
 *
 * @param data The data to validate
 * @return true if size is acceptable
 */
- (BOOL)validateResponseSizeData:(KMPWMKotlinByteArray *)data __attribute__((swift_name("validateResponseSize(data:)")));

/**
 * Validates that a URL uses http:// or https:// scheme.
 *
 * @param url The URL string to validate
 * @return true if URL is valid, false otherwise
 */
- (BOOL)validateURLUrl:(NSString *)url __attribute__((swift_name("validateURL(url:)")));
@property (readonly) int32_t MAX_REQUEST_BODY_SIZE __attribute__((swift_name("MAX_REQUEST_BODY_SIZE")));
@property (readonly) int32_t MAX_RESPONSE_BODY_SIZE __attribute__((swift_name("MAX_RESPONSE_BODY_SIZE")));
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

/**
 * Extension function: Calculate CRC32 for ByteArray
 */
- (uint32_t)crc32 __attribute__((swift_name("crc32()")));

/**
 * Extension function: Verify CRC32 for ByteArray
 */
- (BOOL)verifyCrc32ExpectedCrc:(uint32_t)expectedCrc __attribute__((swift_name("verifyCrc32(expectedCrc:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("BackgroundTaskSchedulerExtKt")))
@interface KMPWMBackgroundTaskSchedulerExtKt : KMPWMBase

/**
 * Begin a task chain with type-safe input serialization (parallel tasks).
 *
 * This extension automatically serializes input objects to JSON for multiple tasks.
 *
 * @param tasks List of task specifications with typed input data
 * @return TaskChain for further chaining with then()
 *
 * Example:
 * ```kotlin
 * @Serializable
 * data class FetchRequest(val endpoint: String)
 *
 * scheduler.beginWith(
 *     TaskSpec("FetchUserWorker", input = FetchRequest("/users")),
 *     TaskSpec("FetchPostsWorker", input = FetchRequest("/posts"))
 * )
 *     .then(TaskRequest("MergeDataWorker"))
 *     .enqueue()
 * ```
 */
+ (KMPWMTaskChain *)beginWith:(id<KMPWMBackgroundTaskScheduler>)receiver tasks:(KMPWMKotlinArray<KMPWMTaskSpec<id> *> *)tasks __attribute__((swift_name("beginWith(_:tasks:)")));

/**
 * Begin a task chain with type-safe input serialization (single task).
 *
 * This extension automatically serializes the input object to JSON.
 *
 * @param T The type of input data (must be annotated with @Serializable)
 * @param workerClassName Fully qualified worker class name
 * @param constraints Execution constraints
 * @param input Optional input data (will be serialized to JSON automatically)
 * @return TaskChain for further chaining with then()
 *
 * Example:
 * ```kotlin
 * @Serializable
 * data class DownloadRequest(val url: String)
 *
 * scheduler.beginWith(
 *     workerClassName = "DownloadWorker",
 *     input = DownloadRequest("https://example.com/file.zip")
 * )
 *     .then(TaskRequest("ExtractWorker"))
 *     .then(TaskRequest("ProcessWorker"))
 *     .enqueue()
 * ```
 */
+ (KMPWMTaskChain *)beginWith:(id<KMPWMBackgroundTaskScheduler>)receiver workerClassName:(NSString *)workerClassName constraints:(KMPWMConstraints *)constraints input:(id _Nullable)input __attribute__((swift_name("beginWith(_:workerClassName:constraints:input:)")));

/**
 * Enqueue a task with type-safe input serialization.
 *
 * This extension automatically serializes the input object to JSON using kotlinx.serialization.
 *
 * @param T The type of input data (must be annotated with @Serializable)
 * @param id Unique task identifier
 * @param trigger When and how the task should be triggered
 * @param workerClassName Fully qualified worker class name
 * @param constraints Execution constraints (network, charging, etc.)
 * @param input Optional input data (will be serialized to JSON automatically)
 * @param policy How to handle duplicate task IDs
 * @return ScheduleResult indicating success or failure
 *
 * Example:
 * ```kotlin
 * @Serializable
 * data class SyncRequest(val userId: String, val fullSync: Boolean)
 *
 * scheduler.enqueue(
 *     id = "user-sync-123",
 *     trigger = TaskTrigger.OneTime(initialDelayMs = 5000),
 *     workerClassName = "SyncWorker",
 *     input = SyncRequest(userId = "123", fullSync = true),
 *     constraints = Constraints(requiresNetwork = true)
 * )
 * ```
 *
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
+ (void)enqueue:(id<KMPWMBackgroundTaskScheduler>)receiver id:(NSString *)id trigger:(id<KMPWMTaskTrigger>)trigger workerClassName:(NSString *)workerClassName constraints:(KMPWMConstraints *)constraints input:(id _Nullable)input policy:(KMPWMExistingPolicy *)policy completionHandler:(void (^)(KMPWMScheduleResult * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("enqueue(_:id:trigger:workerClassName:constraints:input:policy:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("CRC32Kt")))
@interface KMPWMCRC32Kt : KMPWMBase

/**
 * Extension function: Calculate CRC32 for String
 */
+ (uint32_t)crc32:(NSString *)receiver __attribute__((swift_name("crc32(_:)")));

/**
 * Extension function: Verify CRC32 for String
 */
+ (BOOL)verifyCrc32:(NSString *)receiver expectedCrc:(uint32_t)expectedCrc __attribute__((swift_name("verifyCrc32(_:expectedCrc:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("ChainExecutorKt")))
@interface KMPWMChainExecutorKt : KMPWMBase

/**
 * Extension function for using Closeable with automatic cleanup
 */
+ (id _Nullable)use:(id<KMPWMCloseable>)receiver block:(id _Nullable (^)(id<KMPWMCloseable>))block __attribute__((swift_name("use(_:block:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KoinModule_iosKt")))
@interface KMPWMKoinModule_iosKt : KMPWMBase

/**
 * iOS implementation of the Koin module.
 *
 * v4.0.0+ Breaking Change: Now requires WorkerFactory parameter
 * v2.2.2+ New: Optional config parameter for logging configuration
 *
 * Usage:
 * ```kotlin
 * // Basic usage
 * fun initKoinIos() {
 *     startKoin {
 *         modules(kmpWorkerModule(
 *             workerFactory = MyWorkerFactory(),
 *             config = KmpWorkManagerConfig(logLevel = Logger.Level.INFO)
 *         ))
 *     }
 * }
 *
 * // With additional task IDs (optional - reads from Info.plist automatically)
 * fun initKoinIos() {
 *     startKoin {
 *         modules(kmpWorkerModule(
 *             workerFactory = MyWorkerFactory(),
 *             config = KmpWorkManagerConfig(logLevel = Logger.Level.INFO),
 *             iosTaskIds = setOf("my-sync-task", "my-upload-task")
 *         ))
 *     }
 * }
 * ```
 *
 * @param workerFactory User-provided factory implementing IosWorkerFactory
 * @param config Configuration for logging and other settings
 * @param iosTaskIds Additional iOS task IDs (optional, Info.plist is primary source)
 */
+ (KMPWMKoin_coreModule *)kmpWorkerModuleWorkerFactory:(id<KMPWMWorkerFactory>)workerFactory config:(KMPWMKmpWorkManagerConfig *)config iosTaskIds:(NSSet<NSString *> *)iosTaskIds __attribute__((swift_name("kmpWorkerModule(workerFactory:config:iosTaskIds:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KoinModuleKt")))
@interface KMPWMKoinModuleKt : KMPWMBase

/**
 * Common module definition for direct use (advanced usage)
 */
+ (KMPWMKoin_coreModule *)kmpWorkerCoreModuleScheduler:(id<KMPWMBackgroundTaskScheduler>)scheduler workerFactory:(id<KMPWMWorkerFactory>)workerFactory __attribute__((swift_name("kmpWorkerCoreModule(scheduler:workerFactory:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("PlatformFileSystemKt")))
@interface KMPWMPlatformFileSystemKt : KMPWMBase
@property (class, readonly) KMPWMOkioFileSystem *platformFileSystem __attribute__((swift_name("platformFileSystem")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("TaskTriggerHelperKt")))
@interface KMPWMTaskTriggerHelperKt : KMPWMBase

/**
 * Helper function to create a Constraints instance with default values from Swift/Objective-C.
 *
 * @return A Constraints object with all fields set to their default (false/Background).
 */
+ (KMPWMConstraints *)createConstraints __attribute__((swift_name("createConstraints()")));

/**
 * Helper function to create a TaskTrigger.OneTime instance from Swift/Objective-C,
 * as default values in data classes are sometimes complex to access from native code.
 *
 * @param initialDelayMs The delay before the task should run, in milliseconds.
 * @return A TaskTrigger.OneTime object.
 */
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


/**
 * Serialization strategy defines the serial form of a type [T], including its structural description,
 * declared by the [descriptor] and the actual serialization process, defined by the implementation
 * of the [serialize] method.
 *
 * [serialize] method takes an instance of [T] and transforms it into its serial form (a sequence of primitives),
 * calling the corresponding [Encoder] methods.
 *
 * A serial form of the type is a transformation of the concrete instance into a sequence of primitive values
 * and vice versa. The serial form is not required to completely mimic the structure of the class, for example,
 * a specific implementation may represent multiple integer values as a single string, omit or add some
 * values that are present in the type, but not in the instance.
 *
 * For a more detailed explanation of the serialization process, please refer to [KSerializer] documentation.
 */
__attribute__((swift_name("Kotlinx_serialization_coreSerializationStrategy")))
@protocol KMPWMKotlinx_serialization_coreSerializationStrategy
@required

/**
 * Serializes the [value] of type [T] using the format that is represented by the given [encoder].
 * [serialize] method is format-agnostic and operates with a high-level structured [Encoder] API.
 * Throws [SerializationException] if value cannot be serialized.
 *
 * Example of serialize method:
 * ```
 * class MyData(int: Int, stringList: List<String>, alwaysZero: Long)
 *
 * fun serialize(encoder: Encoder, value: MyData): Unit = encoder.encodeStructure(descriptor) {
 *     // encodeStructure encodes beginning and end of the structure
 *     // encode 'int' property as Int
 *     encodeIntElement(descriptor, index = 0, value.int)
 *     // encode 'stringList' property as List<String>
 *     encodeSerializableElement(descriptor, index = 1, serializer<List<String>>, value.stringList)
 *     // don't encode 'alwaysZero' property because we decided to do so
 * } // end of the structure
 * ```
 *
 * @throws SerializationException in case of any serialization-specific error
 * @throws IllegalArgumentException if the supplied input does not comply encoder's specification
 * @see KSerializer for additional information about general contracts and exception specifics
 */
- (void)serializeEncoder:(id<KMPWMKotlinx_serialization_coreEncoder>)encoder value:(id _Nullable)value __attribute__((swift_name("serialize(encoder:value:)")));

/**
 * Describes the structure of the serializable representation of [T], produced
 * by this serializer.
 */
@property (readonly) id<KMPWMKotlinx_serialization_coreSerialDescriptor> descriptor __attribute__((swift_name("descriptor")));
@end


/**
 * Deserialization strategy defines the serial form of a type [T], including its structural description,
 * declared by the [descriptor] and the actual deserialization process, defined by the implementation
 * of the [deserialize] method.
 *
 * [deserialize] method takes an instance of [Decoder], and, knowing the serial form of the [T],
 * invokes primitive retrieval methods on the decoder and then transforms the received primitives
 * to an instance of [T].
 *
 * A serial form of the type is a transformation of the concrete instance into a sequence of primitive values
 * and vice versa. The serial form is not required to completely mimic the structure of the class, for example,
 * a specific implementation may represent multiple integer values as a single string, omit or add some
 * values that are present in the type, but not in the instance.
 *
 * For a more detailed explanation of the serialization process, please refer to [KSerializer] documentation.
 */
__attribute__((swift_name("Kotlinx_serialization_coreDeserializationStrategy")))
@protocol KMPWMKotlinx_serialization_coreDeserializationStrategy
@required

/**
 * Deserializes the value of type [T] using the format that is represented by the given [decoder].
 * [deserialize] method is format-agnostic and operates with a high-level structured [Decoder] API.
 * As long as most of the formats imply an arbitrary order of properties, deserializer should be able
 * to decode these properties in an arbitrary order and in a format-agnostic way.
 * For that purposes, [CompositeDecoder.decodeElementIndex]-based loop is used: decoder firstly
 * signals property at which index it is ready to decode and then expects caller to decode
 * property with the given index.
 *
 * Throws [SerializationException] if value cannot be deserialized.
 *
 * Example of deserialize method:
 * ```
 * class MyData(int: Int, stringList: List<String>, alwaysZero: Long)
 *
 * fun deserialize(decoder: Decoder): MyData = decoder.decodeStructure(descriptor) {
 *     // decodeStructure decodes beginning and end of the structure
 *     var int: Int? = null
 *     var list: List<String>? = null
 *     loop@ while (true) {
 *         when (val index = decodeElementIndex(descriptor)) {
 *             DECODE_DONE -> break@loop
 *             0 -> {
 *                 // Decode 'int' property as Int
 *                 int = decodeIntElement(descriptor, index = 0)
 *             }
 *             1 -> {
 *                 // Decode 'stringList' property as List<String>
 *                 list = decodeSerializableElement(descriptor, index = 1, serializer<List<String>>())
 *             }
 *             else -> throw SerializationException("Unexpected index $index")
 *         }
 *      }
 *     if (int == null || list == null) throwMissingFieldException()
 *     // Always use 0 as a value for alwaysZero property because we decided to do so.
 *     return MyData(int, list, alwaysZero = 0L)
 * }
 * ```
 *
 * @throws MissingFieldException if non-optional fields were not found during deserialization
 * @throws SerializationException in case of any deserialization-specific error
 * @throws IllegalArgumentException if the decoded input is not a valid instance of [T]
 * @see KSerializer for additional information about general contracts and exception specifics
 */
- (id _Nullable)deserializeDecoder:(id<KMPWMKotlinx_serialization_coreDecoder>)decoder __attribute__((swift_name("deserialize(decoder:)")));

/**
 * Describes the structure of the serializable representation of [T], that current
 * deserializer is able to deserialize.
 */
@property (readonly) id<KMPWMKotlinx_serialization_coreSerialDescriptor> descriptor __attribute__((swift_name("descriptor")));
@end


/**
 * KSerializer is responsible for the representation of a serial form of a type [T]
 * in terms of [encoders][Encoder] and [decoders][Decoder] and for constructing and deconstructing [T]
 * from/to a sequence of encoding primitives. For classes marked with [@Serializable][Serializable], can be
 * obtained from generated companion extension `.serializer()` or from [serializer<T>()][serializer] function.
 *
 * Serialization is decoupled from the encoding process to make it completely format-agnostic.
 * Serialization represents a type as its serial form and is abstracted from the actual
 * format (whether its JSON, ProtoBuf or a hashing) and unaware of the underlying storage
 * (whether it is a string builder, byte array or a network socket), while
 * encoding/decoding is abstracted from a particular type and its serial form and is responsible
 * for transforming primitives ("here in an int property 'foo'" call from a serializer) into a particular
 * format-specific representation ("for a given int, append a property name in quotation marks,
 * then append a colon, then append an actual value" for JSON) and how to retrieve a primitive
 * ("give me an int that is 'foo' property") from the underlying representation ("expect the next string to be 'foo',
 * parse it, then parse colon, then parse a string until the next comma as an int and return it).
 *
 * Serial form consists of a structural description, declared by the [descriptor] and
 * actual serialization and deserialization processes, defined by the corresponding
 * [serialize] and [deserialize] methods implementation.
 *
 * Structural description specifies how the [T] is represented in the serial form:
 * its [kind][SerialKind] (e.g. whether it is represented as a primitive, a list or a class),
 * its [elements][SerialDescriptor.elementNames] and their [positional names][SerialDescriptor.getElementName].
 *
 * Serialization process is defined as a sequence of calls to an [Encoder], and transforms a type [T]
 * into a stream of format-agnostic primitives that represent [T], such as "here is an int, here is a double
 * and here is another nested object". It can be demonstrated by the example:
 * ```
 * class MyData(int: Int, stringList: List<String>, alwaysZero: Long)
 *
 * // .. serialize method of a corresponding serializer
 * fun serialize(encoder: Encoder, value: MyData): Unit = encoder.encodeStructure(descriptor) {
 *     // encodeStructure encodes beginning and end of the structure
 *     // encode 'int' property as Int
 *     encodeIntElement(descriptor, index = 0, value.int)
 *     // encode 'stringList' property as List<String>
 *     encodeSerializableElement(descriptor, index = 1, serializer<List<String>>, value.stringList)
 *     // don't encode 'alwaysZero' property because we decided to do so
 * } // end of the structure
 * ```
 *
 * Deserialization process is symmetric and uses [Decoder].
 *
 * ### Exception types for `KSerializer` implementation
 *
 * Implementations of [serialize] and [deserialize] methods are allowed to throw
 * any subtype of [IllegalArgumentException] in order to indicate serialization
 * and deserialization errors.
 *
 * For serializer implementations, it is recommended to throw subclasses of [SerializationException] for
 * any serialization-specific errors related to invalid or unsupported format of the data
 * and [IllegalStateException] for errors during validation of the data.
 */
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

__attribute__((swift_name("Kotlinx_coroutines_coreCoroutineScope")))
@protocol KMPWMKotlinx_coroutines_coreCoroutineScope
@required
@property (readonly) id<KMPWMKotlinCoroutineContext> coroutineContext __attribute__((swift_name("coroutineContext")));
@end

__attribute__((swift_name("Ktor_ioCloseable")))
@protocol KMPWMKtor_ioCloseable
@required
- (void)close __attribute__((swift_name("close()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpClient")))
@interface KMPWMKtor_client_coreHttpClient : KMPWMBase <KMPWMKotlinx_coroutines_coreCoroutineScope, KMPWMKtor_ioCloseable>
- (instancetype)initWithEngine:(id<KMPWMKtor_client_coreHttpClientEngine>)engine userConfig:(KMPWMKtor_client_coreHttpClientConfig<KMPWMKtor_client_coreHttpClientEngineConfig *> *)userConfig __attribute__((swift_name("init(engine:userConfig:)"))) __attribute__((objc_designated_initializer));
- (void)close __attribute__((swift_name("close()")));
- (KMPWMKtor_client_coreHttpClient *)configBlock:(void (^)(KMPWMKtor_client_coreHttpClientConfig<id> *))block __attribute__((swift_name("config(block:)")));
- (BOOL)isSupportedCapability:(id<KMPWMKtor_client_coreHttpClientEngineCapability>)capability __attribute__((swift_name("isSupported(capability:)")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) id<KMPWMKtor_utilsAttributes> attributes __attribute__((swift_name("attributes")));
@property (readonly) id<KMPWMKotlinCoroutineContext> coroutineContext __attribute__((swift_name("coroutineContext")));
@property (readonly) id<KMPWMKtor_client_coreHttpClientEngine> engine __attribute__((swift_name("engine")));
@property (readonly) KMPWMKtor_client_coreHttpClientEngineConfig *engineConfig __attribute__((swift_name("engineConfig")));
@property (readonly) KMPWMKtor_eventsEvents *monitor __attribute__((swift_name("monitor")));
@property (readonly) KMPWMKtor_client_coreHttpReceivePipeline *receivePipeline __attribute__((swift_name("receivePipeline")));
@property (readonly) KMPWMKtor_client_coreHttpRequestPipeline *requestPipeline __attribute__((swift_name("requestPipeline")));
@property (readonly) KMPWMKtor_client_coreHttpResponsePipeline *responsePipeline __attribute__((swift_name("responsePipeline")));
@property (readonly) KMPWMKtor_client_coreHttpSendPipeline *sendPipeline __attribute__((swift_name("sendPipeline")));
@end

__attribute__((swift_name("OkioCloseable")))
@protocol KMPWMOkioCloseable
@required

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)closeAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("close_()")));
@end

__attribute__((swift_name("OkioFileSystem")))
@interface KMPWMOkioFileSystem : KMPWMBase <KMPWMOkioCloseable>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) KMPWMOkioFileSystemCompanion *companion __attribute__((swift_name("companion")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<KMPWMOkioSink> _Nullable)appendingSinkFile:(KMPWMOkioPath *)file mustExist:(BOOL)mustExist error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("appendingSink(file:mustExist:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)atomicMoveSource:(KMPWMOkioPath *)source target:(KMPWMOkioPath *)target error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("atomicMove(source:target:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (KMPWMOkioPath * _Nullable)canonicalizePath:(KMPWMOkioPath *)path error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("canonicalize(path:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)closeAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("close_()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)doCopySource:(KMPWMOkioPath *)source target:(KMPWMOkioPath *)target error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("doCopy(source:target:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)createDirectoriesDir:(KMPWMOkioPath *)dir mustCreate:(BOOL)mustCreate error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("createDirectories(dir:mustCreate:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)createDirectoryDir:(KMPWMOkioPath *)dir mustCreate:(BOOL)mustCreate error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("createDirectory(dir:mustCreate:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)createSymlinkSource:(KMPWMOkioPath *)source target:(KMPWMOkioPath *)target error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("createSymlink(source:target:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)deletePath:(KMPWMOkioPath *)path mustExist:(BOOL)mustExist error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("delete(path:mustExist:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)deleteRecursivelyFileOrDirectory:(KMPWMOkioPath *)fileOrDirectory mustExist:(BOOL)mustExist error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("deleteRecursively(fileOrDirectory:mustExist:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)existsPath:(KMPWMOkioPath *)path error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("exists(path:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (NSArray<KMPWMOkioPath *> * _Nullable)listDir:(KMPWMOkioPath *)dir error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("list(dir:)")));
- (NSArray<KMPWMOkioPath *> * _Nullable)listOrNullDir:(KMPWMOkioPath *)dir __attribute__((swift_name("listOrNull(dir:)")));
- (id<KMPWMKotlinSequence>)listRecursivelyDir:(KMPWMOkioPath *)dir followSymlinks:(BOOL)followSymlinks __attribute__((swift_name("listRecursively(dir:followSymlinks:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (KMPWMOkioFileMetadata * _Nullable)metadataPath:(KMPWMOkioPath *)path error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("metadata(path:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (KMPWMOkioFileMetadata * _Nullable)metadataOrNullPath:(KMPWMOkioPath *)path error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("metadataOrNull(path:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (KMPWMOkioFileHandle * _Nullable)openReadOnlyFile:(KMPWMOkioPath *)file error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("openReadOnly(file:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (KMPWMOkioFileHandle * _Nullable)openReadWriteFile:(KMPWMOkioPath *)file mustCreate:(BOOL)mustCreate mustExist:(BOOL)mustExist error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("openReadWrite(file:mustCreate:mustExist:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id _Nullable)readFile:(KMPWMOkioPath *)file error:(NSError * _Nullable * _Nullable)error readerAction:(id _Nullable (^)(id<KMPWMOkioBufferedSource>))readerAction __attribute__((swift_name("read(file:readerAction:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<KMPWMOkioSink> _Nullable)sinkFile:(KMPWMOkioPath *)file mustCreate:(BOOL)mustCreate error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("sink(file:mustCreate:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<KMPWMOkioSource> _Nullable)sourceFile:(KMPWMOkioPath *)file error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("source(file:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id _Nullable)writeFile:(KMPWMOkioPath *)file mustCreate:(BOOL)mustCreate error:(NSError * _Nullable * _Nullable)error writerAction:(id _Nullable (^)(id<KMPWMOkioBufferedSink>))writerAction __attribute__((swift_name("write(file:mustCreate:writerAction:)"))) __attribute__((swift_error(nonnull_error)));
@end


/**
 * Class representing single JSON element.
 * Can be [JsonPrimitive], [JsonArray] or [JsonObject].
 *
 * [JsonElement.toString] properly prints JSON tree as valid JSON, taking into account quoted values and primitives.
 * Whole hierarchy is serializable, but only when used with [Json] as [JsonElement] is purely JSON-specific structure
 * which has a meaningful schemaless semantics only for JSON.
 *
 * The whole hierarchy is [serializable][Serializable] only by [Json] format.
 *
 * @note annotations
 *   kotlinx.serialization.Serializable(with=NormalClass(value=kotlinx/serialization/json/JsonElementSerializer))
*/
__attribute__((swift_name("Kotlinx_serialization_jsonJsonElement")))
@interface KMPWMKotlinx_serialization_jsonJsonElement : KMPWMBase
@property (class, readonly, getter=companion) KMPWMKotlinx_serialization_jsonJsonElementCompanion *companion __attribute__((swift_name("companion")));
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


/**
 * Encoder is a core serialization primitive that encapsulates the knowledge of the underlying
 * format and its storage, exposing only structural methods to the serializer, making it completely
 * format-agnostic. Serialization process transforms a single value into the sequence of its
 * primitive elements, also called its serial form, while encoding transforms these primitive elements into an actual
 * format representation: JSON string, ProtoBuf ByteArray, in-memory map representation etc.
 *
 * Encoder provides high-level API that operates with basic primitive types, collections
 * and nested structures. Internally, encoder represents output storage and operates with its state
 * and lower level format-specific details.
 *
 * To be more specific, serialization transforms a value into a sequence of "here is an int, here is
 * a double, here a list of strings and here is another object that is a nested int", while encoding
 * transforms this sequence into a format-specific commands such as "insert opening curly bracket
 * for a nested object start, insert a name of the value, and the value separated with colon for an int etc."
 *
 * The symmetric interface for the deserialization process is [Decoder].
 *
 * ### Serialization. Primitives
 *
 * If a class is represented as a single [primitive][PrimitiveKind] value in its serialized form,
 * then one of the `encode*` methods (e.g. [encodeInt]) can be used directly.
 *
 * ### Serialization. Structured types.
 *
 * If a class is represented as a structure or has multiple values in its serialized form,
 * `encode*` methods are not that helpful, because they do not allow working with collection types or establish structure boundaries.
 * All these capabilities are delegated to the [CompositeEncoder] interface with a more specific API surface.
 * To denote a structure start, [beginStructure] should be used.
 * ```
 * // Denote the structure start,
 * val composite = encoder.beginStructure(descriptor)
 * // Encoding all elements within the structure using 'composite'
 * ...
 * // Denote the structure end
 * composite.endStructure(descriptor)
 * ```
 *
 * E.g. if the encoder belongs to JSON format, then [beginStructure] will write an opening bracket
 * (`{` or `[`, depending on the descriptor kind), returning the [CompositeEncoder] that is aware of colon separator,
 * that should be appended between each key-value pair, whilst [CompositeEncoder.endStructure] will write a closing bracket.
 *
 * ### Exception guarantees
 *
 * For the regular exceptions, such as invalid input, conflicting serial names,
 * [SerializationException] can be thrown by any encoder methods.
 * It is recommended to declare a format-specific subclass of [SerializationException] and throw it.
 *
 * ### Exception safety
 *
 * In general, catching [SerializationException] from any of `encode*` methods is not allowed and produces unspecified behaviour.
 * After thrown exception, the current encoder is left in an arbitrary state, no longer suitable for further encoding.
 *
 * ### Format encapsulation
 *
 * For example, for the following serializer:
 * ```
 * class StringHolder(val stringValue: String)
 *
 * object StringPairDeserializer : SerializationStrategy<StringHolder> {
 *    override val descriptor = ...
 *
 *    override fun serializer(encoder: Encoder, value: StringHolder) {
 *        // Denotes start of the structure, StringHolder is not a "plain" data type
 *        val composite = encoder.beginStructure(descriptor)
 *        // Encode the nested string value
 *        composite.encodeStringElement(descriptor, index = 0)
 *        // Denotes end of the structure
 *        composite.endStructure(descriptor)
 *    }
 * }
 * ```
 *
 * This serializer does not know anything about the underlying storage and will work with any properly-implemented encoder.
 * JSON, for example, writes an opening bracket `{` during the `beginStructure` call, writes `stringValue` key along
 * with its value in `encodeStringElement` and writes the closing bracket `}` during the `endStructure`.
 * XML would do roughly the same, but with different separators and structures, while ProtoBuf
 * machinery could be completely different.
 * In any case, all these parsing details are encapsulated by an encoder.
 *
 * ### Encoder implementation.
 *
 * While being strictly typed, an underlying format can transform actual types in the way it wants.
 * For example, a format can support only string types and encode/decode all primitives in a string form:
 * ```
 * StringFormatEncoder : Encoder {
 *
 *     ...
 *     override fun encodeDouble(value: Double) = encodeString(value.toString())
 *     override fun encodeInt(value: Int) = encodeString(value.toString())
 *     ...
 * }
 * ```
 *
 * ### Not stable for inheritance
 *
 * `Encoder` interface is not stable for inheritance in 3rd party libraries, as new methods
 * might be added to this interface or contracts of the existing methods can be changed.
 */
__attribute__((swift_name("Kotlinx_serialization_coreEncoder")))
@protocol KMPWMKotlinx_serialization_coreEncoder
@required

/**
 * Encodes the beginning of the collection with size [collectionSize] and the given serializer of its type parameters.
 * This method has to be implemented only if you need to know collection size in advance, otherwise, [beginStructure] can be used.
 */
- (id<KMPWMKotlinx_serialization_coreCompositeEncoder>)beginCollectionDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor collectionSize:(int32_t)collectionSize __attribute__((swift_name("beginCollection(descriptor:collectionSize:)")));

/**
 * Encodes the beginning of the nested structure in a serialized form
 * and returns [CompositeDecoder] responsible for encoding this very structure.
 * E.g the hierarchy:
 * ```
 * class StringHolder(val stringValue: String)
 * class Holder(val stringHolder: StringHolder)
 * ```
 *
 * with the following serialized form in JSON:
 * ```
 * {
 *   "stringHolder" : { "stringValue": "value" }
 * }
 * ```
 *
 * will be roughly represented as the following sequence of calls:
 * ```
 * // Holder serializer
 * fun serialize(encoder: Encoder, value: Holder) {
 *     val composite = encoder.beginStructure(descriptor) // the very first opening bracket '{'
 *     composite.encodeSerializableElement(descriptor, 0, value.stringHolder) // Serialize nested StringHolder
 *     composite.endStructure(descriptor) // The very last closing bracket
 * }
 *
 * // StringHolder serializer
 * fun serialize(encoder: Encoder, value: StringHolder) {
 *     val composite = encoder.beginStructure(descriptor) // One more '{' when the key "stringHolder" is already written
 *     composite.encodeStringElement(descriptor, 0, value.stringValue) // Serialize actual value
 *     composite.endStructure(descriptor) // Closing bracket
 * }
 * ```
 */
- (id<KMPWMKotlinx_serialization_coreCompositeEncoder>)beginStructureDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("beginStructure(descriptor:)")));

/**
 * Encodes a boolean value.
 * Corresponding kind is [PrimitiveKind.BOOLEAN].
 */
- (void)encodeBooleanValue:(BOOL)value __attribute__((swift_name("encodeBoolean(value:)")));

/**
 * Encodes a single byte value.
 * Corresponding kind is [PrimitiveKind.BYTE].
 */
- (void)encodeByteValue:(int8_t)value __attribute__((swift_name("encodeByte(value:)")));

/**
 * Encodes a 16-bit unicode character value.
 * Corresponding kind is [PrimitiveKind.CHAR].
 */
- (void)encodeCharValue:(unichar)value __attribute__((swift_name("encodeChar(value:)")));

/**
 * Encodes a 64-bit IEEE 754 floating point value.
 * Corresponding kind is [PrimitiveKind.DOUBLE].
 */
- (void)encodeDoubleValue:(double)value __attribute__((swift_name("encodeDouble(value:)")));

/**
 * Encodes a enum value that is stored at the [index] in [enumDescriptor] elements collection.
 * Corresponding kind is [SerialKind.ENUM].
 *
 * E.g. for the enum `enum class Letters { A, B, C, D }` and
 * serializable value "C", [encodeEnum] method should be called with `2` as am index.
 *
 * This method does not imply any restrictions on the output format,
 * the format is free to store the enum by its name, index, ordinal or any other
 */
- (void)encodeEnumEnumDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)enumDescriptor index:(int32_t)index __attribute__((swift_name("encodeEnum(enumDescriptor:index:)")));

/**
 * Encodes a 32-bit IEEE 754 floating point value.
 * Corresponding kind is [PrimitiveKind.FLOAT].
 */
- (void)encodeFloatValue:(float)value __attribute__((swift_name("encodeFloat(value:)")));

/**
 * Returns [Encoder] for encoding an underlying type of a value class in an inline manner.
 * [descriptor] describes a serializable value class.
 *
 * Namely, for the `@Serializable @JvmInline value class MyInt(val my: Int)`,
 * the following sequence is used:
 * ```
 * thisEncoder.encodeInline(MyInt.serializer().descriptor).encodeInt(my)
 * ```
 *
 * Current encoder may return any other instance of [Encoder] class, depending on the provided [descriptor].
 * For example, when this function is called on Json encoder with `UInt.serializer().descriptor`, the returned encoder is able
 * to encode unsigned integers.
 *
 * Note that this function returns [Encoder] instead of the [CompositeEncoder]
 * because value classes always have the single property.
 * Calling [Encoder.beginStructure] on returned instance leads to an unspecified behavior and, in general, is prohibited.
 */
- (id<KMPWMKotlinx_serialization_coreEncoder>)encodeInlineDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("encodeInline(descriptor:)")));

/**
 * Encodes a 32-bit integer value.
 * Corresponding kind is [PrimitiveKind.INT].
 */
- (void)encodeIntValue:(int32_t)value __attribute__((swift_name("encodeInt(value:)")));

/**
 * Encodes a 64-bit integer value.
 * Corresponding kind is [PrimitiveKind.LONG].
 */
- (void)encodeLongValue:(int64_t)value __attribute__((swift_name("encodeLong(value:)")));

/**
 * Notifies the encoder that value of a nullable type that is
 * being serialized is not null. It should be called before writing a non-null value
 * of nullable type:
 * ```
 * // Could be String? serialize method
 * if (value != null) {
 *     encoder.encodeNotNullMark()
 *     encoder.encodeStringValue(value)
 * } else {
 *     encoder.encodeNull()
 * }
 * ```
 *
 * This method has a use in highly-performant binary formats and can
 * be safely ignore by most of the regular formats.
 *
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (void)encodeNotNullMark __attribute__((swift_name("encodeNotNullMark()")));

/**
 * Encodes `null` value.
 *
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (void)encodeNull __attribute__((swift_name("encodeNull()")));

/**
 * Encodes the nullable [value] of type [T] by delegating the encoding process to the given [serializer].
 *
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (void)encodeNullableSerializableValueSerializer:(id<KMPWMKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeNullableSerializableValue(serializer:value:)")));

/**
 * Encodes the [value] of type [T] by delegating the encoding process to the given [serializer].
 * For example, `encodeInt` call is equivalent to delegating integer encoding to [Int.serializer][Int.Companion.serializer]:
 * `encodeSerializableValue(Int.serializer())`
 */
- (void)encodeSerializableValueSerializer:(id<KMPWMKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeSerializableValue(serializer:value:)")));

/**
 * Encodes a 16-bit short value.
 * Corresponding kind is [PrimitiveKind.SHORT].
 */
- (void)encodeShortValue:(int16_t)value __attribute__((swift_name("encodeShort(value:)")));

/**
 * Encodes a string value.
 * Corresponding kind is [PrimitiveKind.STRING].
 */
- (void)encodeStringValue:(NSString *)value __attribute__((swift_name("encodeString(value:)")));

/**
 * Context of the current serialization process, including contextual and polymorphic serialization and,
 * potentially, a format-specific configuration.
 */
@property (readonly) KMPWMKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end


/**
 * Serial descriptor is an inherent property of [KSerializer] that describes the structure of the serializable type.
 * The structure of the serializable type is not only the characteristic of the type itself, but also of the serializer as well,
 * meaning that one type can have multiple descriptors that have completely different structures.
 *
 * For example, the class `class Color(val rgb: Int)` can have multiple serializable representations,
 * such as `{"rgb": 255}`, `"#0000FF"`, `[0, 0, 255]` and `{"red": 0, "green": 0, "blue": 255}`.
 * Representations are determined by serializers, and each such serializer has its own descriptor that identifies
 * each structure in a distinguishable and format-agnostic manner.
 *
 * ### Structure
 * Serial descriptor is identified by its [name][serialName] and consists of a kind, potentially empty set of
 * children elements, and additional metadata.
 *
 * * [serialName] uniquely identifies the descriptor (and the corresponding serializer) for non-generic types.
 *   For generic types, the actual type substitution is omitted from the string representation, and the name
 *   identifies the family of the serializers without type substitutions. However, type substitution is accounted for
 *   in [equals] and [hashCode] operations, meaning that descriptors of generic classes with the same name but different type
 *   arguments are not equal to each other.
 *   [serialName] is typically used to specify the type of the target class during serialization of polymorphic and sealed
 *   classes, for observability and diagnostics.
 * * [Kind][SerialKind] defines what this descriptor represents: primitive, enum, object, collection, etc.
 * * Children elements are represented as serial descriptors as well and define the structure of the type's elements.
 * * Metadata carries additional information, such as [nullability][nullable], [optionality][isElementOptional]
 *   and [serial annotations][getElementAnnotations].
 *
 * ### Usages
 * There are two general usages of the descriptors: THE serialization process and serialization introspection.
 *
 * #### Serialization
 * Serial descriptor is used as a bridge between decoders/encoders and serializers.
 * When asking for a next element, the serializer provides an expected descriptor to the decoder, and,
 * based on the descriptor content, the decoder decides how to parse its input.
 * In JSON, for example, when the encoder is asked to encode the next element and this element
 * is a subtype of [List], the encoder receives a descriptor with [StructureKind.LIST] and, based on that,
 * first writes an opening square bracket before writing the content of the list.
 *
 * Serial descriptor _encapsulates_ the structure of the data, so serializers can be free from
 * format-specific details. `ListSerializer` knows nothing about JSON and square brackets, providing
 * only the structure of the data and delegating encoding decision to the format itself.
 *
 * #### Introspection
 * Another usage of a serial descriptor is type introspection without its serialization.
 * Introspection can be used to check whether the given serializable class complies the
 * corresponding scheme and to generate JSON or ProtoBuf schema from the given class.
 *
 * ### Indices
 * Serial descriptor API operates with children indices.
 * For the fixed-size structures, such as regular classes, index is represented by a value in
 * the range from zero to [elementsCount] and represent and index of the property in this class.
 * Consequently, primitives do not have children and their element count is zero.
 *
 * For collections and maps indices do not have a fixed bound. Regular collections descriptors usually
 * have one element (`T`, maps have two, one for keys and one for values), but potentially unlimited
 * number of actual children values. Valid indices range is not known statically,
 * and implementations of such a descriptor should provide consistent and unbounded names and indices.
 *
 * In practice, for regular classes it is allowed to invoke `getElement*(index)` methods
 * with an index from `0` to [elementsCount] range and the element at the particular index corresponds to the
 * serializable property at the given position.
 * For collections and maps, index parameter for `getElement*(index)` methods is effectively bounded
 * by the maximal number of collection/map elements.
 *
 * ### Thread-safety and mutability
 * Serial descriptor implementation should be immutable and, thus, thread-safe.
 *
 * ### Equality and caching
 * Serial descriptor can be used as a unique identifier for format-specific data or schemas and
 * this implies the following restrictions on its `equals` and `hashCode`:
 *
 * An [equals] implementation should use both [serialName] and elements structure.
 * Comparing [elementDescriptors] directly is discouraged,
 * because it may cause a stack overflow error, e.g., if a serializable class `T` contains elements of type `T`.
 * To avoid it, a serial descriptor implementation should compare only descriptors
 * of class' type parameters, in a way that `serializer<Box<Int>>().descriptor != serializer<Box<String>>().descriptor`.
 * If type parameters are equal, descriptor structure should be compared by using children elements
 * descriptors' [serialName]s, which correspond to class names
 * (do not confuse with elements' own names, which correspond to properties' names); and/or other [SerialDescriptor]
 * properties, such as [kind].
 * An example of [equals] implementation:
 * ```
 * if (this === other) return true
 * if (other::class != this::class) return false
 * if (serialName != other.serialName) return false
 * if (!typeParametersAreEqual(other)) return false
 * if (this.elementDescriptors().map { it.serialName } != other.elementDescriptors().map { it.serialName }) return false
 * return true
 * ```
 *
 * [hashCode] implementation should use the same properties for computing the result.
 *
 * ### User-defined serial descriptors
 * The best way to define a custom descriptor is to use [buildClassSerialDescriptor] builder function, where
 * for each serializable property the corresponding element is declared.
 *
 * Example:
 * ```
 * // Class with custom serializer and custom serial descriptor
 * class Data(
 *     val intField: Int, // This field is ignored by custom serializer
 *     val longField: Long, // This field is written as long, but in serialized form is named as "_longField"
 *     val stringList: List<String> // This field is written as regular list of strings
 * )
 *
 * // Descriptor for such class:
 * buildClassSerialDescriptor("my.package.Data") {
 *     // intField is deliberately ignored by serializer -- not present in the descriptor as well
 *     element<Long>("_longField") // longField is named as _longField
 *     element("stringField", listSerialDescriptor<String>())
 * }
 *
 * // Example of 'serialize' function for such descriptor
 * override fun serialize(encoder: Encoder, value: Data) {
 *     encoder.encodeStructure(descriptor) {
 *         encodeLongElement(descriptor, 0, value.longField) // Will be written as "_longField" because descriptor's child at index 0 says so
 *         encodeSerializableElement(descriptor, 1, ListSerializer(String.serializer()), value.stringList)
 *     }
 * }
 * ```
 *
 * For classes that are represented as a single primitive value, [PrimitiveSerialDescriptor] builder function can be used instead.
 *
 * ### Consistency violations
 * An implementation of [SerialDescriptor] should be consistent with the implementation of the corresponding [KSerializer].
 * Yet it is not type-checked statically, thus making it possible to declare a non-consistent implementation of descriptor and serializer.
 * In such cases, the behavior of an underlying format is unspecified and may lead to both runtime errors and encoding of
 * corrupted data that is impossible to decode back.
 *
 * ### Not for implementation
 *
 * `SerialDescriptor` interface should not be implemented in 3rd party libraries, as new methods
 * might be added to this interface when kotlinx.serialization adds support for new Kotlin features.
 * This interface is safe to use and construct via [buildClassSerialDescriptor], [PrimitiveSerialDescriptor], and `SerialDescriptor` factory function.
 */
__attribute__((swift_name("Kotlinx_serialization_coreSerialDescriptor")))
@protocol KMPWMKotlinx_serialization_coreSerialDescriptor
@required

/**
 * Returns serial annotations of the child element at the given [index].
 * This method differs from `getElementDescriptor(index).annotations` by reporting only
 * element-specific annotations:
 * ```
 * @Serializable
 * @OnClassSerialAnnotation
 * class Nested(...)
 *
 * @Serializable
 * class Outer(@OnPropertySerialAnnotation val nested: Nested)
 *
 * val outerDescriptor = Outer.serializer().descriptor
 *
 * outerDescriptor.getElementAnnotations(0) // Returns [@OnPropertySerialAnnotation]
 * outerDescriptor.getElementDescriptor(0).annotations // Returns [@OnClassSerialAnnotation]
 * ```
 * Only annotations marked with [SerialInfo] are added to the resulting list.
 *
 * @throws IndexOutOfBoundsException for an illegal [index] values.
 * @throws IllegalStateException if the current descriptor does not support children elements (e.g. is a primitive).
 */
- (NSArray<id<KMPWMKotlinAnnotation>> *)getElementAnnotationsIndex:(int32_t)index __attribute__((swift_name("getElementAnnotations(index:)")));

/**
 * Retrieves the descriptor of the child element for the given [index].
 * For the property of type `T` on the position `i`, `getElementDescriptor(i)` yields the same result
 * as for `T.serializer().descriptor`, if the serializer for this property is not explicitly overridden
 * with `@Serializable(with = ...`)`, [Polymorphic] or [Contextual].
 * This method can be used to completely introspect the type that the current descriptor describes.
 *
 * Example:
 * ```
 * @Serializable
 * @OnClassSerialAnnotation
 * class Nested(...)
 *
 * @Serializable
 * class Outer(val nested: Nested)
 *
 * val outerDescriptor = Outer.serializer().descriptor
 *
 * outerDescriptor.getElementDescriptor(0).serialName // Returns "Nested"
 * outerDescriptor.getElementDescriptor(0).annotations // Returns [@OnClassSerialAnnotation]
 * ```
 *
 * @throws IndexOutOfBoundsException for illegal [index] values.
 * @throws IllegalStateException if the current descriptor does not support children elements (e.g. is a primitive).
 */
- (id<KMPWMKotlinx_serialization_coreSerialDescriptor>)getElementDescriptorIndex:(int32_t)index __attribute__((swift_name("getElementDescriptor(index:)")));

/**
 * Returns an index in the children list of the given element by its name or [CompositeDecoder.UNKNOWN_NAME]
 * if there is no such element.
 * The resulting index, if it is not [CompositeDecoder.UNKNOWN_NAME], is guaranteed to be usable with [getElementName].
 *
 * Example:
 *
 * ```
 * @Serializable
 * class User(val name: String, val alias: String?)
 *
 * val userDescriptor = User.serializer().descriptor
 *
 * userDescriptor.getElementIndex("name") // Returns 0
 * userDescriptor.getElementIndex("alias") // Returns 1
 * userDescriptor.getElementIndex("lastName") // Returns CompositeDecoder.UNKNOWN_NAME = -3
 * ```
 */
- (int32_t)getElementIndexName:(NSString *)name __attribute__((swift_name("getElementIndex(name:)")));

/**
 * Returns a positional name of the child at the given [index].
 * Positional name represents a corresponding property name in the class, associated with
 * the current descriptor.
 *
 * Do not confuse with [serialName], which returns class name:
 *
 * ```
 * package my.app
 *
 * @Serializable
 * class User(val name: String)
 *
 * val userDescriptor = User.serializer().descriptor
 *
 * userDescriptor.serialName // Returns "my.app.User"
 * userDescriptor.getElementName(0) // Returns "name"
 * ```
 *
 * @throws IndexOutOfBoundsException for an illegal [index] values.
 * @throws IllegalStateException if the current descriptor does not support children elements (e.g. is a primitive)
 */
- (NSString *)getElementNameIndex:(int32_t)index __attribute__((swift_name("getElementName(index:)")));

/**
 * Whether the element at the given [index] is optional (can be absent in serialized form).
 * For generated descriptors, all elements that have a corresponding default parameter value are
 * marked as optional. Custom serializers can treat optional values in a serialization-specific manner
 * without a default parameters constraint.
 *
 * Example of optionality:
 * ```
 * @Serializable
 * class Holder(
 *     val a: Int, // isElementOptional(0) == false
 *     val b: Int?, // isElementOptional(1) == false
 *     val c: Int? = null, // isElementOptional(2) == true
 *     val d: List<Int>, // isElementOptional(3) == false
 *     val e: List<Int> = listOf(1), // isElementOptional(4) == true
 * )
 * ```
 * Returns `false` for valid indices of collections, maps, and enums.
 *
 * @throws IndexOutOfBoundsException for an illegal [index] values.
 * @throws IllegalStateException if the current descriptor does not support children elements (e.g. is a primitive).
 */
- (BOOL)isElementOptionalIndex:(int32_t)index __attribute__((swift_name("isElementOptional(index:)")));

/**
 * Returns serial annotations of the associated class.
 * Serial annotations can be used to specify additional metadata that may be used during serialization.
 * Only annotations marked with [SerialInfo] are added to the resulting list.
 *
 * Do not confuse with [getElementAnnotations]:
 * ```
 * @Serializable
 * @OnClassSerialAnnotation
 * class Nested(...)
 *
 * @Serializable
 * class Outer(@OnPropertySerialAnnotation val nested: Nested)
 *
 * val outerDescriptor = Outer.serializer().descriptor
 *
 * outerDescriptor.getElementAnnotations(0) // Returns [@OnPropertySerialAnnotation]
 * outerDescriptor.getElementDescriptor(0).annotations // Returns [@OnClassSerialAnnotation]
 * ```
 */
@property (readonly) NSArray<id<KMPWMKotlinAnnotation>> *annotations __attribute__((swift_name("annotations")));

/**
 * The number of elements this descriptor describes, besides from the class itself.
 * [elementsCount] describes the number of **semantic** elements, not the number
 * of actual fields/properties in the serialized form, even though they frequently match.
 *
 * For example, for the following class
 * `class Complex(val real: Long, val imaginary: Long)` the corresponding descriptor
 * and the serialized form both have two elements, while for `List<Int>`
 * the corresponding descriptor has a single element (`IntDescriptor`, the type of list element),
 * but from zero up to `Int.MAX_VALUE` values in the serialized form:
 *
 * ```
 * @Serializable
 * class Complex(val real: Long, val imaginary: Long)
 *
 * Complex.serializer().descriptor.elementsCount // Returns 2
 *
 * @Serializable
 * class OuterList(val list: List<Int>)
 *
 * OuterList.serializer().descriptor.getElementDescriptor(0).elementsCount // Returns 1
 * ```
 */
@property (readonly) int32_t elementsCount __attribute__((swift_name("elementsCount")));

/**
 * Returns `true` if this descriptor describes a serializable value class which underlying value
 * is serialized directly.
 *
 * This property is true for serializable `@JvmInline value` classes:
 * ```
 * @Serializable
 * class User(val name: Name)
 *
 * @Serializable
 * @JvmInline
 * value class Name(val value: String)
 *
 * User.serializer().descriptor.isInline // false
 * User.serializer().descriptor.getElementDescriptor(0).isInline // true
 * Name.serializer().descriptor.isInline // true
 * ```
 */
@property (readonly) BOOL isInline __attribute__((swift_name("isInline")));

/**
 * Whether the descriptor describes a nullable type.
 * Returns `true` if associated serializer can serialize/deserialize nullable elements of the described type.
 *
 * Example:
 *
 * ```
 * @Serializable
 * class User(val name: String, val alias: String?)
 *
 * val userDescriptor = User.serializer().descriptor
 *
 * userDescriptor.isNullable // Returns false
 * userDescriptor.getElementDescriptor(0).isNullable // Returns false
 * userDescriptor.getElementDescriptor(1).isNullable // Returns true
 * ```
 */
@property (readonly) BOOL isNullable __attribute__((swift_name("isNullable")));

/**
 * The kind of the serialized form that determines **the shape** of the serialized data.
 * Formats use serial kind to add and parse serializer-agnostic metadata to the result.
 *
 * For example, JSON format wraps [classes][StructureKind.CLASS] and [StructureKind.MAP] into
 * brackets, while ProtoBuf just serialize these types in separate ways.
 *
 * Kind should be consistent with the implementation, for example, if it is a [primitive][PrimitiveKind],
 * then its element count should be zero and vice versa.
 *
 * Example of introspecting kinds:
 *
 * ```
 * @Serializable
 * class User(val name: String)
 *
 * val userDescriptor = User.serializer().descriptor
 *
 * userDescriptor.kind // Returns StructureKind.CLASS
 * userDescriptor.getElementDescriptor(0).kind // Returns PrimitiveKind.STRING
 * ```
 */
@property (readonly) KMPWMKotlinx_serialization_coreSerialKind *kind __attribute__((swift_name("kind")));

/**
 * Serial name of the descriptor that identifies a pair of the associated serializer and target class.
 *
 * For generated and default serializers, the serial name is equal to the corresponding class's fully qualified name
 * or, if overridden, [SerialName].
 * Custom serializers should provide a unique serial name that identifies both the serializable class and
 * the serializer itself, ignoring type arguments if they are present, for example: `my.package.LongAsTrimmedString`.
 *
 * Do not confuse with [getElementName], which returns property name:
 *
 * ```
 * package my.app
 *
 * @Serializable
 * class User(val name: String)
 *
 * val userDescriptor = User.serializer().descriptor
 *
 * userDescriptor.serialName // Returns "my.app.User"
 * userDescriptor.getElementName(0) // Returns "name"
 * ```
 */
@property (readonly) NSString *serialName __attribute__((swift_name("serialName")));
@end


/**
 * Decoder is a core deserialization primitive that encapsulates the knowledge of the underlying
 * format and an underlying storage, exposing only structural methods to the deserializer, making it completely
 * format-agnostic. Deserialization process takes a decoder and asks him for a sequence of primitive elements,
 * defined by a deserializer serial form, while decoder knows how to retrieve these primitive elements from an actual format
 * representations.
 *
 * Decoder provides high-level API that operates with basic primitive types, collections
 * and nested structures. Internally, the decoder represents input storage, and operates with its state
 * and lower level format-specific details.
 *
 * To be more specific, serialization asks a decoder for a sequence of "give me an int, give me
 * a double, give me a list of strings and give me another object that is a nested int", while decoding
 * transforms this sequence into a format-specific commands such as "parse the part of the string until the next quotation mark
 * as an int to retrieve an int, parse everything within the next curly braces to retrieve elements of a nested object etc."
 *
 * The symmetric interface for the serialization process is [Encoder].
 *
 * ### Deserialization. Primitives
 *
 * If a class is represented as a single [primitive][PrimitiveKind] value in its serialized form,
 * then one of the `decode*` methods (e.g. [decodeInt]) can be used directly.
 *
 * ### Deserialization. Structured types
 *
 * If a class is represented as a structure or has multiple values in its serialized form,
 * `decode*` methods are not that helpful, because format may not require a strict order of data
 * (e.g. JSON or XML), do not allow working with collection types or establish structure boundaries.
 * All these capabilities are delegated to the [CompositeDecoder] interface with a more specific API surface.
 * To denote a structure start, [beginStructure] should be used.
 * ```
 * // Denote the structure start,
 * val composite = decoder.beginStructure(descriptor)
 * // Decode all elements within the structure using 'composite'
 * ...
 * // Denote the structure end
 * composite.endStructure(descriptor)
 * ```
 *
 * E.g. if the decoder belongs to JSON format, then [beginStructure] will parse an opening bracket
 * (`{` or `[`, depending on the descriptor kind), returning the [CompositeDecoder] that is aware of colon separator,
 * that should be read after each key-value pair, whilst [CompositeDecoder.endStructure] will parse a closing bracket.
 *
 * ### Exception guarantees
 *
 * For the regular exceptions, such as invalid input, missing control symbols or attributes, and unknown symbols,
 * [SerializationException] can be thrown by any decoder methods. It is recommended to declare a format-specific
 * subclass of [SerializationException] and throw it.
 *
 * ### Exception safety
 *
 * In general, catching [SerializationException] from any of `decode*` methods is not allowed and produces unspecified behavior.
 * After thrown exception, the current decoder is left in an arbitrary state, no longer suitable for further decoding.
 *
 * ### Format encapsulation
 *
 * For example, for the following deserializer:
 * ```
 * class StringHolder(val stringValue: String)
 *
 * object StringPairDeserializer : DeserializationStrategy<StringHolder> {
 *    override val descriptor = ...
 *
 *    override fun deserializer(decoder: Decoder): StringHolder {
 *        // Denotes start of the structure, StringHolder is not a "plain" data type
 *        val composite = decoder.beginStructure(descriptor)
 *        if (composite.decodeElementIndex(descriptor) != 0)
 *            throw MissingFieldException("Field 'stringValue' is missing")
 *        // Decode the nested string value
 *        val value = composite.decodeStringElement(descriptor, index = 0)
 *        // Denotes end of the structure
 *        composite.endStructure(descriptor)
 *    }
 * }
 * ```
 *
 * This deserializer does not know anything about the underlying data and will work with any properly-implemented decoder.
 * JSON, for example, parses an opening bracket `{` during the `beginStructure` call, checks that the next key
 * after this bracket is `stringValue` (using the descriptor), returns the value after the colon as string value
 * and parses closing bracket `}` during the `endStructure`.
 * XML would do roughly the same, but with different separators and parsing structures, while ProtoBuf
 * machinery could be completely different.
 * In any case, all these parsing details are encapsulated by a decoder.
 *
 * ### Decoder implementation
 *
 * While being strictly typed, an underlying format can transform actual types in the way it wants.
 * For example, a format can support only string types and encode/decode all primitives in a string form:
 * ```
 * StringFormatDecoder : Decoder {
 *
 *     ...
 *     override fun decodeDouble(): Double = decodeString().toDouble()
 *     override fun decodeInt(): Int = decodeString().toInt()
 *     ...
 * }
 * ```
 *
 * ### Not stable for inheritance
 *
 * `Decoder` interface is not stable for inheritance in 3rd-party libraries, as new methods
 * might be added to this interface or contracts of the existing methods can be changed.
 */
__attribute__((swift_name("Kotlinx_serialization_coreDecoder")))
@protocol KMPWMKotlinx_serialization_coreDecoder
@required

/**
 * Decodes the beginning of the nested structure in a serialized form
 * and returns [CompositeDecoder] responsible for decoding this very structure.
 *
 * Typically, classes, collections and maps are represented as a nested structure in a serialized form.
 * E.g. the following JSON
 * ```
 * {
 *     "a": 2,
 *     "b": { "nested": "c" }
 *     "c": [1, 2, 3],
 *     "d": null
 * }
 * ```
 * has three nested structures: the very beginning of the data, "b" value and "c" value.
 */
- (id<KMPWMKotlinx_serialization_coreCompositeDecoder>)beginStructureDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("beginStructure(descriptor:)")));

/**
 * Decodes a boolean value.
 * Corresponding kind is [PrimitiveKind.BOOLEAN].
 */
- (BOOL)decodeBoolean __attribute__((swift_name("decodeBoolean()")));

/**
 * Decodes a single byte value.
 * Corresponding kind is [PrimitiveKind.BYTE].
 */
- (int8_t)decodeByte __attribute__((swift_name("decodeByte()")));

/**
 * Decodes a 16-bit unicode character value.
 * Corresponding kind is [PrimitiveKind.CHAR].
 */
- (unichar)decodeChar __attribute__((swift_name("decodeChar()")));

/**
 * Decodes a 64-bit IEEE 754 floating point value.
 * Corresponding kind is [PrimitiveKind.DOUBLE].
 */
- (double)decodeDouble __attribute__((swift_name("decodeDouble()")));

/**
 * Decodes a enum value and returns its index in [enumDescriptor] elements collection.
 * Corresponding kind is [SerialKind.ENUM].
 *
 * E.g. for the enum `enum class Letters { A, B, C, D }` and
 * underlying input "C", [decodeEnum] method should return `2` as a result.
 *
 * This method does not imply any restrictions on the input format,
 * the format is free to store the enum by its name, index, ordinal or any other enum representation.
 */
- (int32_t)decodeEnumEnumDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)enumDescriptor __attribute__((swift_name("decodeEnum(enumDescriptor:)")));

/**
 * Decodes a 32-bit IEEE 754 floating point value.
 * Corresponding kind is [PrimitiveKind.FLOAT].
 */
- (float)decodeFloat __attribute__((swift_name("decodeFloat()")));

/**
 * Returns [Decoder] for decoding an underlying type of a value class in an inline manner.
 * [descriptor] describes a target value class.
 *
 * Namely, for the `@Serializable @JvmInline value class MyInt(val my: Int)`, the following sequence is used:
 * ```
 * thisDecoder.decodeInline(MyInt.serializer().descriptor).decodeInt()
 * ```
 *
 * Current decoder may return any other instance of [Decoder] class, depending on the provided [descriptor].
 * For example, when this function is called on `Json` decoder with
 * `UInt.serializer().descriptor`, the returned decoder is able to decode unsigned integers.
 *
 * Note that this function returns [Decoder] instead of the [CompositeDecoder]
 * because value classes always have the single property.
 *
 * Calling [Decoder.beginStructure] on returned instance leads to an unspecified behavior and, in general, is prohibited.
 */
- (id<KMPWMKotlinx_serialization_coreDecoder>)decodeInlineDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("decodeInline(descriptor:)")));

/**
 * Decodes a 32-bit integer value.
 * Corresponding kind is [PrimitiveKind.INT].
 */
- (int32_t)decodeInt __attribute__((swift_name("decodeInt()")));

/**
 * Decodes a 64-bit integer value.
 * Corresponding kind is [PrimitiveKind.LONG].
 */
- (int64_t)decodeLong __attribute__((swift_name("decodeLong()")));

/**
 * Returns `true` if the current value in decoder is not null, false otherwise.
 * This method is usually used to decode potentially nullable data:
 * ```
 * // Could be String? deserialize() method
 * public fun deserialize(decoder: Decoder): String? {
 *     if (decoder.decodeNotNullMark()) {
 *         return decoder.decodeString()
 *     } else {
 *         return decoder.decodeNull()
 *     }
 * }
 * ```
 *
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (BOOL)decodeNotNullMark __attribute__((swift_name("decodeNotNullMark()")));

/**
 * Decodes the `null` value and returns it.
 *
 * It is expected that `decodeNotNullMark` was called
 * prior to `decodeNull` invocation and the case when it returned `true` was handled.
 *
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (KMPWMKotlinNothing * _Nullable)decodeNull __attribute__((swift_name("decodeNull()")));

/**
 * Decodes the nullable value of type [T] by delegating the decoding process to the given [deserializer].
 *
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id _Nullable)decodeNullableSerializableValueDeserializer:(id<KMPWMKotlinx_serialization_coreDeserializationStrategy>)deserializer __attribute__((swift_name("decodeNullableSerializableValue(deserializer:)")));

/**
 * Decodes the value of type [T] by delegating the decoding process to the given [deserializer].
 * For example, `decodeInt` call is equivalent to delegating integer decoding to [Int.serializer][Int.Companion.serializer]:
 * `decodeSerializableValue(Int.serializer())`
 */
- (id _Nullable)decodeSerializableValueDeserializer:(id<KMPWMKotlinx_serialization_coreDeserializationStrategy>)deserializer __attribute__((swift_name("decodeSerializableValue(deserializer:)")));

/**
 * Decodes a 16-bit short value.
 * Corresponding kind is [PrimitiveKind.SHORT].
 */
- (int16_t)decodeShort __attribute__((swift_name("decodeShort()")));

/**
 * Decodes a string value.
 * Corresponding kind is [PrimitiveKind.STRING].
 */
- (NSString *)decodeString __attribute__((swift_name("decodeString()")));

/**
 * Context of the current serialization process, including contextual and polymorphic serialization and,
 * potentially, a format-specific configuration.
 */
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


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.3")
*/
__attribute__((swift_name("KotlinCoroutineContext")))
@protocol KMPWMKotlinCoroutineContext
@required
- (id _Nullable)foldInitial:(id _Nullable)initial operation:(id _Nullable (^)(id _Nullable, id<KMPWMKotlinCoroutineContextElement>))operation __attribute__((swift_name("fold(initial:operation:)")));
- (id<KMPWMKotlinCoroutineContextElement> _Nullable)getKey:(id<KMPWMKotlinCoroutineContextKey>)key __attribute__((swift_name("get(key:)")));
- (id<KMPWMKotlinCoroutineContext>)minusKeyKey:(id<KMPWMKotlinCoroutineContextKey>)key __attribute__((swift_name("minusKey(key:)")));
- (id<KMPWMKotlinCoroutineContext>)plusContext:(id<KMPWMKotlinCoroutineContext>)context __attribute__((swift_name("plus(context:)")));
@end

__attribute__((swift_name("Ktor_client_coreHttpClientEngine")))
@protocol KMPWMKtor_client_coreHttpClientEngine <KMPWMKotlinx_coroutines_coreCoroutineScope, KMPWMKtor_ioCloseable>
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)executeData:(KMPWMKtor_client_coreHttpRequestData *)data completionHandler:(void (^)(KMPWMKtor_client_coreHttpResponseData * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("execute(data:completionHandler:)")));
- (void)installClient:(KMPWMKtor_client_coreHttpClient *)client __attribute__((swift_name("install(client:)")));
@property (readonly) KMPWMKtor_client_coreHttpClientEngineConfig *config __attribute__((swift_name("config")));
@property (readonly) KMPWMKotlinx_coroutines_coreCoroutineDispatcher *dispatcher __attribute__((swift_name("dispatcher")));
@property (readonly) NSSet<id<KMPWMKtor_client_coreHttpClientEngineCapability>> *supportedCapabilities __attribute__((swift_name("supportedCapabilities")));
@end

__attribute__((swift_name("Ktor_client_coreHttpClientEngineConfig")))
@interface KMPWMKtor_client_coreHttpClientEngineConfig : KMPWMBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property BOOL pipelining __attribute__((swift_name("pipelining")));
@property KMPWMKtor_client_coreProxyConfig * _Nullable proxy __attribute__((swift_name("proxy")));
@property int32_t threadsCount __attribute__((swift_name("threadsCount"))) __attribute__((deprecated("The [threadsCount] property is deprecated. The [Dispatchers.IO] is used by default.")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpClientConfig")))
@interface KMPWMKtor_client_coreHttpClientConfig<T> : KMPWMBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (KMPWMKtor_client_coreHttpClientConfig<T> *)clone __attribute__((swift_name("clone()")));
- (void)engineBlock:(void (^)(T))block __attribute__((swift_name("engine(block:)")));
- (void)installClient:(KMPWMKtor_client_coreHttpClient *)client __attribute__((swift_name("install(client:)")));
- (void)installPlugin:(id<KMPWMKtor_client_coreHttpClientPlugin>)plugin configure:(void (^)(id))configure __attribute__((swift_name("install(plugin:configure:)")));
- (void)installKey:(NSString *)key block:(void (^)(KMPWMKtor_client_coreHttpClient *))block __attribute__((swift_name("install(key:block:)")));
- (void)plusAssignOther:(KMPWMKtor_client_coreHttpClientConfig<T> *)other __attribute__((swift_name("plusAssign(other:)")));
@property BOOL developmentMode __attribute__((swift_name("developmentMode")));
@property BOOL expectSuccess __attribute__((swift_name("expectSuccess")));
@property BOOL followRedirects __attribute__((swift_name("followRedirects")));
@property BOOL useDefaultTransformers __attribute__((swift_name("useDefaultTransformers")));
@end

__attribute__((swift_name("Ktor_client_coreHttpClientEngineCapability")))
@protocol KMPWMKtor_client_coreHttpClientEngineCapability
@required
@end

__attribute__((swift_name("Ktor_utilsAttributes")))
@protocol KMPWMKtor_utilsAttributes
@required
- (id)computeIfAbsentKey:(KMPWMKtor_utilsAttributeKey<id> *)key block:(id (^)(void))block __attribute__((swift_name("computeIfAbsent(key:block:)")));
- (BOOL)containsKey:(KMPWMKtor_utilsAttributeKey<id> *)key __attribute__((swift_name("contains(key:)")));
- (id)getKey_:(KMPWMKtor_utilsAttributeKey<id> *)key __attribute__((swift_name("get(key_:)")));
- (id _Nullable)getOrNullKey:(KMPWMKtor_utilsAttributeKey<id> *)key __attribute__((swift_name("getOrNull(key:)")));
- (void)putKey:(KMPWMKtor_utilsAttributeKey<id> *)key value:(id)value __attribute__((swift_name("put(key:value:)")));
- (void)removeKey:(KMPWMKtor_utilsAttributeKey<id> *)key __attribute__((swift_name("remove(key:)")));
- (id)takeKey:(KMPWMKtor_utilsAttributeKey<id> *)key __attribute__((swift_name("take(key:)")));
- (id _Nullable)takeOrNullKey:(KMPWMKtor_utilsAttributeKey<id> *)key __attribute__((swift_name("takeOrNull(key:)")));
@property (readonly) NSArray<KMPWMKtor_utilsAttributeKey<id> *> *allKeys __attribute__((swift_name("allKeys")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_eventsEvents")))
@interface KMPWMKtor_eventsEvents : KMPWMBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (void)raiseDefinition:(KMPWMKtor_eventsEventDefinition<id> *)definition value:(id _Nullable)value __attribute__((swift_name("raise(definition:value:)")));
- (id<KMPWMKotlinx_coroutines_coreDisposableHandle>)subscribeDefinition:(KMPWMKtor_eventsEventDefinition<id> *)definition handler:(void (^)(id _Nullable))handler __attribute__((swift_name("subscribe(definition:handler:)")));
- (void)unsubscribeDefinition:(KMPWMKtor_eventsEventDefinition<id> *)definition handler:(void (^)(id _Nullable))handler __attribute__((swift_name("unsubscribe(definition:handler:)")));
@end

__attribute__((swift_name("Ktor_utilsPipeline")))
@interface KMPWMKtor_utilsPipeline<TSubject, TContext> : KMPWMBase
- (instancetype)initWithPhases:(KMPWMKotlinArray<KMPWMKtor_utilsPipelinePhase *> *)phases __attribute__((swift_name("init(phases:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithPhase:(KMPWMKtor_utilsPipelinePhase *)phase interceptors:(NSArray<id<KMPWMKotlinSuspendFunction2>> *)interceptors __attribute__((swift_name("init(phase:interceptors:)"))) __attribute__((objc_designated_initializer));
- (void)addPhasePhase:(KMPWMKtor_utilsPipelinePhase *)phase __attribute__((swift_name("addPhase(phase:)")));
- (void)afterIntercepted __attribute__((swift_name("afterIntercepted()")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)executeContext:(TContext)context subject:(TSubject)subject completionHandler:(void (^)(TSubject _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("execute(context:subject:completionHandler:)")));
- (void)insertPhaseAfterReference:(KMPWMKtor_utilsPipelinePhase *)reference phase:(KMPWMKtor_utilsPipelinePhase *)phase __attribute__((swift_name("insertPhaseAfter(reference:phase:)")));
- (void)insertPhaseBeforeReference:(KMPWMKtor_utilsPipelinePhase *)reference phase:(KMPWMKtor_utilsPipelinePhase *)phase __attribute__((swift_name("insertPhaseBefore(reference:phase:)")));
- (void)interceptPhase:(KMPWMKtor_utilsPipelinePhase *)phase block:(id<KMPWMKotlinSuspendFunction2>)block __attribute__((swift_name("intercept(phase:block:)")));
- (NSArray<id<KMPWMKotlinSuspendFunction2>> *)interceptorsForPhasePhase:(KMPWMKtor_utilsPipelinePhase *)phase __attribute__((swift_name("interceptorsForPhase(phase:)")));
- (void)mergeFrom:(KMPWMKtor_utilsPipeline<TSubject, TContext> *)from __attribute__((swift_name("merge(from:)")));
- (void)mergePhasesFrom:(KMPWMKtor_utilsPipeline<TSubject, TContext> *)from __attribute__((swift_name("mergePhases(from:)")));
- (void)resetFromFrom:(KMPWMKtor_utilsPipeline<TSubject, TContext> *)from __attribute__((swift_name("resetFrom(from:)")));
@property (readonly) id<KMPWMKtor_utilsAttributes> attributes __attribute__((swift_name("attributes")));
@property (readonly) BOOL developmentMode __attribute__((swift_name("developmentMode")));
@property (readonly) BOOL isEmpty __attribute__((swift_name("isEmpty")));
@property (readonly) NSArray<KMPWMKtor_utilsPipelinePhase *> *items __attribute__((swift_name("items")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpReceivePipeline")))
@interface KMPWMKtor_client_coreHttpReceivePipeline : KMPWMKtor_utilsPipeline<KMPWMKtor_client_coreHttpResponse *, KMPWMKotlinUnit *>
- (instancetype)initWithDevelopmentMode:(BOOL)developmentMode __attribute__((swift_name("init(developmentMode:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithPhases:(KMPWMKotlinArray<KMPWMKtor_utilsPipelinePhase *> *)phases __attribute__((swift_name("init(phases:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)initWithPhase:(KMPWMKtor_utilsPipelinePhase *)phase interceptors:(NSArray<id<KMPWMKotlinSuspendFunction2>> *)interceptors __attribute__((swift_name("init(phase:interceptors:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) KMPWMKtor_client_coreHttpReceivePipelinePhases *companion __attribute__((swift_name("companion")));
@property (readonly) BOOL developmentMode __attribute__((swift_name("developmentMode")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpRequestPipeline")))
@interface KMPWMKtor_client_coreHttpRequestPipeline : KMPWMKtor_utilsPipeline<id, KMPWMKtor_client_coreHttpRequestBuilder *>
- (instancetype)initWithDevelopmentMode:(BOOL)developmentMode __attribute__((swift_name("init(developmentMode:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithPhases:(KMPWMKotlinArray<KMPWMKtor_utilsPipelinePhase *> *)phases __attribute__((swift_name("init(phases:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)initWithPhase:(KMPWMKtor_utilsPipelinePhase *)phase interceptors:(NSArray<id<KMPWMKotlinSuspendFunction2>> *)interceptors __attribute__((swift_name("init(phase:interceptors:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) KMPWMKtor_client_coreHttpRequestPipelinePhases *companion __attribute__((swift_name("companion")));
@property (readonly) BOOL developmentMode __attribute__((swift_name("developmentMode")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpResponsePipeline")))
@interface KMPWMKtor_client_coreHttpResponsePipeline : KMPWMKtor_utilsPipeline<KMPWMKtor_client_coreHttpResponseContainer *, KMPWMKtor_client_coreHttpClientCall *>
- (instancetype)initWithDevelopmentMode:(BOOL)developmentMode __attribute__((swift_name("init(developmentMode:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithPhases:(KMPWMKotlinArray<KMPWMKtor_utilsPipelinePhase *> *)phases __attribute__((swift_name("init(phases:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)initWithPhase:(KMPWMKtor_utilsPipelinePhase *)phase interceptors:(NSArray<id<KMPWMKotlinSuspendFunction2>> *)interceptors __attribute__((swift_name("init(phase:interceptors:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) KMPWMKtor_client_coreHttpResponsePipelinePhases *companion __attribute__((swift_name("companion")));
@property (readonly) BOOL developmentMode __attribute__((swift_name("developmentMode")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpSendPipeline")))
@interface KMPWMKtor_client_coreHttpSendPipeline : KMPWMKtor_utilsPipeline<id, KMPWMKtor_client_coreHttpRequestBuilder *>
- (instancetype)initWithDevelopmentMode:(BOOL)developmentMode __attribute__((swift_name("init(developmentMode:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithPhases:(KMPWMKotlinArray<KMPWMKtor_utilsPipelinePhase *> *)phases __attribute__((swift_name("init(phases:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (instancetype)initWithPhase:(KMPWMKtor_utilsPipelinePhase *)phase interceptors:(NSArray<id<KMPWMKotlinSuspendFunction2>> *)interceptors __attribute__((swift_name("init(phase:interceptors:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) KMPWMKtor_client_coreHttpSendPipelinePhases *companion __attribute__((swift_name("companion")));
@property (readonly) BOOL developmentMode __attribute__((swift_name("developmentMode")));
@end

__attribute__((swift_name("OkioIOException")))
@interface KMPWMOkioIOException : KMPWMKotlinException
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithMessage:(NSString * _Nullable)message __attribute__((swift_name("init(message:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithMessage:(NSString * _Nullable)message cause:(KMPWMKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(message:cause:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCause:(KMPWMKotlinThrowable * _Nullable)cause __attribute__((swift_name("init(cause:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("OkioFileSystem.Companion")))
@interface KMPWMOkioFileSystemCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMOkioFileSystemCompanion *shared __attribute__((swift_name("shared")));

/**
 * The current process's host file system. Use this instance directly, or dependency inject a
 * [FileSystem] to make code testable.
 */
@property (readonly) KMPWMOkioFileSystem *SYSTEM __attribute__((swift_name("SYSTEM")));
@property (readonly) KMPWMOkioPath *SYSTEM_TEMPORARY_DIRECTORY __attribute__((swift_name("SYSTEM_TEMPORARY_DIRECTORY")));
@end

__attribute__((swift_name("OkioSink")))
@protocol KMPWMOkioSink <KMPWMOkioCloseable>
@required

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)flushAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("flush()")));
- (KMPWMOkioTimeout *)timeout __attribute__((swift_name("timeout()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)writeSource:(KMPWMOkioBuffer *)source byteCount:(int64_t)byteCount error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("write(source:byteCount:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("OkioPath")))
@interface KMPWMOkioPath : KMPWMBase <KMPWMKotlinComparable>
@property (class, readonly, getter=companion) KMPWMOkioPathCompanion *companion __attribute__((swift_name("companion")));
- (int32_t)compareToOther:(KMPWMOkioPath *)other __attribute__((swift_name("compareTo(other:)")));
- (KMPWMOkioPath *)divChild:(NSString *)child __attribute__((swift_name("div(child:)")));
- (KMPWMOkioPath *)divChild_:(KMPWMOkioByteString *)child __attribute__((swift_name("div(child_:)")));
- (KMPWMOkioPath *)divChild__:(KMPWMOkioPath *)child __attribute__((swift_name("div(child__:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (KMPWMOkioPath *)normalized __attribute__((swift_name("normalized()")));
- (KMPWMOkioPath *)relativeToOther:(KMPWMOkioPath *)other __attribute__((swift_name("relativeTo(other:)")));
- (KMPWMOkioPath *)resolveChild:(NSString *)child normalize:(BOOL)normalize __attribute__((swift_name("resolve(child:normalize:)")));
- (KMPWMOkioPath *)resolveChild:(KMPWMOkioByteString *)child normalize_:(BOOL)normalize __attribute__((swift_name("resolve(child:normalize_:)")));
- (KMPWMOkioPath *)resolveChild:(KMPWMOkioPath *)child normalize__:(BOOL)normalize __attribute__((swift_name("resolve(child:normalize__:)")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) BOOL isAbsolute __attribute__((swift_name("isAbsolute")));
@property (readonly) BOOL isRelative __attribute__((swift_name("isRelative")));
@property (readonly) BOOL isRoot __attribute__((swift_name("isRoot")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@property (readonly) KMPWMOkioByteString *nameBytes __attribute__((swift_name("nameBytes")));
@property (readonly) KMPWMOkioPath * _Nullable parent __attribute__((swift_name("parent")));
@property (readonly) KMPWMOkioPath * _Nullable root __attribute__((swift_name("root")));
@property (readonly) NSArray<NSString *> *segments __attribute__((swift_name("segments")));
@property (readonly) NSArray<KMPWMOkioByteString *> *segmentsBytes __attribute__((swift_name("segmentsBytes")));
@property (readonly) id _Nullable volumeLetter __attribute__((swift_name("volumeLetter")));
@end

__attribute__((swift_name("KotlinSequence")))
@protocol KMPWMKotlinSequence
@required
- (id<KMPWMKotlinIterator>)iterator __attribute__((swift_name("iterator()")));
@end


/**
 * Description of a file or another object referenced by a path.
 *
 * In simple use a file system is a mechanism for organizing files and directories on a local
 * storage device. In practice file systems are more capable and their contents more varied. For
 * example, a path may refer to:
 *
 *  * An operating system process that consumes data, produces data, or both. For example, reading
 *    from the `/dev/urandom` file on Linux returns a unique sequence of pseudorandom bytes to each
 *    reader.
 *
 *  * A stream that connects a pair of programs together. A pipe is a special file that a producing
 *    program writes to and a consuming program reads from. Both programs operate concurrently. The
 *    size of a pipe is not well defined: the writer can write as much data as the reader is able to
 *    read.
 *
 *  * A file on a remote file system. The performance and availability of remote files may be quite
 *    different from that of local files!
 *
 *  * A symbolic link (symlink) to another path. When attempting to access this path the file system
 *    will follow the link and return data from the target path.
 *
 *  * The same content as another path without a symlink. On UNIX file systems an inode is an
 *    anonymous handle to a file's content, and multiple paths may target the same inode without any
 *    other relationship to one another. A consequence of this design is that a directory with three
 *    1 GiB files may only need 1 GiB on the storage device.
 *
 * This class does not attempt to model these rich file system features! It exposes a limited view
 * useful for programs with only basic file system needs. Be cautious of the potential consequences
 * of special files when writing programs that operate on a file system.
 *
 * File metadata is subject to change, and code that operates on file systems should defend against
 * changes to the file that occur between reading metadata and subsequent operations.
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("OkioFileMetadata")))
@interface KMPWMOkioFileMetadata : KMPWMBase
- (instancetype)initWithIsRegularFile:(BOOL)isRegularFile isDirectory:(BOOL)isDirectory symlinkTarget:(KMPWMOkioPath * _Nullable)symlinkTarget size:(KMPWMLong * _Nullable)size createdAtMillis:(KMPWMLong * _Nullable)createdAtMillis lastModifiedAtMillis:(KMPWMLong * _Nullable)lastModifiedAtMillis lastAccessedAtMillis:(KMPWMLong * _Nullable)lastAccessedAtMillis extras:(NSDictionary<id<KMPWMKotlinKClass>, id> *)extras __attribute__((swift_name("init(isRegularFile:isDirectory:symlinkTarget:size:createdAtMillis:lastModifiedAtMillis:lastAccessedAtMillis:extras:)"))) __attribute__((objc_designated_initializer));
- (KMPWMOkioFileMetadata *)doCopyIsRegularFile:(BOOL)isRegularFile isDirectory:(BOOL)isDirectory symlinkTarget:(KMPWMOkioPath * _Nullable)symlinkTarget size:(KMPWMLong * _Nullable)size createdAtMillis:(KMPWMLong * _Nullable)createdAtMillis lastModifiedAtMillis:(KMPWMLong * _Nullable)lastModifiedAtMillis lastAccessedAtMillis:(KMPWMLong * _Nullable)lastAccessedAtMillis extras:(NSDictionary<id<KMPWMKotlinKClass>, id> *)extras __attribute__((swift_name("doCopy(isRegularFile:isDirectory:symlinkTarget:size:createdAtMillis:lastModifiedAtMillis:lastAccessedAtMillis:extras:)")));

/** Returns extra metadata of type [type], or null if no such metadata is held. */
- (id _Nullable)extraType:(id<KMPWMKotlinKClass>)type __attribute__((swift_name("extra(type:)")));
- (NSString *)description __attribute__((swift_name("description()")));

/**
 * The system time of the host computer when this file was created, if the host file system
 * supports this feature. This is typically available on Windows NTFS file systems and not
 * available on UNIX or Windows FAT file systems.
 */
@property (readonly) KMPWMLong * _Nullable createdAtMillis __attribute__((swift_name("createdAtMillis")));

/**
 * Additional file system-specific metadata organized by the class of that metadata. File systems
 * may use this to include information like permissions, content-type, or linked applications.
 *
 * Values in this map should be instances of immutable classes. Keys should be the types of those
 * classes.
 */
@property (readonly) NSDictionary<id<KMPWMKotlinKClass>, id> *extras __attribute__((swift_name("extras")));

/**
 * True if the path refers to a directory that contains 0 or more child paths.
 *
 * Note that a path does not need to be a directory for [FileSystem.list] to return successfully.
 * For example, mounted storage devices may have child files, but do not identify themselves as
 * directories.
 */
@property (readonly) BOOL isDirectory __attribute__((swift_name("isDirectory")));

/** True if this file is a container of bytes. If this is true, then [size] is non-null. */
@property (readonly) BOOL isRegularFile __attribute__((swift_name("isRegularFile")));

/**
 * The system time of the host computer when this file was most recently read or written.
 *
 * Note that the accuracy of the returned time may be much more coarse than its precision. In
 * particular, this value is expressed with millisecond precision but may be accessed at
 * second- or day-accuracy only.
 */
@property (readonly) KMPWMLong * _Nullable lastAccessedAtMillis __attribute__((swift_name("lastAccessedAtMillis")));

/**
 * The system time of the host computer when this file was most recently written.
 *
 * Note that the accuracy of the returned time may be much more coarse than its precision. In
 * particular, this value is expressed with millisecond precision but may be accessed at
 * second- or day-accuracy only.
 */
@property (readonly) KMPWMLong * _Nullable lastModifiedAtMillis __attribute__((swift_name("lastModifiedAtMillis")));

/**
 * The number of bytes readable from this file. The amount of storage resources consumed by this
 * file may be larger (due to block size overhead, redundant copies for RAID, etc.), or smaller
 * (due to file system compression, shared inodes, etc).
 */
@property (readonly) KMPWMLong * _Nullable size __attribute__((swift_name("size")));

/**
 * The absolute or relative path that this file is a symlink to, or null if this is not a symlink.
 * If this is a relative path, it is relative to the source file's parent directory.
 */
@property (readonly) KMPWMOkioPath * _Nullable symlinkTarget __attribute__((swift_name("symlinkTarget")));
@end


/**
 * An open file for reading and writing; using either streaming and random access.
 *
 * Use [read] and [write] to perform one-off random-access reads and writes. Use [source], [sink],
 * and [appendingSink] for streaming reads and writes.
 *
 * File handles must be closed when they are no longer needed. It is an error to read, write, or
 * create streams after a file handle is closed. The operating system resources held by a file
 * handle will be released once the file handle **and** all of its streams are closed.
 *
 * Although this class offers both reading and writing APIs, file handle instances may be
 * read-only or write-only. For example, a handle to a file on a read-only file system will throw an
 * exception if a write is attempted.
 *
 * File handles may be used by multiple threads concurrently. But the individual sources and sinks
 * produced by a file handle are not safe for concurrent use.
 */
__attribute__((swift_name("OkioFileHandle")))
@interface KMPWMOkioFileHandle : KMPWMBase <KMPWMOkioCloseable>
- (instancetype)initWithReadWrite:(BOOL)readWrite __attribute__((swift_name("init(readWrite:)"))) __attribute__((objc_designated_initializer));

/**
 * Returns a sink that writes to this starting at the end. The returned sink must be closed when
 * it is no longer needed.
 *
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<KMPWMOkioSink> _Nullable)appendingSinkAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("appendingSink()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)closeAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("close_()")));

/** Pushes all buffered bytes to their final destination.
 *
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)flushAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("flush()")));

/**
 * Returns the position of [sink] in the file. The argument [sink] must be either a sink produced
 * by this file handle, or a [BufferedSink] that directly wraps such a sink. If the parameter is a
 * [BufferedSink], it adjusts for buffered bytes.
 *
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (int64_t)positionSink:(id<KMPWMOkioSink>)sink error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("position(sink:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * Returns the position of [source] in the file. The argument [source] must be either a source
 * produced by this file handle, or a [BufferedSource] that directly wraps such a source. If the
 * parameter is a [BufferedSource], it adjusts for buffered bytes.
 *
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (int64_t)positionSource:(id<KMPWMOkioSource>)source error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("position(source:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * Subclasses should implement this to release resources held by this file handle. It is invoked
 * once both the file handle is closed, and also all sources and sinks produced by it are also
 * closed.
 *
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (BOOL)protectedCloseAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("protectedClose()")));

/** Like [flush] but not performing any close check.
 *
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (BOOL)protectedFlushAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("protectedFlush()")));

/** Like [read] but not performing any close check.
 *
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (int32_t)protectedReadFileOffset:(int64_t)fileOffset array:(KMPWMKotlinByteArray *)array arrayOffset:(int32_t)arrayOffset byteCount:(int32_t)byteCount error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("protectedRead(fileOffset:array:arrayOffset:byteCount:)"))) __attribute__((swift_error(nonnull_error)));

/** Like [resize] but not performing any close check.
 *
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (BOOL)protectedResizeSize:(int64_t)size error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("protectedResize(size:)")));

/** Like [size] but not performing any close check.
 *
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (int64_t)protectedSizeAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("protectedSize()"))) __attribute__((swift_error(nonnull_error)));

/** Like [write] but not performing any close check.
 *
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (BOOL)protectedWriteFileOffset:(int64_t)fileOffset array:(KMPWMKotlinByteArray *)array arrayOffset:(int32_t)arrayOffset byteCount:(int32_t)byteCount error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("protectedWrite(fileOffset:array:arrayOffset:byteCount:)")));

/**
 * Reads at least 1, and up to [byteCount] bytes from this starting at [fileOffset] and appends
 * them to [sink]. Returns the number of bytes read, or -1 if [fileOffset] equals [size].
 *
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (int64_t)readFileOffset:(int64_t)fileOffset sink:(KMPWMOkioBuffer *)sink byteCount:(int64_t)byteCount error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("read(fileOffset:sink:byteCount:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * Reads at least 1, and up to [byteCount] bytes from this starting at [fileOffset] and copies
 * them to [array] at [arrayOffset]. Returns the number of bytes read, or -1 if [fileOffset]
 * equals [size].
 *
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (int32_t)readFileOffset:(int64_t)fileOffset array:(KMPWMKotlinByteArray *)array arrayOffset:(int32_t)arrayOffset byteCount:(int32_t)byteCount error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("read(fileOffset:array:arrayOffset:byteCount:)"))) __attribute__((swift_error(nonnull_error)));

/**
 * Change the position of [sink] in the file to [position]. The argument [sink] must be either a
 * sink produced by this file handle, or a [BufferedSink] that directly wraps such a sink. If the
 * parameter is a [BufferedSink], it emits for buffered bytes.
 *
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)repositionSink:(id<KMPWMOkioSink>)sink position:(int64_t)position error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("reposition(sink:position:)")));

/**
 * Change the position of [source] in the file to [position]. The argument [source] must be either
 * a source produced by this file handle, or a [BufferedSource] that directly wraps such a source.
 * If the parameter is a [BufferedSource], it will skip or clear buffered bytes.
 *
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)repositionSource:(id<KMPWMOkioSource>)source position:(int64_t)position error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("reposition(source:position:)")));

/**
 * Changes the number of bytes in this file to [size]. This will remove bytes from the end if the
 * new size is smaller. It will add `0` bytes to the end if it is larger.
 *
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)resizeSize:(int64_t)size error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("resize(size:)")));

/**
 * Returns a sink that writes to this starting at [fileOffset]. The returned sink must be closed
 * when it is no longer needed.
 *
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<KMPWMOkioSink> _Nullable)sinkFileOffset:(int64_t)fileOffset error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("sink(fileOffset:)")));

/**
 * Returns the total number of bytes in the file. This will change if the file size changes.
 *
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (int64_t)sizeAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("size()"))) __attribute__((swift_error(nonnull_error)));

/**
 * Returns a source that reads from this starting at [fileOffset]. The returned source must be
 * closed when it is no longer needed.
 *
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (id<KMPWMOkioSource> _Nullable)sourceFileOffset:(int64_t)fileOffset error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("source(fileOffset:)")));

/** Removes [byteCount] bytes from [source] and writes them to this at [fileOffset].
 *
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)writeFileOffset:(int64_t)fileOffset source:(KMPWMOkioBuffer *)source byteCount:(int64_t)byteCount error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("write(fileOffset:source:byteCount:)")));

/** Reads [byteCount] bytes from [array] and writes them to this at [fileOffset]. */
- (void)writeFileOffset:(int64_t)fileOffset array:(KMPWMKotlinByteArray *)array arrayOffset:(int32_t)arrayOffset byteCount:(int32_t)byteCount __attribute__((swift_name("write(fileOffset:array:arrayOffset:byteCount:)")));
@property (readonly) KMPWMOkioLock *lock __attribute__((swift_name("lock")));

/**
 * True if this handle supports both reading and writing. If this is false all write operations
 * including [write], [sink], [resize], and [flush] will all throw [IllegalStateException] if
 * called.
 */
@property (readonly) BOOL readWrite __attribute__((swift_name("readWrite")));
@end


/**
 * Supplies a stream of bytes. Use this interface to read data from wherever it's located: from the
 * network, storage, or a buffer in memory. Sources may be layered to transform supplied data, such
 * as to decompress, decrypt, or remove protocol framing.
 *
 * Most applications shouldn't operate on a source directly, but rather on a [BufferedSource] which
 * is both more efficient and more convenient. Use [buffer] to wrap any source with a buffer.
 *
 * Sources are easy to test: just use a [Buffer] in your tests, and fill it with the data your
 * application is to read.
 *
 * ### Comparison with InputStream
 * This interface is functionally equivalent to [java.io.InputStream].
 *
 * `InputStream` requires multiple layers when consumed data is heterogeneous: a `DataInputStream`
 * for primitive values, a `BufferedInputStream` for buffering, and `InputStreamReader` for strings.
 * This library uses `BufferedSource` for all of the above.
 *
 * Source avoids the impossible-to-implement [available()][java.io.InputStream.available] method.
 * Instead callers specify how many bytes they [require][BufferedSource.require].
 *
 * Source omits the unsafe-to-compose [mark and reset][java.io.InputStream.mark] state that's
 * tracked by `InputStream`; instead, callers just buffer what they need.
 *
 * When implementing a source, you don't need to worry about the [read()][java.io.InputStream.read]
 * method that is awkward to implement efficiently and returns one of 257 possible values.
 *
 * And source has a stronger `skip` method: [BufferedSource.skip] won't return prematurely.
 *
 * ### Interop with InputStream
 *
 * Use [source] to adapt an `InputStream` to a source. Use [BufferedSource.inputStream] to adapt a
 * source to an `InputStream`.
 */
__attribute__((swift_name("OkioSource")))
@protocol KMPWMOkioSource <KMPWMOkioCloseable>
@required

/**
 * Removes at least 1, and up to `byteCount` bytes from this and appends them to `sink`. Returns
 * the number of bytes read, or -1 if this source is exhausted.
 *
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (int64_t)readSink:(KMPWMOkioBuffer *)sink byteCount:(int64_t)byteCount error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("read(sink:byteCount:)"))) __attribute__((swift_error(nonnull_error)));

/** Returns the timeout for this source.  */
- (KMPWMOkioTimeout *)timeout __attribute__((swift_name("timeout()")));
@end

__attribute__((swift_name("OkioBufferedSource")))
@protocol KMPWMOkioBufferedSource <KMPWMOkioSource>
@required
- (BOOL)exhausted __attribute__((swift_name("exhausted()")));
- (int64_t)indexOfB:(int8_t)b __attribute__((swift_name("indexOf(b:)")));
- (int64_t)indexOfBytes:(KMPWMOkioByteString *)bytes __attribute__((swift_name("indexOf(bytes:)")));
- (int64_t)indexOfB:(int8_t)b fromIndex:(int64_t)fromIndex __attribute__((swift_name("indexOf(b:fromIndex:)")));
- (int64_t)indexOfBytes:(KMPWMOkioByteString *)bytes fromIndex:(int64_t)fromIndex __attribute__((swift_name("indexOf(bytes:fromIndex:)")));
- (int64_t)indexOfB:(int8_t)b fromIndex:(int64_t)fromIndex toIndex:(int64_t)toIndex __attribute__((swift_name("indexOf(b:fromIndex:toIndex:)")));
- (int64_t)indexOfBytes:(KMPWMOkioByteString *)bytes fromIndex:(int64_t)fromIndex toIndex:(int64_t)toIndex __attribute__((swift_name("indexOf(bytes:fromIndex:toIndex:)")));
- (int64_t)indexOfElementTargetBytes:(KMPWMOkioByteString *)targetBytes __attribute__((swift_name("indexOfElement(targetBytes:)")));
- (int64_t)indexOfElementTargetBytes:(KMPWMOkioByteString *)targetBytes fromIndex:(int64_t)fromIndex __attribute__((swift_name("indexOfElement(targetBytes:fromIndex:)")));
- (id<KMPWMOkioBufferedSource>)peek __attribute__((swift_name("peek()")));
- (BOOL)rangeEqualsOffset:(int64_t)offset bytes:(KMPWMOkioByteString *)bytes __attribute__((swift_name("rangeEquals(offset:bytes:)")));
- (BOOL)rangeEqualsOffset:(int64_t)offset bytes:(KMPWMOkioByteString *)bytes bytesOffset:(int32_t)bytesOffset byteCount:(int32_t)byteCount __attribute__((swift_name("rangeEquals(offset:bytes:bytesOffset:byteCount:)")));
- (int32_t)readSink:(KMPWMKotlinByteArray *)sink __attribute__((swift_name("read(sink:)")));
- (int32_t)readSink:(KMPWMKotlinByteArray *)sink offset:(int32_t)offset byteCount:(int32_t)byteCount __attribute__((swift_name("read(sink:offset:byteCount:)")));
- (int64_t)readAllSink:(id<KMPWMOkioSink>)sink __attribute__((swift_name("readAll(sink:)")));
- (int8_t)readByte __attribute__((swift_name("readByte()")));
- (KMPWMKotlinByteArray *)readByteArray __attribute__((swift_name("readByteArray()")));
- (KMPWMKotlinByteArray *)readByteArrayByteCount:(int64_t)byteCount __attribute__((swift_name("readByteArray(byteCount:)")));
- (KMPWMOkioByteString *)readByteString __attribute__((swift_name("readByteString()")));
- (KMPWMOkioByteString *)readByteStringByteCount:(int64_t)byteCount __attribute__((swift_name("readByteString(byteCount:)")));
- (int64_t)readDecimalLong __attribute__((swift_name("readDecimalLong()")));
- (void)readFullySink:(KMPWMKotlinByteArray *)sink __attribute__((swift_name("readFully(sink:)")));
- (void)readFullySink:(KMPWMOkioBuffer *)sink byteCount:(int64_t)byteCount __attribute__((swift_name("readFully(sink:byteCount:)")));
- (int64_t)readHexadecimalUnsignedLong __attribute__((swift_name("readHexadecimalUnsignedLong()")));
- (int32_t)readInt __attribute__((swift_name("readInt()")));
- (int32_t)readIntLe __attribute__((swift_name("readIntLe()")));
- (int64_t)readLong __attribute__((swift_name("readLong()")));
- (int64_t)readLongLe __attribute__((swift_name("readLongLe()")));
- (int16_t)readShort __attribute__((swift_name("readShort()")));
- (int16_t)readShortLe __attribute__((swift_name("readShortLe()")));
- (NSString *)readUtf8 __attribute__((swift_name("readUtf8()")));
- (NSString *)readUtf8ByteCount:(int64_t)byteCount __attribute__((swift_name("readUtf8(byteCount:)")));
- (int32_t)readUtf8CodePoint __attribute__((swift_name("readUtf8CodePoint()")));
- (NSString * _Nullable)readUtf8Line __attribute__((swift_name("readUtf8Line()")));
- (NSString *)readUtf8LineStrict __attribute__((swift_name("readUtf8LineStrict()")));
- (NSString *)readUtf8LineStrictLimit:(int64_t)limit __attribute__((swift_name("readUtf8LineStrict(limit:)")));
- (BOOL)requestByteCount:(int64_t)byteCount __attribute__((swift_name("request(byteCount:)")));
- (void)requireByteCount:(int64_t)byteCount __attribute__((swift_name("require(byteCount:)")));
- (int32_t)selectOptions:(NSArray<KMPWMOkioByteString *> *)options __attribute__((swift_name("select(options:)")));
- (id _Nullable)selectOptions_:(NSArray<id> *)options __attribute__((swift_name("select(options_:)")));
- (void)skipByteCount:(int64_t)byteCount __attribute__((swift_name("skip(byteCount:)")));
@property (readonly) KMPWMOkioBuffer *buffer __attribute__((swift_name("buffer")));
@end

__attribute__((swift_name("OkioBufferedSink")))
@protocol KMPWMOkioBufferedSink <KMPWMOkioSink>
@required
- (id<KMPWMOkioBufferedSink>)emit __attribute__((swift_name("emit()")));
- (id<KMPWMOkioBufferedSink>)emitCompleteSegments __attribute__((swift_name("emitCompleteSegments()")));
- (id<KMPWMOkioBufferedSink>)writeSource:(KMPWMKotlinByteArray *)source __attribute__((swift_name("write(source:)")));
- (id<KMPWMOkioBufferedSink>)writeByteString:(KMPWMOkioByteString *)byteString __attribute__((swift_name("write(byteString:)")));
- (id<KMPWMOkioBufferedSink>)writeSource:(id<KMPWMOkioSource>)source byteCount:(int64_t)byteCount __attribute__((swift_name("write(source:byteCount_:)")));
- (id<KMPWMOkioBufferedSink>)writeSource:(KMPWMKotlinByteArray *)source offset:(int32_t)offset byteCount:(int32_t)byteCount __attribute__((swift_name("write(source:offset:byteCount:)")));
- (id<KMPWMOkioBufferedSink>)writeByteString:(KMPWMOkioByteString *)byteString offset:(int32_t)offset byteCount:(int32_t)byteCount __attribute__((swift_name("write(byteString:offset:byteCount:)")));
- (int64_t)writeAllSource:(id<KMPWMOkioSource>)source __attribute__((swift_name("writeAll(source:)")));
- (id<KMPWMOkioBufferedSink>)writeByteB:(int32_t)b __attribute__((swift_name("writeByte(b:)")));
- (id<KMPWMOkioBufferedSink>)writeDecimalLongV:(int64_t)v __attribute__((swift_name("writeDecimalLong(v:)")));
- (id<KMPWMOkioBufferedSink>)writeHexadecimalUnsignedLongV:(int64_t)v __attribute__((swift_name("writeHexadecimalUnsignedLong(v:)")));
- (id<KMPWMOkioBufferedSink>)writeIntI:(int32_t)i __attribute__((swift_name("writeInt(i:)")));
- (id<KMPWMOkioBufferedSink>)writeIntLeI:(int32_t)i __attribute__((swift_name("writeIntLe(i:)")));
- (id<KMPWMOkioBufferedSink>)writeLongV:(int64_t)v __attribute__((swift_name("writeLong(v:)")));
- (id<KMPWMOkioBufferedSink>)writeLongLeV:(int64_t)v __attribute__((swift_name("writeLongLe(v:)")));
- (id<KMPWMOkioBufferedSink>)writeShortS:(int32_t)s __attribute__((swift_name("writeShort(s:)")));
- (id<KMPWMOkioBufferedSink>)writeShortLeS:(int32_t)s __attribute__((swift_name("writeShortLe(s:)")));
- (id<KMPWMOkioBufferedSink>)writeUtf8String:(NSString *)string __attribute__((swift_name("writeUtf8(string:)")));
- (id<KMPWMOkioBufferedSink>)writeUtf8String:(NSString *)string beginIndex:(int32_t)beginIndex endIndex:(int32_t)endIndex __attribute__((swift_name("writeUtf8(string:beginIndex:endIndex:)")));
- (id<KMPWMOkioBufferedSink>)writeUtf8CodePointCodePoint:(int32_t)codePoint __attribute__((swift_name("writeUtf8CodePoint(codePoint:)")));
@property (readonly) KMPWMOkioBuffer *buffer __attribute__((swift_name("buffer")));
@end


/**
 * Class representing single JSON element.
 * Can be [JsonPrimitive], [JsonArray] or [JsonObject].
 *
 * [JsonElement.toString] properly prints JSON tree as valid JSON, taking into account quoted values and primitives.
 * Whole hierarchy is serializable, but only when used with [Json] as [JsonElement] is purely JSON-specific structure
 * which has a meaningful schemaless semantics only for JSON.
 *
 * The whole hierarchy is [serializable][Serializable] only by [Json] format.
 */
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Kotlinx_serialization_jsonJsonElement.Companion")))
@interface KMPWMKotlinx_serialization_jsonJsonElementCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));

/**
 * Class representing single JSON element.
 * Can be [JsonPrimitive], [JsonArray] or [JsonObject].
 *
 * [JsonElement.toString] properly prints JSON tree as valid JSON, taking into account quoted values and primitives.
 * Whole hierarchy is serializable, but only when used with [Json] as [JsonElement] is purely JSON-specific structure
 * which has a meaningful schemaless semantics only for JSON.
 *
 * The whole hierarchy is [serializable][Serializable] only by [Json] format.
 */
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKotlinx_serialization_jsonJsonElementCompanion *shared __attribute__((swift_name("shared")));

/**
 * Class representing single JSON element.
 * Can be [JsonPrimitive], [JsonArray] or [JsonObject].
 *
 * [JsonElement.toString] properly prints JSON tree as valid JSON, taking into account quoted values and primitives.
 * Whole hierarchy is serializable, but only when used with [Json] as [JsonElement] is purely JSON-specific structure
 * which has a meaningful schemaless semantics only for JSON.
 *
 * The whole hierarchy is [serializable][Serializable] only by [Json] format.
 */
- (id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("serializer()")));
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


/**
 * [CompositeEncoder] is a part of encoding process that is bound to a particular structured part of
 * the serialized form, described by the serial descriptor passed to [Encoder.beginStructure].
 *
 * All `encode*` methods have `index` and `serialDescriptor` parameters with a strict semantics and constraints:
 *   * `descriptor` is always the same as one used in [Encoder.beginStructure]. While this parameter may seem redundant,
 *      it is required for efficient serialization process to avoid excessive field spilling.
 *      If you are writing your own format, you can safely ignore this parameter and use one used in `beginStructure`
 *      for simplicity.
 *   * `index` of the element being encoded. This element at this index in the descriptor should be associated with
 *      the one being written.
 *
 * The symmetric interface for the deserialization process is [CompositeDecoder].
 *
 * ### Not stable for inheritance
 *
 * `CompositeEncoder` interface is not stable for inheritance in 3rd party libraries, as new methods
 * might be added to this interface or contracts of the existing methods can be changed.
 */
__attribute__((swift_name("Kotlinx_serialization_coreCompositeEncoder")))
@protocol KMPWMKotlinx_serialization_coreCompositeEncoder
@required

/**
 * Encodes a boolean [value] associated with an element at the given [index] in [serial descriptor][descriptor].
 * The element at the given [index] should have [PrimitiveKind.BOOLEAN] kind.
 */
- (void)encodeBooleanElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(BOOL)value __attribute__((swift_name("encodeBooleanElement(descriptor:index:value:)")));

/**
 * Encodes a single byte [value] associated with an element at the given [index] in [serial descriptor][descriptor].
 * The element at the given [index] should have [PrimitiveKind.BYTE] kind.
 */
- (void)encodeByteElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(int8_t)value __attribute__((swift_name("encodeByteElement(descriptor:index:value:)")));

/**
 * Encodes a 16-bit unicode character [value] associated with an element at the given [index] in [serial descriptor][descriptor].
 * The element at the given [index] should have [PrimitiveKind.CHAR] kind.
 */
- (void)encodeCharElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(unichar)value __attribute__((swift_name("encodeCharElement(descriptor:index:value:)")));

/**
 * Encodes a 64-bit IEEE 754 floating point [value] associated with an element
 * at the given [index] in [serial descriptor][descriptor].
 * The element at the given [index] should have [PrimitiveKind.DOUBLE] kind.
 */
- (void)encodeDoubleElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(double)value __attribute__((swift_name("encodeDoubleElement(descriptor:index:value:)")));

/**
 * Encodes a 32-bit IEEE 754 floating point [value] associated with an element
 * at the given [index] in [serial descriptor][descriptor].
 * The element at the given [index] should have [PrimitiveKind.FLOAT] kind.
 */
- (void)encodeFloatElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(float)value __attribute__((swift_name("encodeFloatElement(descriptor:index:value:)")));

/**
 * Returns [Encoder] for decoding an underlying type of a value class in an inline manner.
 * Serializable value class is described by the [child descriptor][SerialDescriptor.getElementDescriptor]
 * of given [descriptor] at [index].
 *
 * Namely, for the `@Serializable @JvmInline value class MyInt(val my: Int)`,
 * and `@Serializable class MyData(val myInt: MyInt)` the following sequence is used:
 * ```
 * thisEncoder.encodeInlineElement(MyData.serializer.descriptor, 0).encodeInt(my)
 * ```
 *
 * This method provides an opportunity for the optimization to avoid boxing of a carried value
 * and its invocation should be equivalent to the following:
 * ```
 * thisEncoder.encodeSerializableElement(MyData.serializer.descriptor, 0, MyInt.serializer(), myInt)
 * ```
 *
 * Current encoder may return any other instance of [Encoder] class, depending on provided descriptor.
 * For example, when this function is called on Json encoder with descriptor that has
 * `UInt.serializer().descriptor` at the given [index], the returned encoder is able
 * to encode unsigned integers.
 *
 * Note that this function returns [Encoder] instead of the [CompositeEncoder]
 * because value classes always have the single property.
 * Calling [Encoder.beginStructure] on returned instance leads to an unspecified behavior and, in general, is prohibited.
 *
 * @see Encoder.encodeInline
 * @see SerialDescriptor.getElementDescriptor
 */
- (id<KMPWMKotlinx_serialization_coreEncoder>)encodeInlineElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("encodeInlineElement(descriptor:index:)")));

/**
 * Encodes a 32-bit integer [value] associated with an element at the given [index] in [serial descriptor][descriptor].
 * The element at the given [index] should have [PrimitiveKind.INT] kind.
 */
- (void)encodeIntElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(int32_t)value __attribute__((swift_name("encodeIntElement(descriptor:index:value:)")));

/**
 * Encodes a 64-bit integer [value] associated with an element at the given [index] in [serial descriptor][descriptor].
 * The element at the given [index] should have [PrimitiveKind.LONG] kind.
 */
- (void)encodeLongElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(int64_t)value __attribute__((swift_name("encodeLongElement(descriptor:index:value:)")));

/**
 * Delegates nullable [value] encoding of the type [T] to the given [serializer].
 * [value] is associated with an element at the given [index] in [serial descriptor][descriptor].
 *
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (void)encodeNullableSerializableElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index serializer:(id<KMPWMKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeNullableSerializableElement(descriptor:index:serializer:value:)")));

/**
 * Delegates [value] encoding of the type [T] to the given [serializer].
 * [value] is associated with an element at the given [index] in [serial descriptor][descriptor].
 */
- (void)encodeSerializableElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index serializer:(id<KMPWMKotlinx_serialization_coreSerializationStrategy>)serializer value:(id _Nullable)value __attribute__((swift_name("encodeSerializableElement(descriptor:index:serializer:value:)")));

/**
 * Encodes a 16-bit short [value] associated with an element at the given [index] in [serial descriptor][descriptor].
 * The element at the given [index] should have [PrimitiveKind.SHORT] kind.
 */
- (void)encodeShortElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(int16_t)value __attribute__((swift_name("encodeShortElement(descriptor:index:value:)")));

/**
 * Encodes a string [value] associated with an element at the given [index] in [serial descriptor][descriptor].
 * The element at the given [index] should have [PrimitiveKind.STRING] kind.
 */
- (void)encodeStringElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index value:(NSString *)value __attribute__((swift_name("encodeStringElement(descriptor:index:value:)")));

/**
 * Denotes the end of the structure associated with current encoder.
 * For example, composite encoder of JSON format will write
 * a closing bracket in the underlying input and reduce the number of nesting for pretty printing.
 */
- (void)endStructureDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("endStructure(descriptor:)")));

/**
 * Whether the format should encode values that are equal to the default values.
 * This method is used by plugin-generated serializers for properties with default values:
 * ```
 * @Serializable
 * class WithDefault(val int: Int = 42)
 * // serialize method
 * if (value.int != 42 || output.shouldEncodeElementDefault(serialDesc, 0)) {
 *    encoder.encodeIntElement(serialDesc, 0, value.int);
 * }
 * ```
 *
 * This method is never invoked for properties annotated with [EncodeDefault].
 *
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (BOOL)shouldEncodeElementDefaultDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("shouldEncodeElementDefault(descriptor:index:)")));

/**
 * Context of the current serialization process, including contextual and polymorphic serialization and,
 * potentially, a format-specific configuration.
 */
@property (readonly) KMPWMKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end


/**
 * [SerializersModule] is a collection of serializers used by [ContextualSerializer] and [PolymorphicSerializer]
 * to override or provide serializers at the runtime, whereas at the compile-time they provided by the serialization plugin.
 * It can be considered as a map where serializers can be found using their statically known KClasses.
 *
 * To enable runtime serializers resolution, one of the special annotations must be used on target types
 * ([Polymorphic] or [Contextual]), and a serial module with serializers should be used during construction of [SerialFormat].
 *
 * Serializers module can be built with `SerializersModule {}` builder function.
 * Empty module can be obtained with `EmptySerializersModule()` factory function.
 *
 * @see Contextual
 * @see Polymorphic
 */
__attribute__((swift_name("Kotlinx_serialization_coreSerializersModule")))
@interface KMPWMKotlinx_serialization_coreSerializersModule : KMPWMBase

/**
 * Copies contents of this module to the given [collector].
 *
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (void)dumpToCollector:(id<KMPWMKotlinx_serialization_coreSerializersModuleCollector>)collector __attribute__((swift_name("dumpTo(collector:)")));

/**
 * Returns a contextual serializer associated with a given [kClass].
 * If given class has generic parameters and module has provider for [kClass],
 * [typeArgumentsSerializers] are used to create serializer.
 * This method is used in context-sensitive operations on a property marked with [Contextual] by a [ContextualSerializer].
 *
 * @see SerializersModuleBuilder.contextual
 *
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id<KMPWMKotlinx_serialization_coreKSerializer> _Nullable)getContextualKClass:(id<KMPWMKotlinKClass>)kClass typeArgumentsSerializers:(NSArray<id<KMPWMKotlinx_serialization_coreKSerializer>> *)typeArgumentsSerializers __attribute__((swift_name("getContextual(kClass:typeArgumentsSerializers:)")));

/**
 * Returns a polymorphic serializer registered for a class of the given [value] in the scope of [baseClass].
 *
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id<KMPWMKotlinx_serialization_coreSerializationStrategy> _Nullable)getPolymorphicBaseClass:(id<KMPWMKotlinKClass>)baseClass value:(id)value __attribute__((swift_name("getPolymorphic(baseClass:value:)")));

/**
 * Returns a polymorphic deserializer registered for a [serializedClassName] in the scope of [baseClass]
 * or default value constructed from [serializedClassName] if a default serializer provider was registered.
 *
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id<KMPWMKotlinx_serialization_coreDeserializationStrategy> _Nullable)getPolymorphicBaseClass:(id<KMPWMKotlinKClass>)baseClass serializedClassName:(NSString * _Nullable)serializedClassName __attribute__((swift_name("getPolymorphic(baseClass:serializedClassName:)")));
@end

__attribute__((swift_name("KotlinAnnotation")))
@protocol KMPWMKotlinAnnotation
@required
@end


/**
 * Serial kind is an intrinsic property of [SerialDescriptor] that indicates how
 * the corresponding type is structurally represented by its serializer.
 *
 * Kind is used by serialization formats to determine how exactly the given type
 * should be serialized. For example, JSON format detects the kind of the value and,
 * depending on that, may write it as a plain value for primitive kinds, open a
 * curly brace '{' for class-like structures and square bracket '[' for list- and array- like structures.
 *
 * Kinds are used both during serialization, to serialize a value properly and statically, and
 * to introspect the type structure or build serialization schema.
 *
 * Kind should match the structure of the serialized form, not the structure of the corresponding Kotlin class.
 * Meaning that if serializable class `class IntPair(val left: Int, val right: Int)` is represented by the serializer
 * as a single `Long` value, its descriptor should have [PrimitiveKind.LONG] without nested elements even though the class itself
 * represents a structure with two primitive fields.
 */
__attribute__((swift_name("Kotlinx_serialization_coreSerialKind")))
@interface KMPWMKotlinx_serialization_coreSerialKind : KMPWMBase
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@end


/**
 * [CompositeDecoder] is a part of decoding process that is bound to a particular structured part of
 * the serialized form, described by the serial descriptor passed to [Decoder.beginStructure].
 *
 * Typically, for unordered data, [CompositeDecoder] is used by a serializer withing a [decodeElementIndex]-based
 * loop that decodes all the required data one-by-one in any order and then terminates by calling [endStructure].
 * Please refer to [decodeElementIndex] for example of such loop.
 *
 * All `decode*` methods have `index` and `serialDescriptor` parameters with a strict semantics and constraints:
 *   * `descriptor` argument is always the same as one used in [Decoder.beginStructure].
 *   * `index` of the element being decoded. For [sequential][decodeSequentially] decoding, it is always a monotonic
 *      sequence from `0` to `descriptor.elementsCount` and for indexing-loop it is always an index that [decodeElementIndex]
 *      has returned from the last call.
 *
 * The symmetric interface for the serialization process is [CompositeEncoder].
 *
 * ### Not stable for inheritance
 *
 * `CompositeDecoder` interface is not stable for inheritance in 3rd party libraries, as new methods
 * might be added to this interface or contracts of the existing methods can be changed.
 */
__attribute__((swift_name("Kotlinx_serialization_coreCompositeDecoder")))
@protocol KMPWMKotlinx_serialization_coreCompositeDecoder
@required

/**
 * Decodes a boolean value from the underlying input.
 * The resulting value is associated with the [descriptor] element at the given [index].
 * The element at the given index should have [PrimitiveKind.BOOLEAN] kind.
 */
- (BOOL)decodeBooleanElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeBooleanElement(descriptor:index:)")));

/**
 * Decodes a single byte value from the underlying input.
 * The resulting value is associated with the [descriptor] element at the given [index].
 * The element at the given index should have [PrimitiveKind.BYTE] kind.
 */
- (int8_t)decodeByteElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeByteElement(descriptor:index:)")));

/**
 * Decodes a 16-bit unicode character value from the underlying input.
 * The resulting value is associated with the [descriptor] element at the given [index].
 * The element at the given index should have [PrimitiveKind.CHAR] kind.
 */
- (unichar)decodeCharElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeCharElement(descriptor:index:)")));

/**
 * Method to decode collection size that may be called before the collection decoding.
 * Collection type includes [Collection], [Map] and [Array] (including primitive arrays).
 * Method can return `-1` if the size is not known in advance, though for [sequential decoding][decodeSequentially]
 * knowing precise size is a mandatory requirement.
 */
- (int32_t)decodeCollectionSizeDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("decodeCollectionSize(descriptor:)")));

/**
 * Decodes a 64-bit IEEE 754 floating point value from the underlying input.
 * The resulting value is associated with the [descriptor] element at the given [index].
 * The element at the given index should have [PrimitiveKind.DOUBLE] kind.
 */
- (double)decodeDoubleElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeDoubleElement(descriptor:index:)")));

/**
 *  Decodes the index of the next element to be decoded.
 *  Index represents a position of the current element in the serial descriptor element that can be found
 *  with [SerialDescriptor.getElementIndex].
 *
 *  If this method returns non-negative index, the caller should call one of the `decode*Element` methods
 *  with a resulting index.
 *  Apart from positive values, this method can return [DECODE_DONE] to indicate that no more elements
 *  are left or [UNKNOWN_NAME] to indicate that symbol with an unknown name was encountered.
 *
 * Example of usage:
 * ```
 * class MyPair(i: Int, d: Double)
 *
 * object MyPairSerializer : KSerializer<MyPair> {
 *     // ... other methods omitted
 *
 *    fun deserialize(decoder: Decoder): MyPair {
 *        val composite = decoder.beginStructure(descriptor)
 *        var i: Int? = null
 *        var d: Double? = null
 *        while (true) {
 *            when (val index = composite.decodeElementIndex(descriptor)) {
 *                0 -> i = composite.decodeIntElement(descriptor, 0)
 *                1 -> d = composite.decodeDoubleElement(descriptor, 1)
 *                DECODE_DONE -> break // Input is over
 *                else -> error("Unexpected index: $index)
 *            }
 *        }
 *        composite.endStructure(descriptor)
 *        require(i != null && d != null)
 *        return MyPair(i, d)
 *    }
 * }
 * ```
 * This example is a rough equivalent of what serialization plugin generates for serializable pair class.
 *
 * The need in such a loop comes from unstructured nature of most serialization formats.
 * For example, JSON for the following input `{"d": 2.0, "i": 1}`, will first read `d` key with index `1`
 * and only after `i` with the index `0`.
 *
 * A potential implementation of this method for JSON format can be the following:
 * ```
 * fun decodeElementIndex(descriptor: SerialDescriptor): Int {
 *     // Ignore arrays
 *     val nextKey: String? = myStringJsonParser.nextKey()
 *     if (nextKey == null) return DECODE_DONE
 *     return descriptor.getElementIndex(nextKey) // getElementIndex can return UNKNOWN_NAME
 * }
 * ```
 *
 * If [decodeSequentially] returns `true`, the caller might skip calling this method.
 */
- (int32_t)decodeElementIndexDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("decodeElementIndex(descriptor:)")));

/**
 * Decodes a 32-bit IEEE 754 floating point value from the underlying input.
 * The resulting value is associated with the [descriptor] element at the given [index].
 * The element at the given index should have [PrimitiveKind.FLOAT] kind.
 */
- (float)decodeFloatElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeFloatElement(descriptor:index:)")));

/**
 * Returns [Decoder] for decoding an underlying type of a value class in an inline manner.
 * Serializable value class is described by the [child descriptor][SerialDescriptor.getElementDescriptor]
 * of given [descriptor] at [index].
 *
 * Namely, for the `@Serializable @JvmInline value class MyInt(val my: Int)`,
 * and `@Serializable class MyData(val myInt: MyInt)` the following sequence is used:
 * ```
 * thisDecoder.decodeInlineElement(MyData.serializer().descriptor, 0).decodeInt()
 * ```
 *
 * This method provides an opportunity for the optimization to avoid boxing of a carried value
 * and its invocation should be equivalent to the following:
 * ```
 * thisDecoder.decodeSerializableElement(MyData.serializer.descriptor, 0, MyInt.serializer())
 * ```
 *
 * Current decoder may return any other instance of [Decoder] class, depending on the provided descriptor.
 * For example, when this function is called on `Json` decoder with descriptor that has
 * `UInt.serializer().descriptor` at the given [index], the returned decoder is able
 * to decode unsigned integers.
 *
 * Note that this function returns [Decoder] instead of the [CompositeDecoder]
 * because value classes always have the single property.
 * Calling [Decoder.beginStructure] on returned instance leads to an unspecified behavior and, in general, is prohibited.
 *
 * @see Decoder.decodeInline
 * @see SerialDescriptor.getElementDescriptor
 */
- (id<KMPWMKotlinx_serialization_coreDecoder>)decodeInlineElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeInlineElement(descriptor:index:)")));

/**
 * Decodes a 32-bit integer value from the underlying input.
 * The resulting value is associated with the [descriptor] element at the given [index].
 * The element at the given index should have [PrimitiveKind.INT] kind.
 */
- (int32_t)decodeIntElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeIntElement(descriptor:index:)")));

/**
 * Decodes a 64-bit integer value from the underlying input.
 * The resulting value is associated with the [descriptor] element at the given [index].
 * The element at the given index should have [PrimitiveKind.LONG] kind.
 */
- (int64_t)decodeLongElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeLongElement(descriptor:index:)")));

/**
 * Decodes nullable value of the type [T] with the given [deserializer].
 *
 * If value at given [index] was already decoded with previous [decodeSerializableElement] call with the same index,
 * [previousValue] would contain a previously decoded value.
 * This parameter can be used to aggregate multiple values of the given property to the only one.
 * Implementation can safely ignore it and return a new value, efficiently using 'the last one wins' strategy,
 * or apply format-specific aggregating strategies, e.g. appending scattered Protobuf lists to a single one.
 *
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (id _Nullable)decodeNullableSerializableElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index deserializer:(id<KMPWMKotlinx_serialization_coreDeserializationStrategy>)deserializer previousValue:(id _Nullable)previousValue __attribute__((swift_name("decodeNullableSerializableElement(descriptor:index:deserializer:previousValue:)")));

/**
 * Checks whether the current decoder supports strictly ordered decoding of the data
 * without calling to [decodeElementIndex].
 * If the method returns `true`, the caller might skip [decodeElementIndex] calls
 * and start invoking `decode*Element` directly, incrementing the index of the element one by one.
 * This method can be called by serializers (either generated or user-defined) as a performance optimization,
 * but there is no guarantee that the method will be ever called. Practically, it means that implementations
 * that may benefit from sequential decoding should also support a regular [decodeElementIndex]-based decoding as well.
 *
 * Example of usage:
 * ```
 * class MyPair(i: Int, d: Double)
 *
 * object MyPairSerializer : KSerializer<MyPair> {
 *     // ... other methods omitted
 *
 *    fun deserialize(decoder: Decoder): MyPair {
 *        val composite = decoder.beginStructure(descriptor)
 *        if (composite.decodeSequentially()) {
 *            val i = composite.decodeIntElement(descriptor, index = 0) // Mind the sequential indexing
 *            val d = composite.decodeIntElement(descriptor, index = 1)
 *            composite.endStructure(descriptor)
 *            return MyPair(i, d)
 *        } else {
 *            // Fallback to `decodeElementIndex` loop, refer to its documentation for details
 *        }
 *    }
 * }
 * ```
 * This example is a rough equivalent of what serialization plugin generates for serializable pair class.
 *
 * Sequential decoding is a performance optimization for formats with strictly ordered schema,
 * usually binary ones. Regular formats such as JSON or ProtoBuf cannot use this optimization,
 * because e.g. in the latter example, the same data can be represented both as
 * `{"i": 1, "d": 1.0}` and `{"d": 1.0, "i": 1}` (thus, unordered).
 *
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
- (BOOL)decodeSequentially __attribute__((swift_name("decodeSequentially()")));

/**
 * Decodes value of the type [T] with the given [deserializer].
 *
 * Implementations of [CompositeDecoder] may use their format-specific deserializers
 * for particular data types, e.g. handle [ByteArray] specifically if format is binary.
 *
 * If value at given [index] was already decoded with previous [decodeSerializableElement] call with the same index,
 * [previousValue] would contain a previously decoded value.
 * This parameter can be used to aggregate multiple values of the given property to the only one.
 * Implementation can safely ignore it and return a new value, effectively using 'the last one wins' strategy,
 * or apply format-specific aggregating strategies, e.g. appending scattered Protobuf lists to a single one.
 */
- (id _Nullable)decodeSerializableElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index deserializer:(id<KMPWMKotlinx_serialization_coreDeserializationStrategy>)deserializer previousValue:(id _Nullable)previousValue __attribute__((swift_name("decodeSerializableElement(descriptor:index:deserializer:previousValue:)")));

/**
 * Decodes a 16-bit short value from the underlying input.
 * The resulting value is associated with the [descriptor] element at the given [index].
 * The element at the given index should have [PrimitiveKind.SHORT] kind.
 */
- (int16_t)decodeShortElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeShortElement(descriptor:index:)")));

/**
 * Decodes a string value from the underlying input.
 * The resulting value is associated with the [descriptor] element at the given [index].
 * The element at the given index should have [PrimitiveKind.STRING] kind.
 */
- (NSString *)decodeStringElementDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor index:(int32_t)index __attribute__((swift_name("decodeStringElement(descriptor:index:)")));

/**
 * Denotes the end of the structure associated with current decoder.
 * For example, composite decoder of JSON format will expect (and parse)
 * a closing bracket in the underlying input.
 */
- (void)endStructureDescriptor:(id<KMPWMKotlinx_serialization_coreSerialDescriptor>)descriptor __attribute__((swift_name("endStructure(descriptor:)")));

/**
 * Context of the current decoding process, including contextual and polymorphic serialization and,
 * potentially, a format-specific configuration.
 */
@property (readonly) KMPWMKotlinx_serialization_coreSerializersModule *serializersModule __attribute__((swift_name("serializersModule")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinNothing")))
@interface KMPWMKotlinNothing : KMPWMBase
@end

__attribute__((swift_name("KotlinCoroutineContextElement")))
@protocol KMPWMKotlinCoroutineContextElement <KMPWMKotlinCoroutineContext>
@required
@property (readonly) id<KMPWMKotlinCoroutineContextKey> key __attribute__((swift_name("key")));
@end

__attribute__((swift_name("KotlinCoroutineContextKey")))
@protocol KMPWMKotlinCoroutineContextKey
@required
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpRequestData")))
@interface KMPWMKtor_client_coreHttpRequestData : KMPWMBase
- (instancetype)initWithUrl:(KMPWMKtor_httpUrl *)url method:(KMPWMKtor_httpHttpMethod *)method headers:(id<KMPWMKtor_httpHeaders>)headers body:(KMPWMKtor_httpOutgoingContent *)body executionContext:(id<KMPWMKotlinx_coroutines_coreJob>)executionContext attributes:(id<KMPWMKtor_utilsAttributes>)attributes __attribute__((swift_name("init(url:method:headers:body:executionContext:attributes:)"))) __attribute__((objc_designated_initializer));
- (id _Nullable)getCapabilityOrNullKey:(id<KMPWMKtor_client_coreHttpClientEngineCapability>)key __attribute__((swift_name("getCapabilityOrNull(key:)")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) id<KMPWMKtor_utilsAttributes> attributes __attribute__((swift_name("attributes")));
@property (readonly) KMPWMKtor_httpOutgoingContent *body __attribute__((swift_name("body")));
@property (readonly) id<KMPWMKotlinx_coroutines_coreJob> executionContext __attribute__((swift_name("executionContext")));
@property (readonly) id<KMPWMKtor_httpHeaders> headers __attribute__((swift_name("headers")));
@property (readonly) KMPWMKtor_httpHttpMethod *method __attribute__((swift_name("method")));
@property (readonly) KMPWMKtor_httpUrl *url __attribute__((swift_name("url")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpResponseData")))
@interface KMPWMKtor_client_coreHttpResponseData : KMPWMBase
- (instancetype)initWithStatusCode:(KMPWMKtor_httpHttpStatusCode *)statusCode requestTime:(KMPWMKtor_utilsGMTDate *)requestTime headers:(id<KMPWMKtor_httpHeaders>)headers version:(KMPWMKtor_httpHttpProtocolVersion *)version body:(id)body callContext:(id<KMPWMKotlinCoroutineContext>)callContext __attribute__((swift_name("init(statusCode:requestTime:headers:version:body:callContext:)"))) __attribute__((objc_designated_initializer));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) id body __attribute__((swift_name("body")));
@property (readonly) id<KMPWMKotlinCoroutineContext> callContext __attribute__((swift_name("callContext")));
@property (readonly) id<KMPWMKtor_httpHeaders> headers __attribute__((swift_name("headers")));
@property (readonly) KMPWMKtor_utilsGMTDate *requestTime __attribute__((swift_name("requestTime")));
@property (readonly) KMPWMKtor_utilsGMTDate *responseTime __attribute__((swift_name("responseTime")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *statusCode __attribute__((swift_name("statusCode")));
@property (readonly) KMPWMKtor_httpHttpProtocolVersion *version __attribute__((swift_name("version")));
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.3")
*/
__attribute__((swift_name("KotlinAbstractCoroutineContextElement")))
@interface KMPWMKotlinAbstractCoroutineContextElement : KMPWMBase <KMPWMKotlinCoroutineContextElement>
- (instancetype)initWithKey:(id<KMPWMKotlinCoroutineContextKey>)key __attribute__((swift_name("init(key:)"))) __attribute__((objc_designated_initializer));
@property (readonly) id<KMPWMKotlinCoroutineContextKey> key __attribute__((swift_name("key")));
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.3")
*/
__attribute__((swift_name("KotlinContinuationInterceptor")))
@protocol KMPWMKotlinContinuationInterceptor <KMPWMKotlinCoroutineContextElement>
@required
- (id<KMPWMKotlinContinuation>)interceptContinuationContinuation:(id<KMPWMKotlinContinuation>)continuation __attribute__((swift_name("interceptContinuation(continuation:)")));
- (void)releaseInterceptedContinuationContinuation:(id<KMPWMKotlinContinuation>)continuation __attribute__((swift_name("releaseInterceptedContinuation(continuation:)")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreCoroutineDispatcher")))
@interface KMPWMKotlinx_coroutines_coreCoroutineDispatcher : KMPWMKotlinAbstractCoroutineContextElement <KMPWMKotlinContinuationInterceptor>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (instancetype)initWithKey:(id<KMPWMKotlinCoroutineContextKey>)key __attribute__((swift_name("init(key:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) KMPWMKotlinx_coroutines_coreCoroutineDispatcherKey *companion __attribute__((swift_name("companion")));
- (void)dispatchContext:(id<KMPWMKotlinCoroutineContext>)context block:(id<KMPWMKotlinx_coroutines_coreRunnable>)block __attribute__((swift_name("dispatch(context:block:)")));

/**
 * @note annotations
 *   kotlinx.coroutines.InternalCoroutinesApi
*/
- (void)dispatchYieldContext:(id<KMPWMKotlinCoroutineContext>)context block:(id<KMPWMKotlinx_coroutines_coreRunnable>)block __attribute__((swift_name("dispatchYield(context:block:)")));
- (id<KMPWMKotlinContinuation>)interceptContinuationContinuation:(id<KMPWMKotlinContinuation>)continuation __attribute__((swift_name("interceptContinuation(continuation:)")));
- (BOOL)isDispatchNeededContext:(id<KMPWMKotlinCoroutineContext>)context __attribute__((swift_name("isDispatchNeeded(context:)")));
- (KMPWMKotlinx_coroutines_coreCoroutineDispatcher *)limitedParallelismParallelism:(int32_t)parallelism name:(NSString * _Nullable)name __attribute__((swift_name("limitedParallelism(parallelism:name:)")));
- (KMPWMKotlinx_coroutines_coreCoroutineDispatcher *)plusOther:(KMPWMKotlinx_coroutines_coreCoroutineDispatcher *)other __attribute__((swift_name("plus(other:)"))) __attribute__((unavailable("Operator '+' on two CoroutineDispatcher objects is meaningless. CoroutineDispatcher is a coroutine context element and `+` is a set-sum operator for coroutine contexts. The dispatcher to the right of `+` just replaces the dispatcher to the left.")));
- (void)releaseInterceptedContinuationContinuation:(id<KMPWMKotlinContinuation>)continuation __attribute__((swift_name("releaseInterceptedContinuation(continuation:)")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreProxyConfig")))
@interface KMPWMKtor_client_coreProxyConfig : KMPWMBase
- (instancetype)initWithUrl:(KMPWMKtor_httpUrl *)url __attribute__((swift_name("init(url:)"))) __attribute__((objc_designated_initializer));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) KMPWMKtor_httpUrl *url __attribute__((swift_name("url")));
@end

__attribute__((swift_name("Ktor_client_coreHttpClientPlugin")))
@protocol KMPWMKtor_client_coreHttpClientPlugin
@required
- (void)installPlugin:(id)plugin scope:(KMPWMKtor_client_coreHttpClient *)scope __attribute__((swift_name("install(plugin:scope:)")));
- (id)prepareBlock:(void (^)(id))block __attribute__((swift_name("prepare(block:)")));
@property (readonly) KMPWMKtor_utilsAttributeKey<id> *key __attribute__((swift_name("key")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_utilsAttributeKey")))
@interface KMPWMKtor_utilsAttributeKey<T> : KMPWMBase
- (instancetype)initWithName:(NSString *)name __attribute__((swift_name("init(name:)"))) __attribute__((objc_designated_initializer));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@end

__attribute__((swift_name("Ktor_eventsEventDefinition")))
@interface KMPWMKtor_eventsEventDefinition<T> : KMPWMBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreDisposableHandle")))
@protocol KMPWMKotlinx_coroutines_coreDisposableHandle
@required
- (void)dispose __attribute__((swift_name("dispose()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_utilsPipelinePhase")))
@interface KMPWMKtor_utilsPipelinePhase : KMPWMBase
- (instancetype)initWithName:(NSString *)name __attribute__((swift_name("init(name:)"))) __attribute__((objc_designated_initializer));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@end

__attribute__((swift_name("KotlinFunction")))
@protocol KMPWMKotlinFunction
@required
@end

__attribute__((swift_name("KotlinSuspendFunction2")))
@protocol KMPWMKotlinSuspendFunction2 <KMPWMKotlinFunction>
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)invokeP1:(id _Nullable)p1 p2:(id _Nullable)p2 completionHandler:(void (^)(id _Nullable_result, NSError * _Nullable))completionHandler __attribute__((swift_name("invoke(p1:p2:completionHandler:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpReceivePipeline.Phases")))
@interface KMPWMKtor_client_coreHttpReceivePipelinePhases : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)phases __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_client_coreHttpReceivePipelinePhases *shared __attribute__((swift_name("shared")));
@property (readonly) KMPWMKtor_utilsPipelinePhase *After __attribute__((swift_name("After")));
@property (readonly) KMPWMKtor_utilsPipelinePhase *Before __attribute__((swift_name("Before")));
@property (readonly) KMPWMKtor_utilsPipelinePhase *State __attribute__((swift_name("State")));
@end

__attribute__((swift_name("Ktor_httpHttpMessage")))
@protocol KMPWMKtor_httpHttpMessage
@required
@property (readonly) id<KMPWMKtor_httpHeaders> headers __attribute__((swift_name("headers")));
@end

__attribute__((swift_name("Ktor_client_coreHttpResponse")))
@interface KMPWMKtor_client_coreHttpResponse : KMPWMBase <KMPWMKtor_httpHttpMessage, KMPWMKotlinx_coroutines_coreCoroutineScope>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) KMPWMKtor_client_coreHttpClientCall *call __attribute__((swift_name("call")));
@property (readonly) id<KMPWMKtor_ioByteReadChannel> content __attribute__((swift_name("content")));
@property (readonly) KMPWMKtor_utilsGMTDate *requestTime __attribute__((swift_name("requestTime")));
@property (readonly) KMPWMKtor_utilsGMTDate *responseTime __attribute__((swift_name("responseTime")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *status __attribute__((swift_name("status")));
@property (readonly) KMPWMKtor_httpHttpProtocolVersion *version __attribute__((swift_name("version")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinUnit")))
@interface KMPWMKotlinUnit : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)unit __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKotlinUnit *shared __attribute__((swift_name("shared")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpRequestPipeline.Phases")))
@interface KMPWMKtor_client_coreHttpRequestPipelinePhases : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)phases __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_client_coreHttpRequestPipelinePhases *shared __attribute__((swift_name("shared")));
@property (readonly) KMPWMKtor_utilsPipelinePhase *Before __attribute__((swift_name("Before")));
@property (readonly) KMPWMKtor_utilsPipelinePhase *Render __attribute__((swift_name("Render")));
@property (readonly) KMPWMKtor_utilsPipelinePhase *Send __attribute__((swift_name("Send")));
@property (readonly) KMPWMKtor_utilsPipelinePhase *State __attribute__((swift_name("State")));
@property (readonly) KMPWMKtor_utilsPipelinePhase *Transform __attribute__((swift_name("Transform")));
@end

__attribute__((swift_name("Ktor_httpHttpMessageBuilder")))
@protocol KMPWMKtor_httpHttpMessageBuilder
@required
@property (readonly) KMPWMKtor_httpHeadersBuilder *headers __attribute__((swift_name("headers")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpRequestBuilder")))
@interface KMPWMKtor_client_coreHttpRequestBuilder : KMPWMBase <KMPWMKtor_httpHttpMessageBuilder>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) KMPWMKtor_client_coreHttpRequestBuilderCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMKtor_client_coreHttpRequestData *)build __attribute__((swift_name("build()")));
- (id _Nullable)getCapabilityOrNullKey:(id<KMPWMKtor_client_coreHttpClientEngineCapability>)key __attribute__((swift_name("getCapabilityOrNull(key:)")));
- (void)setAttributesBlock:(void (^)(id<KMPWMKtor_utilsAttributes>))block __attribute__((swift_name("setAttributes(block:)")));
- (void)setCapabilityKey:(id<KMPWMKtor_client_coreHttpClientEngineCapability>)key capability:(id)capability __attribute__((swift_name("setCapability(key:capability:)")));
- (KMPWMKtor_client_coreHttpRequestBuilder *)takeFromBuilder:(KMPWMKtor_client_coreHttpRequestBuilder *)builder __attribute__((swift_name("takeFrom(builder:)")));
- (KMPWMKtor_client_coreHttpRequestBuilder *)takeFromWithExecutionContextBuilder:(KMPWMKtor_client_coreHttpRequestBuilder *)builder __attribute__((swift_name("takeFromWithExecutionContext(builder:)")));
- (void)urlBlock:(void (^)(KMPWMKtor_httpURLBuilder *, KMPWMKtor_httpURLBuilder *))block __attribute__((swift_name("url(block:)")));
@property (readonly) id<KMPWMKtor_utilsAttributes> attributes __attribute__((swift_name("attributes")));
@property id body __attribute__((swift_name("body")));
@property KMPWMKtor_utilsTypeInfo * _Nullable bodyType __attribute__((swift_name("bodyType")));
@property (readonly) id<KMPWMKotlinx_coroutines_coreJob> executionContext __attribute__((swift_name("executionContext")));
@property (readonly) KMPWMKtor_httpHeadersBuilder *headers __attribute__((swift_name("headers")));
@property KMPWMKtor_httpHttpMethod *method __attribute__((swift_name("method")));
@property (readonly) KMPWMKtor_httpURLBuilder *url __attribute__((swift_name("url")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpResponsePipeline.Phases")))
@interface KMPWMKtor_client_coreHttpResponsePipelinePhases : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)phases __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_client_coreHttpResponsePipelinePhases *shared __attribute__((swift_name("shared")));
@property (readonly) KMPWMKtor_utilsPipelinePhase *After __attribute__((swift_name("After")));
@property (readonly) KMPWMKtor_utilsPipelinePhase *Parse __attribute__((swift_name("Parse")));
@property (readonly) KMPWMKtor_utilsPipelinePhase *Receive __attribute__((swift_name("Receive")));
@property (readonly) KMPWMKtor_utilsPipelinePhase *State __attribute__((swift_name("State")));
@property (readonly) KMPWMKtor_utilsPipelinePhase *Transform __attribute__((swift_name("Transform")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpResponseContainer")))
@interface KMPWMKtor_client_coreHttpResponseContainer : KMPWMBase
- (instancetype)initWithExpectedType:(KMPWMKtor_utilsTypeInfo *)expectedType response:(id)response __attribute__((swift_name("init(expectedType:response:)"))) __attribute__((objc_designated_initializer));
- (KMPWMKtor_client_coreHttpResponseContainer *)doCopyExpectedType:(KMPWMKtor_utilsTypeInfo *)expectedType response:(id)response __attribute__((swift_name("doCopy(expectedType:response:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) KMPWMKtor_utilsTypeInfo *expectedType __attribute__((swift_name("expectedType")));
@property (readonly) id response __attribute__((swift_name("response")));
@end

__attribute__((swift_name("Ktor_client_coreHttpClientCall")))
@interface KMPWMKtor_client_coreHttpClientCall : KMPWMBase <KMPWMKotlinx_coroutines_coreCoroutineScope>
- (instancetype)initWithClient:(KMPWMKtor_client_coreHttpClient *)client __attribute__((swift_name("init(client:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithClient:(KMPWMKtor_client_coreHttpClient *)client requestData:(KMPWMKtor_client_coreHttpRequestData *)requestData responseData:(KMPWMKtor_client_coreHttpResponseData *)responseData __attribute__((swift_name("init(client:requestData:responseData:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMKtor_client_coreHttpClientCallCompanion *companion __attribute__((swift_name("companion")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)bodyInfo:(KMPWMKtor_utilsTypeInfo *)info completionHandler:(void (^)(id _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("body(info:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)bodyNullableInfo:(KMPWMKtor_utilsTypeInfo *)info completionHandler:(void (^)(id _Nullable_result, NSError * _Nullable))completionHandler __attribute__((swift_name("bodyNullable(info:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (void)getResponseContentWithCompletionHandler:(void (^)(id<KMPWMKtor_ioByteReadChannel> _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("getResponseContent(completionHandler:)")));
- (NSString *)description __attribute__((swift_name("description()")));

/**
 * @note This property has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
@property (readonly) BOOL allowDoubleReceive __attribute__((swift_name("allowDoubleReceive")));
@property (readonly) id<KMPWMKtor_utilsAttributes> attributes __attribute__((swift_name("attributes")));
@property (readonly) KMPWMKtor_client_coreHttpClient *client __attribute__((swift_name("client")));
@property (readonly) id<KMPWMKotlinCoroutineContext> coroutineContext __attribute__((swift_name("coroutineContext")));
@property id<KMPWMKtor_client_coreHttpRequest> request __attribute__((swift_name("request")));
@property KMPWMKtor_client_coreHttpResponse *response __attribute__((swift_name("response")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpSendPipeline.Phases")))
@interface KMPWMKtor_client_coreHttpSendPipelinePhases : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)phases __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_client_coreHttpSendPipelinePhases *shared __attribute__((swift_name("shared")));
@property (readonly) KMPWMKtor_utilsPipelinePhase *Before __attribute__((swift_name("Before")));
@property (readonly) KMPWMKtor_utilsPipelinePhase *Engine __attribute__((swift_name("Engine")));
@property (readonly) KMPWMKtor_utilsPipelinePhase *Monitoring __attribute__((swift_name("Monitoring")));
@property (readonly) KMPWMKtor_utilsPipelinePhase *Receive __attribute__((swift_name("Receive")));
@property (readonly) KMPWMKtor_utilsPipelinePhase *State __attribute__((swift_name("State")));
@end

__attribute__((swift_name("OkioTimeout")))
@interface KMPWMOkioTimeout : KMPWMBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) KMPWMOkioTimeoutCompanion *companion __attribute__((swift_name("companion")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("OkioBuffer")))
@interface KMPWMOkioBuffer : KMPWMBase <KMPWMOkioBufferedSource, KMPWMOkioBufferedSink>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
- (void)clear __attribute__((swift_name("clear()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)closeAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("close_()")));
- (int64_t)completeSegmentByteCount __attribute__((swift_name("completeSegmentByteCount()")));
- (KMPWMOkioBuffer *)doCopy __attribute__((swift_name("doCopy()")));
- (KMPWMOkioBuffer *)doCopyToOut:(KMPWMOkioBuffer *)out offset:(int64_t)offset __attribute__((swift_name("doCopyTo(out:offset:)")));
- (KMPWMOkioBuffer *)doCopyToOut:(KMPWMOkioBuffer *)out offset:(int64_t)offset byteCount:(int64_t)byteCount __attribute__((swift_name("doCopyTo(out:offset:byteCount:)")));
- (KMPWMOkioBuffer *)emit __attribute__((swift_name("emit()")));
- (KMPWMOkioBuffer *)emitCompleteSegments __attribute__((swift_name("emitCompleteSegments()")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (BOOL)exhausted __attribute__((swift_name("exhausted()")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)flushAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("flush()")));
- (int8_t)getPos:(int64_t)pos __attribute__((swift_name("get(pos:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));

/** Returns the 160-bit SHA-1 HMAC of this buffer.  */
- (KMPWMOkioByteString *)hmacSha1Key:(KMPWMOkioByteString *)key __attribute__((swift_name("hmacSha1(key:)")));

/** Returns the 256-bit SHA-256 HMAC of this buffer.  */
- (KMPWMOkioByteString *)hmacSha256Key:(KMPWMOkioByteString *)key __attribute__((swift_name("hmacSha256(key:)")));

/** Returns the 512-bit SHA-512 HMAC of this buffer.  */
- (KMPWMOkioByteString *)hmacSha512Key:(KMPWMOkioByteString *)key __attribute__((swift_name("hmacSha512(key:)")));
- (int64_t)indexOfB:(int8_t)b __attribute__((swift_name("indexOf(b:)")));
- (int64_t)indexOfBytes:(KMPWMOkioByteString *)bytes __attribute__((swift_name("indexOf(bytes:)")));
- (int64_t)indexOfB:(int8_t)b fromIndex:(int64_t)fromIndex __attribute__((swift_name("indexOf(b:fromIndex:)")));
- (int64_t)indexOfBytes:(KMPWMOkioByteString *)bytes fromIndex:(int64_t)fromIndex __attribute__((swift_name("indexOf(bytes:fromIndex:)")));
- (int64_t)indexOfB:(int8_t)b fromIndex:(int64_t)fromIndex toIndex:(int64_t)toIndex __attribute__((swift_name("indexOf(b:fromIndex:toIndex:)")));
- (int64_t)indexOfBytes:(KMPWMOkioByteString *)bytes fromIndex:(int64_t)fromIndex toIndex:(int64_t)toIndex __attribute__((swift_name("indexOf(bytes:fromIndex:toIndex:)")));
- (int64_t)indexOfElementTargetBytes:(KMPWMOkioByteString *)targetBytes __attribute__((swift_name("indexOfElement(targetBytes:)")));
- (int64_t)indexOfElementTargetBytes:(KMPWMOkioByteString *)targetBytes fromIndex:(int64_t)fromIndex __attribute__((swift_name("indexOfElement(targetBytes:fromIndex:)")));
- (KMPWMOkioByteString *)md5 __attribute__((swift_name("md5()")));
- (id<KMPWMOkioBufferedSource>)peek __attribute__((swift_name("peek()")));
- (BOOL)rangeEqualsOffset:(int64_t)offset bytes:(KMPWMOkioByteString *)bytes __attribute__((swift_name("rangeEquals(offset:bytes:)")));
- (BOOL)rangeEqualsOffset:(int64_t)offset bytes:(KMPWMOkioByteString *)bytes bytesOffset:(int32_t)bytesOffset byteCount:(int32_t)byteCount __attribute__((swift_name("rangeEquals(offset:bytes:bytesOffset:byteCount:)")));
- (int32_t)readSink:(KMPWMKotlinByteArray *)sink __attribute__((swift_name("read(sink:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (int64_t)readSink:(KMPWMOkioBuffer *)sink byteCount:(int64_t)byteCount error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("read(sink:byteCount:)"))) __attribute__((swift_error(nonnull_error)));
- (int32_t)readSink:(KMPWMKotlinByteArray *)sink offset:(int32_t)offset byteCount:(int32_t)byteCount __attribute__((swift_name("read(sink:offset:byteCount:)")));
- (int64_t)readAllSink:(id<KMPWMOkioSink>)sink __attribute__((swift_name("readAll(sink:)")));
- (KMPWMOkioBufferUnsafeCursor *)readAndWriteUnsafeUnsafeCursor:(KMPWMOkioBufferUnsafeCursor *)unsafeCursor __attribute__((swift_name("readAndWriteUnsafe(unsafeCursor:)")));
- (int8_t)readByte __attribute__((swift_name("readByte()")));
- (KMPWMKotlinByteArray *)readByteArray __attribute__((swift_name("readByteArray()")));
- (KMPWMKotlinByteArray *)readByteArrayByteCount:(int64_t)byteCount __attribute__((swift_name("readByteArray(byteCount:)")));
- (KMPWMOkioByteString *)readByteString __attribute__((swift_name("readByteString()")));
- (KMPWMOkioByteString *)readByteStringByteCount:(int64_t)byteCount __attribute__((swift_name("readByteString(byteCount:)")));
- (int64_t)readDecimalLong __attribute__((swift_name("readDecimalLong()")));
- (void)readFullySink:(KMPWMKotlinByteArray *)sink __attribute__((swift_name("readFully(sink:)")));
- (void)readFullySink:(KMPWMOkioBuffer *)sink byteCount:(int64_t)byteCount __attribute__((swift_name("readFully(sink:byteCount:)")));
- (int64_t)readHexadecimalUnsignedLong __attribute__((swift_name("readHexadecimalUnsignedLong()")));
- (int32_t)readInt __attribute__((swift_name("readInt()")));
- (int32_t)readIntLe __attribute__((swift_name("readIntLe()")));
- (int64_t)readLong __attribute__((swift_name("readLong()")));
- (int64_t)readLongLe __attribute__((swift_name("readLongLe()")));
- (int16_t)readShort __attribute__((swift_name("readShort()")));
- (int16_t)readShortLe __attribute__((swift_name("readShortLe()")));
- (KMPWMOkioBufferUnsafeCursor *)readUnsafeUnsafeCursor:(KMPWMOkioBufferUnsafeCursor *)unsafeCursor __attribute__((swift_name("readUnsafe(unsafeCursor:)")));
- (NSString *)readUtf8 __attribute__((swift_name("readUtf8()")));
- (NSString *)readUtf8ByteCount:(int64_t)byteCount __attribute__((swift_name("readUtf8(byteCount:)")));
- (int32_t)readUtf8CodePoint __attribute__((swift_name("readUtf8CodePoint()")));
- (NSString * _Nullable)readUtf8Line __attribute__((swift_name("readUtf8Line()")));
- (NSString *)readUtf8LineStrict __attribute__((swift_name("readUtf8LineStrict()")));
- (NSString *)readUtf8LineStrictLimit:(int64_t)limit __attribute__((swift_name("readUtf8LineStrict(limit:)")));
- (BOOL)requestByteCount:(int64_t)byteCount __attribute__((swift_name("request(byteCount:)")));
- (void)requireByteCount:(int64_t)byteCount __attribute__((swift_name("require(byteCount:)")));
- (int32_t)selectOptions:(NSArray<KMPWMOkioByteString *> *)options __attribute__((swift_name("select(options:)")));
- (id _Nullable)selectOptions_:(NSArray<id> *)options __attribute__((swift_name("select(options_:)")));
- (KMPWMOkioByteString *)sha1 __attribute__((swift_name("sha1()")));
- (KMPWMOkioByteString *)sha256 __attribute__((swift_name("sha256()")));
- (KMPWMOkioByteString *)sha512 __attribute__((swift_name("sha512()")));
- (void)skipByteCount:(int64_t)byteCount __attribute__((swift_name("skip(byteCount:)")));
- (KMPWMOkioByteString *)snapshot __attribute__((swift_name("snapshot()")));
- (KMPWMOkioByteString *)snapshotByteCount:(int32_t)byteCount __attribute__((swift_name("snapshot(byteCount:)")));
- (KMPWMOkioTimeout *)timeout __attribute__((swift_name("timeout()")));

/**
 * Returns a human-readable string that describes the contents of this buffer. Typically this
 * is a string like `[text=Hello]` or `[hex=0000ffff]`.
 */
- (NSString *)description __attribute__((swift_name("description()")));
- (KMPWMOkioBuffer *)writeSource:(KMPWMKotlinByteArray *)source __attribute__((swift_name("write(source:)")));
- (KMPWMOkioBuffer *)writeByteString:(KMPWMOkioByteString *)byteString __attribute__((swift_name("write(byteString:)")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)writeSource:(KMPWMOkioBuffer *)source byteCount:(int64_t)byteCount error:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("write(source:byteCount:)")));
- (KMPWMOkioBuffer *)writeSource:(id<KMPWMOkioSource>)source byteCount:(int64_t)byteCount __attribute__((swift_name("write(source:byteCount_:)")));
- (KMPWMOkioBuffer *)writeSource:(KMPWMKotlinByteArray *)source offset:(int32_t)offset byteCount:(int32_t)byteCount __attribute__((swift_name("write(source:offset:byteCount:)")));
- (KMPWMOkioBuffer *)writeByteString:(KMPWMOkioByteString *)byteString offset:(int32_t)offset byteCount:(int32_t)byteCount __attribute__((swift_name("write(byteString:offset:byteCount:)")));
- (int64_t)writeAllSource:(id<KMPWMOkioSource>)source __attribute__((swift_name("writeAll(source:)")));
- (KMPWMOkioBuffer *)writeByteB:(int32_t)b __attribute__((swift_name("writeByte(b:)")));
- (KMPWMOkioBuffer *)writeDecimalLongV:(int64_t)v __attribute__((swift_name("writeDecimalLong(v:)")));
- (KMPWMOkioBuffer *)writeHexadecimalUnsignedLongV:(int64_t)v __attribute__((swift_name("writeHexadecimalUnsignedLong(v:)")));
- (KMPWMOkioBuffer *)writeIntI:(int32_t)i __attribute__((swift_name("writeInt(i:)")));
- (KMPWMOkioBuffer *)writeIntLeI:(int32_t)i __attribute__((swift_name("writeIntLe(i:)")));
- (KMPWMOkioBuffer *)writeLongV:(int64_t)v __attribute__((swift_name("writeLong(v:)")));
- (KMPWMOkioBuffer *)writeLongLeV:(int64_t)v __attribute__((swift_name("writeLongLe(v:)")));
- (KMPWMOkioBuffer *)writeShortS:(int32_t)s __attribute__((swift_name("writeShort(s:)")));
- (KMPWMOkioBuffer *)writeShortLeS:(int32_t)s __attribute__((swift_name("writeShortLe(s:)")));
- (KMPWMOkioBuffer *)writeUtf8String:(NSString *)string __attribute__((swift_name("writeUtf8(string:)")));
- (KMPWMOkioBuffer *)writeUtf8String:(NSString *)string beginIndex:(int32_t)beginIndex endIndex:(int32_t)endIndex __attribute__((swift_name("writeUtf8(string:beginIndex:endIndex:)")));
- (KMPWMOkioBuffer *)writeUtf8CodePointCodePoint:(int32_t)codePoint __attribute__((swift_name("writeUtf8CodePoint(codePoint:)")));
@property (readonly) KMPWMOkioBuffer *buffer __attribute__((swift_name("buffer")));
@property (readonly) int64_t size __attribute__((swift_name("size")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("OkioPath.Companion")))
@interface KMPWMOkioPathCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMOkioPathCompanion *shared __attribute__((swift_name("shared")));
- (KMPWMOkioPath *)toPath:(NSString *)receiver normalize:(BOOL)normalize __attribute__((swift_name("toPath(_:normalize:)")));
@property (readonly) NSString *DIRECTORY_SEPARATOR __attribute__((swift_name("DIRECTORY_SEPARATOR")));
@end

__attribute__((swift_name("OkioByteString")))
@interface KMPWMOkioByteString : KMPWMBase <KMPWMKotlinComparable>
@property (class, readonly, getter=companion) KMPWMOkioByteStringCompanion *companion __attribute__((swift_name("companion")));
- (NSString *)base64 __attribute__((swift_name("base64()")));
- (NSString *)base64Url __attribute__((swift_name("base64Url()")));
- (int32_t)compareToOther:(KMPWMOkioByteString *)other __attribute__((swift_name("compareTo(other:)")));
- (void)doCopyIntoOffset:(int32_t)offset target:(KMPWMKotlinByteArray *)target targetOffset:(int32_t)targetOffset byteCount:(int32_t)byteCount __attribute__((swift_name("doCopyInto(offset:target:targetOffset:byteCount:)")));
- (BOOL)endsWithSuffix:(KMPWMKotlinByteArray *)suffix __attribute__((swift_name("endsWith(suffix:)")));
- (BOOL)endsWithSuffix_:(KMPWMOkioByteString *)suffix __attribute__((swift_name("endsWith(suffix_:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (int8_t)getIndex:(int32_t)index __attribute__((swift_name("get(index:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)hex __attribute__((swift_name("hex()")));

/** Returns the 160-bit SHA-1 HMAC of this byte string.  */
- (KMPWMOkioByteString *)hmacSha1Key:(KMPWMOkioByteString *)key __attribute__((swift_name("hmacSha1(key:)")));

/** Returns the 256-bit SHA-256 HMAC of this byte string.  */
- (KMPWMOkioByteString *)hmacSha256Key:(KMPWMOkioByteString *)key __attribute__((swift_name("hmacSha256(key:)")));

/** Returns the 512-bit SHA-512 HMAC of this byte string.  */
- (KMPWMOkioByteString *)hmacSha512Key:(KMPWMOkioByteString *)key __attribute__((swift_name("hmacSha512(key:)")));
- (int32_t)indexOfOther:(KMPWMKotlinByteArray *)other fromIndex:(int32_t)fromIndex __attribute__((swift_name("indexOf(other:fromIndex:)")));
- (int32_t)indexOfOther:(KMPWMOkioByteString *)other fromIndex_:(int32_t)fromIndex __attribute__((swift_name("indexOf(other:fromIndex_:)")));
- (int32_t)lastIndexOfOther:(KMPWMKotlinByteArray *)other fromIndex:(int32_t)fromIndex __attribute__((swift_name("lastIndexOf(other:fromIndex:)")));
- (int32_t)lastIndexOfOther:(KMPWMOkioByteString *)other fromIndex_:(int32_t)fromIndex __attribute__((swift_name("lastIndexOf(other:fromIndex_:)")));
- (KMPWMOkioByteString *)md5 __attribute__((swift_name("md5()")));
- (BOOL)rangeEqualsOffset:(int32_t)offset other:(KMPWMKotlinByteArray *)other otherOffset:(int32_t)otherOffset byteCount:(int32_t)byteCount __attribute__((swift_name("rangeEquals(offset:other:otherOffset:byteCount:)")));
- (BOOL)rangeEqualsOffset:(int32_t)offset other:(KMPWMOkioByteString *)other otherOffset:(int32_t)otherOffset byteCount_:(int32_t)byteCount __attribute__((swift_name("rangeEquals(offset:other:otherOffset:byteCount_:)")));
- (KMPWMOkioByteString *)sha1 __attribute__((swift_name("sha1()")));
- (KMPWMOkioByteString *)sha256 __attribute__((swift_name("sha256()")));
- (KMPWMOkioByteString *)sha512 __attribute__((swift_name("sha512()")));
- (BOOL)startsWithPrefix:(KMPWMKotlinByteArray *)prefix __attribute__((swift_name("startsWith(prefix:)")));
- (BOOL)startsWithPrefix_:(KMPWMOkioByteString *)prefix __attribute__((swift_name("startsWith(prefix_:)")));
- (KMPWMOkioByteString *)substringBeginIndex:(int32_t)beginIndex endIndex:(int32_t)endIndex __attribute__((swift_name("substring(beginIndex:endIndex:)")));
- (KMPWMOkioByteString *)toAsciiLowercase __attribute__((swift_name("toAsciiLowercase()")));
- (KMPWMOkioByteString *)toAsciiUppercase __attribute__((swift_name("toAsciiUppercase()")));
- (KMPWMKotlinByteArray *)toByteArray __attribute__((swift_name("toByteArray()")));

/**
 * Returns a human-readable string that describes the contents of this byte string. Typically this
 * is a string like `[text=Hello]` or `[hex=0000ffff]`.
 */
- (NSString *)description __attribute__((swift_name("description()")));
- (NSString *)utf8 __attribute__((swift_name("utf8()")));
@property (readonly) int32_t size __attribute__((swift_name("size")));
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

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("OkioLock")))
@interface KMPWMOkioLock : KMPWMBase
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));
@property (class, readonly, getter=companion) KMPWMOkioLockCompanion *companion __attribute__((swift_name("companion")));
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
 * [SerializersModuleCollector] can introspect and accumulate content of any [SerializersModule] via [SerializersModule.dumpTo],
 * using a visitor-like pattern: [contextual] and [polymorphic] functions are invoked for each registered serializer.
 *
 * ### Not stable for inheritance
 *
 * `SerializersModuleCollector` interface is not stable for inheritance in 3rd party libraries, as new methods
 * might be added to this interface or contracts of the existing methods can be changed.
 *
 * @note annotations
 *   kotlinx.serialization.ExperimentalSerializationApi
*/
__attribute__((swift_name("Kotlinx_serialization_coreSerializersModuleCollector")))
@protocol KMPWMKotlinx_serialization_coreSerializersModuleCollector
@required

/**
 * Accept a provider, associated with generic [kClass] for contextual serialization.
 */
- (void)contextualKClass:(id<KMPWMKotlinKClass>)kClass provider:(id<KMPWMKotlinx_serialization_coreKSerializer> (^)(NSArray<id<KMPWMKotlinx_serialization_coreKSerializer>> *typeArgumentsSerializers))provider __attribute__((swift_name("contextual(kClass:provider:)")));

/**
 * Accept a serializer, associated with [kClass] for contextual serialization.
 */
- (void)contextualKClass:(id<KMPWMKotlinKClass>)kClass serializer:(id<KMPWMKotlinx_serialization_coreKSerializer>)serializer __attribute__((swift_name("contextual(kClass:serializer:)")));

/**
 * Accept a serializer, associated with [actualClass] for polymorphic serialization.
 */
- (void)polymorphicBaseClass:(id<KMPWMKotlinKClass>)baseClass actualClass:(id<KMPWMKotlinKClass>)actualClass actualSerializer:(id<KMPWMKotlinx_serialization_coreKSerializer>)actualSerializer __attribute__((swift_name("polymorphic(baseClass:actualClass:actualSerializer:)")));

/**
 * Accept a default deserializer provider, associated with the [baseClass] for polymorphic deserialization.
 *
 * This function affect only deserialization process. To avoid confusion, it was deprecated and replaced with [polymorphicDefaultDeserializer].
 * To affect serialization process, use [SerializersModuleCollector.polymorphicDefaultSerializer].
 *
 * [defaultDeserializerProvider] is invoked when no polymorphic serializers associated with the `className`
 * in the scope of [baseClass] were found. `className` could be `null` for formats that support nullable class discriminators
 * (currently only `Json` with `useArrayPolymorphism` set to `false`).
 *
 * [defaultDeserializerProvider] can be stateful and lookup a serializer for the missing type dynamically.
 *
 * @see SerializersModuleCollector.polymorphicDefaultDeserializer
 * @see SerializersModuleCollector.polymorphicDefaultSerializer
 */
- (void)polymorphicDefaultBaseClass:(id<KMPWMKotlinKClass>)baseClass defaultDeserializerProvider:(id<KMPWMKotlinx_serialization_coreDeserializationStrategy> _Nullable (^)(NSString * _Nullable className))defaultDeserializerProvider __attribute__((swift_name("polymorphicDefault(baseClass:defaultDeserializerProvider:)"))) __attribute__((deprecated("Deprecated in favor of function with more precise name: polymorphicDefaultDeserializer")));

/**
 * Accept a default deserializer provider, associated with the [baseClass] for polymorphic deserialization.
 * [defaultDeserializerProvider] is invoked when no polymorphic serializers associated with the `className`
 * in the scope of [baseClass] were found. `className` could be `null` for formats that support nullable class discriminators
 * (currently only `Json` with `useArrayPolymorphism` set to `false`).
 *
 * Default deserializers provider affects only deserialization process. Serializers are accepted in the
 * [SerializersModuleCollector.polymorphicDefaultSerializer] method.
 *
 * [defaultDeserializerProvider] can be stateful and lookup a serializer for the missing type dynamically.
 */
- (void)polymorphicDefaultDeserializerBaseClass:(id<KMPWMKotlinKClass>)baseClass defaultDeserializerProvider:(id<KMPWMKotlinx_serialization_coreDeserializationStrategy> _Nullable (^)(NSString * _Nullable className))defaultDeserializerProvider __attribute__((swift_name("polymorphicDefaultDeserializer(baseClass:defaultDeserializerProvider:)")));

/**
 * Accept a default serializer provider, associated with the [baseClass] for polymorphic serialization.
 * [defaultSerializerProvider] is invoked when no polymorphic serializers for `value` in the scope of [baseClass] were found.
 *
 * Default serializers provider affects only serialization process. Deserializers are accepted in the
 * [SerializersModuleCollector.polymorphicDefaultDeserializer] method.
 *
 * [defaultSerializerProvider] can be stateful and lookup a serializer for the missing type dynamically.
 */
- (void)polymorphicDefaultSerializerBaseClass:(id<KMPWMKotlinKClass>)baseClass defaultSerializerProvider:(id<KMPWMKotlinx_serialization_coreSerializationStrategy> _Nullable (^)(id value))defaultSerializerProvider __attribute__((swift_name("polymorphicDefaultSerializer(baseClass:defaultSerializerProvider:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpUrl")))
@interface KMPWMKtor_httpUrl : KMPWMBase
@property (class, readonly, getter=companion) KMPWMKtor_httpUrlCompanion *companion __attribute__((swift_name("companion")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *encodedFragment __attribute__((swift_name("encodedFragment")));
@property (readonly) NSString * _Nullable encodedPassword __attribute__((swift_name("encodedPassword")));
@property (readonly) NSString *encodedPath __attribute__((swift_name("encodedPath")));
@property (readonly) NSString *encodedPathAndQuery __attribute__((swift_name("encodedPathAndQuery")));
@property (readonly) NSString *encodedQuery __attribute__((swift_name("encodedQuery")));
@property (readonly) NSString * _Nullable encodedUser __attribute__((swift_name("encodedUser")));
@property (readonly) NSString *fragment __attribute__((swift_name("fragment")));
@property (readonly) NSString *host __attribute__((swift_name("host")));
@property (readonly) id<KMPWMKtor_httpParameters> parameters __attribute__((swift_name("parameters")));
@property (readonly) NSString * _Nullable password __attribute__((swift_name("password")));
@property (readonly) NSArray<NSString *> *pathSegments __attribute__((swift_name("pathSegments")));
@property (readonly) int32_t port __attribute__((swift_name("port")));
@property (readonly) KMPWMKtor_httpURLProtocol *protocol __attribute__((swift_name("protocol")));
@property (readonly) int32_t specifiedPort __attribute__((swift_name("specifiedPort")));
@property (readonly) BOOL trailingQuery __attribute__((swift_name("trailingQuery")));
@property (readonly) NSString * _Nullable user __attribute__((swift_name("user")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpHttpMethod")))
@interface KMPWMKtor_httpHttpMethod : KMPWMBase
- (instancetype)initWithValue:(NSString *)value __attribute__((swift_name("init(value:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMKtor_httpHttpMethodCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMKtor_httpHttpMethod *)doCopyValue:(NSString *)value __attribute__((swift_name("doCopy(value:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *value __attribute__((swift_name("value")));
@end

__attribute__((swift_name("Ktor_utilsStringValues")))
@protocol KMPWMKtor_utilsStringValues
@required
- (BOOL)containsName:(NSString *)name __attribute__((swift_name("contains(name:)")));
- (BOOL)containsName:(NSString *)name value:(NSString *)value __attribute__((swift_name("contains(name:value:)")));
- (NSSet<id<KMPWMKotlinMapEntry>> *)entries __attribute__((swift_name("entries()")));
- (void)forEachBody:(void (^)(NSString *, NSArray<NSString *> *))body __attribute__((swift_name("forEach(body:)")));
- (NSString * _Nullable)getName:(NSString *)name __attribute__((swift_name("get(name:)")));
- (NSArray<NSString *> * _Nullable)getAllName:(NSString *)name __attribute__((swift_name("getAll(name:)")));
- (BOOL)isEmpty_ __attribute__((swift_name("isEmpty()")));
- (NSSet<NSString *> *)names __attribute__((swift_name("names()")));
@property (readonly) BOOL caseInsensitiveName __attribute__((swift_name("caseInsensitiveName")));
@end

__attribute__((swift_name("Ktor_httpHeaders")))
@protocol KMPWMKtor_httpHeaders <KMPWMKtor_utilsStringValues>
@required
@end

__attribute__((swift_name("Ktor_httpOutgoingContent")))
@interface KMPWMKtor_httpOutgoingContent : KMPWMBase
- (id _Nullable)getPropertyKey:(KMPWMKtor_utilsAttributeKey<id> *)key __attribute__((swift_name("getProperty(key:)")));
- (void)setPropertyKey:(KMPWMKtor_utilsAttributeKey<id> *)key value:(id _Nullable)value __attribute__((swift_name("setProperty(key:value:)")));
- (id<KMPWMKtor_httpHeaders> _Nullable)trailers __attribute__((swift_name("trailers()")));
@property (readonly) KMPWMLong * _Nullable contentLength __attribute__((swift_name("contentLength")));
@property (readonly) KMPWMKtor_httpContentType * _Nullable contentType __attribute__((swift_name("contentType")));
@property (readonly) id<KMPWMKtor_httpHeaders> headers __attribute__((swift_name("headers")));
@property (readonly) KMPWMKtor_httpHttpStatusCode * _Nullable status __attribute__((swift_name("status")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreJob")))
@protocol KMPWMKotlinx_coroutines_coreJob <KMPWMKotlinCoroutineContextElement>
@required

/**
 * @note annotations
 *   kotlinx.coroutines.InternalCoroutinesApi
*/
- (id<KMPWMKotlinx_coroutines_coreChildHandle>)attachChildChild:(id<KMPWMKotlinx_coroutines_coreChildJob>)child __attribute__((swift_name("attachChild(child:)")));
- (void)cancelCause:(KMPWMKotlinCancellationException * _Nullable)cause __attribute__((swift_name("cancel(cause:)")));

/**
 * @note annotations
 *   kotlinx.coroutines.InternalCoroutinesApi
*/
- (KMPWMKotlinCancellationException *)getCancellationException __attribute__((swift_name("getCancellationException()")));
- (id<KMPWMKotlinx_coroutines_coreDisposableHandle>)invokeOnCompletionHandler:(void (^)(KMPWMKotlinThrowable * _Nullable cause))handler __attribute__((swift_name("invokeOnCompletion(handler:)")));

/**
 * @note annotations
 *   kotlinx.coroutines.InternalCoroutinesApi
*/
- (id<KMPWMKotlinx_coroutines_coreDisposableHandle>)invokeOnCompletionOnCancelling:(BOOL)onCancelling invokeImmediately:(BOOL)invokeImmediately handler:(void (^)(KMPWMKotlinThrowable * _Nullable cause))handler __attribute__((swift_name("invokeOnCompletion(onCancelling:invokeImmediately:handler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)joinWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("join(completionHandler:)")));
- (id<KMPWMKotlinx_coroutines_coreJob>)plusOther_:(id<KMPWMKotlinx_coroutines_coreJob>)other __attribute__((swift_name("plus(other_:)"))) __attribute__((unavailable("Operator '+' on two Job objects is meaningless. Job is a coroutine context element and `+` is a set-sum operator for coroutine contexts. The job to the right of `+` just replaces the job the left of `+`.")));
- (BOOL)start __attribute__((swift_name("start()")));
@property (readonly) id<KMPWMKotlinSequence> children __attribute__((swift_name("children")));
@property (readonly) BOOL isActive __attribute__((swift_name("isActive")));
@property (readonly) BOOL isCancelled __attribute__((swift_name("isCancelled")));
@property (readonly) BOOL isCompleted __attribute__((swift_name("isCompleted")));
@property (readonly) id<KMPWMKotlinx_coroutines_coreSelectClause0> onJoin __attribute__((swift_name("onJoin")));

/**
 * @note annotations
 *   kotlinx.coroutines.ExperimentalCoroutinesApi
*/
@property (readonly) id<KMPWMKotlinx_coroutines_coreJob> _Nullable parent __attribute__((swift_name("parent")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpHttpStatusCode")))
@interface KMPWMKtor_httpHttpStatusCode : KMPWMBase <KMPWMKotlinComparable>
- (instancetype)initWithValue:(int32_t)value description:(NSString *)description __attribute__((swift_name("init(value:description:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMKtor_httpHttpStatusCodeCompanion *companion __attribute__((swift_name("companion")));
- (int32_t)compareToOther:(KMPWMKtor_httpHttpStatusCode *)other __attribute__((swift_name("compareTo(other:)")));
- (KMPWMKtor_httpHttpStatusCode *)doCopyValue:(int32_t)value description:(NSString *)description __attribute__((swift_name("doCopy(value:description:)")));
- (KMPWMKtor_httpHttpStatusCode *)descriptionValue:(NSString *)value __attribute__((swift_name("description(value:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) NSString *description_ __attribute__((swift_name("description_")));
@property (readonly) int32_t value __attribute__((swift_name("value")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_utilsGMTDate")))
@interface KMPWMKtor_utilsGMTDate : KMPWMBase <KMPWMKotlinComparable>
@property (class, readonly, getter=companion) KMPWMKtor_utilsGMTDateCompanion *companion __attribute__((swift_name("companion")));
- (int32_t)compareToOther:(KMPWMKtor_utilsGMTDate *)other __attribute__((swift_name("compareTo(other:)")));
- (KMPWMKtor_utilsGMTDate *)doCopySeconds:(int32_t)seconds minutes:(int32_t)minutes hours:(int32_t)hours dayOfWeek:(KMPWMKtor_utilsWeekDay *)dayOfWeek dayOfMonth:(int32_t)dayOfMonth dayOfYear:(int32_t)dayOfYear month:(KMPWMKtor_utilsMonth *)month year:(int32_t)year timestamp:(int64_t)timestamp __attribute__((swift_name("doCopy(seconds:minutes:hours:dayOfWeek:dayOfMonth:dayOfYear:month:year:timestamp:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int32_t dayOfMonth __attribute__((swift_name("dayOfMonth")));
@property (readonly) KMPWMKtor_utilsWeekDay *dayOfWeek __attribute__((swift_name("dayOfWeek")));
@property (readonly) int32_t dayOfYear __attribute__((swift_name("dayOfYear")));
@property (readonly) int32_t hours __attribute__((swift_name("hours")));
@property (readonly) int32_t minutes __attribute__((swift_name("minutes")));
@property (readonly) KMPWMKtor_utilsMonth *month __attribute__((swift_name("month")));
@property (readonly) int32_t seconds __attribute__((swift_name("seconds")));
@property (readonly) int64_t timestamp __attribute__((swift_name("timestamp")));
@property (readonly) int32_t year __attribute__((swift_name("year")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpHttpProtocolVersion")))
@interface KMPWMKtor_httpHttpProtocolVersion : KMPWMBase
- (instancetype)initWithName:(NSString *)name major:(int32_t)major minor:(int32_t)minor __attribute__((swift_name("init(name:major:minor:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMKtor_httpHttpProtocolVersionCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMKtor_httpHttpProtocolVersion *)doCopyName:(NSString *)name major:(int32_t)major minor:(int32_t)minor __attribute__((swift_name("doCopy(name:major:minor:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int32_t major __attribute__((swift_name("major")));
@property (readonly) int32_t minor __attribute__((swift_name("minor")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.3")
*/
__attribute__((swift_name("KotlinContinuation")))
@protocol KMPWMKotlinContinuation
@required
- (void)resumeWithResult:(id _Nullable)result __attribute__((swift_name("resumeWith(result:)")));
@property (readonly) id<KMPWMKotlinCoroutineContext> context __attribute__((swift_name("context")));
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.3")
 *   kotlin.ExperimentalStdlibApi
*/
__attribute__((swift_name("KotlinAbstractCoroutineContextKey")))
@interface KMPWMKotlinAbstractCoroutineContextKey<B, E> : KMPWMBase <KMPWMKotlinCoroutineContextKey>
- (instancetype)initWithBaseKey:(id<KMPWMKotlinCoroutineContextKey>)baseKey safeCast:(E _Nullable (^)(id<KMPWMKotlinCoroutineContextElement> element))safeCast __attribute__((swift_name("init(baseKey:safeCast:)"))) __attribute__((objc_designated_initializer));
@end


/**
 * @note annotations
 *   kotlin.ExperimentalStdlibApi
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Kotlinx_coroutines_coreCoroutineDispatcher.Key")))
@interface KMPWMKotlinx_coroutines_coreCoroutineDispatcherKey : KMPWMKotlinAbstractCoroutineContextKey<id<KMPWMKotlinContinuationInterceptor>, KMPWMKotlinx_coroutines_coreCoroutineDispatcher *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithBaseKey:(id<KMPWMKotlinCoroutineContextKey>)baseKey safeCast:(id<KMPWMKotlinCoroutineContextElement> _Nullable (^)(id<KMPWMKotlinCoroutineContextElement> element))safeCast __attribute__((swift_name("init(baseKey:safeCast:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
+ (instancetype)key __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKotlinx_coroutines_coreCoroutineDispatcherKey *shared __attribute__((swift_name("shared")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreRunnable")))
@protocol KMPWMKotlinx_coroutines_coreRunnable
@required
- (void)run __attribute__((swift_name("run()")));
@end

__attribute__((swift_name("Ktor_ioByteReadChannel")))
@protocol KMPWMKtor_ioByteReadChannel
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)awaitContentWithCompletionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("awaitContent(completionHandler:)")));
- (BOOL)cancelCause_:(KMPWMKotlinThrowable * _Nullable)cause __attribute__((swift_name("cancel(cause_:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)discardMax:(int64_t)max completionHandler:(void (^)(KMPWMLong * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("discard(max:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)peekToDestination:(KMPWMKtor_ioMemory *)destination destinationOffset:(int64_t)destinationOffset offset:(int64_t)offset min:(int64_t)min max:(int64_t)max completionHandler:(void (^)(KMPWMLong * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("peekTo(destination:destinationOffset:offset:min:max:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readAvailableDst:(KMPWMKtor_ioChunkBuffer *)dst completionHandler:(void (^)(KMPWMInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readAvailable(dst:completionHandler:)")));
- (int32_t)readAvailableMin:(int32_t)min block:(void (^)(KMPWMKtor_ioBuffer *))block __attribute__((swift_name("readAvailable(min:block:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readAvailableDst:(KMPWMKotlinByteArray *)dst offset:(int32_t)offset length:(int32_t)length completionHandler:(void (^)(KMPWMInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readAvailable(dst:offset:length:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readAvailableDst:(void *)dst offset:(int32_t)offset length:(int32_t)length completionHandler_:(void (^)(KMPWMInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readAvailable(dst:offset:length:completionHandler_:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readAvailableDst:(void *)dst offset:(int64_t)offset length:(int64_t)length completionHandler__:(void (^)(KMPWMInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readAvailable(dst:offset:length:completionHandler__:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readBooleanWithCompletionHandler:(void (^)(KMPWMBoolean * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readBoolean(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readByteWithCompletionHandler:(void (^)(KMPWMByte * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readByte(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readDoubleWithCompletionHandler:(void (^)(KMPWMDouble * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readDouble(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readFloatWithCompletionHandler:(void (^)(KMPWMFloat * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readFloat(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readFullyDst:(KMPWMKtor_ioChunkBuffer *)dst n:(int32_t)n completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("readFully(dst:n:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readFullyDst:(KMPWMKotlinByteArray *)dst offset:(int32_t)offset length:(int32_t)length completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("readFully(dst:offset:length:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readFullyDst:(void *)dst offset:(int32_t)offset length:(int32_t)length completionHandler_:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("readFully(dst:offset:length:completionHandler_:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readFullyDst:(void *)dst offset:(int64_t)offset length:(int64_t)length completionHandler__:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("readFully(dst:offset:length:completionHandler__:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readIntWithCompletionHandler:(void (^)(KMPWMInt * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readInt(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readLongWithCompletionHandler:(void (^)(KMPWMLong * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readLong(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readPacketSize:(int32_t)size completionHandler:(void (^)(KMPWMKtor_ioByteReadPacket * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readPacket(size:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readRemainingLimit:(int64_t)limit completionHandler:(void (^)(KMPWMKtor_ioByteReadPacket * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readRemaining(limit:completionHandler:)")));
- (void)readSessionConsumer:(void (^)(id<KMPWMKtor_ioReadSession>))consumer __attribute__((swift_name("readSession(consumer:)"))) __attribute__((deprecated("Use read { } instead.")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readShortWithCompletionHandler:(void (^)(KMPWMShort * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readShort(completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readSuspendableSessionConsumer:(id<KMPWMKotlinSuspendFunction1>)consumer completionHandler:(void (^)(NSError * _Nullable))completionHandler __attribute__((swift_name("readSuspendableSession(consumer:completionHandler:)"))) __attribute__((deprecated("Use read { } instead.")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readUTF8LineLimit:(int32_t)limit completionHandler:(void (^)(NSString * _Nullable_result, NSError * _Nullable))completionHandler __attribute__((swift_name("readUTF8Line(limit:completionHandler:)")));

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)readUTF8LineToOut:(id<KMPWMKotlinAppendable>)out limit:(int32_t)limit completionHandler:(void (^)(KMPWMBoolean * _Nullable, NSError * _Nullable))completionHandler __attribute__((swift_name("readUTF8LineTo(out:limit:completionHandler:)")));
@property (readonly) int32_t availableForRead __attribute__((swift_name("availableForRead")));
@property (readonly) KMPWMKotlinThrowable * _Nullable closedCause __attribute__((swift_name("closedCause")));
@property (readonly) BOOL isClosedForRead __attribute__((swift_name("isClosedForRead")));
@property (readonly) BOOL isClosedForWrite __attribute__((swift_name("isClosedForWrite")));
@property (readonly) int64_t totalBytesRead __attribute__((swift_name("totalBytesRead")));
@end

__attribute__((swift_name("Ktor_utilsStringValuesBuilder")))
@protocol KMPWMKtor_utilsStringValuesBuilder
@required
- (void)appendName:(NSString *)name value:(NSString *)value __attribute__((swift_name("append(name:value:)")));
- (void)appendAllStringValues:(id<KMPWMKtor_utilsStringValues>)stringValues __attribute__((swift_name("appendAll(stringValues:)")));
- (void)appendAllName:(NSString *)name values:(id)values __attribute__((swift_name("appendAll(name:values:)")));
- (void)appendMissingStringValues:(id<KMPWMKtor_utilsStringValues>)stringValues __attribute__((swift_name("appendMissing(stringValues:)")));
- (void)appendMissingName:(NSString *)name values:(id)values __attribute__((swift_name("appendMissing(name:values:)")));
- (id<KMPWMKtor_utilsStringValues>)build __attribute__((swift_name("build()")));
- (void)clear __attribute__((swift_name("clear()")));
- (BOOL)containsName:(NSString *)name __attribute__((swift_name("contains(name:)")));
- (BOOL)containsName:(NSString *)name value:(NSString *)value __attribute__((swift_name("contains(name:value:)")));
- (NSSet<id<KMPWMKotlinMapEntry>> *)entries __attribute__((swift_name("entries()")));
- (NSString * _Nullable)getName:(NSString *)name __attribute__((swift_name("get(name:)")));
- (NSArray<NSString *> * _Nullable)getAllName:(NSString *)name __attribute__((swift_name("getAll(name:)")));
- (BOOL)isEmpty_ __attribute__((swift_name("isEmpty()")));
- (NSSet<NSString *> *)names __attribute__((swift_name("names()")));
- (void)removeName:(NSString *)name __attribute__((swift_name("remove(name:)")));
- (BOOL)removeName:(NSString *)name value:(NSString *)value __attribute__((swift_name("remove(name:value:)")));
- (void)removeKeysWithNoEntries __attribute__((swift_name("removeKeysWithNoEntries()")));
- (void)setName:(NSString *)name value:(NSString *)value __attribute__((swift_name("set(name:value:)")));
@property (readonly) BOOL caseInsensitiveName __attribute__((swift_name("caseInsensitiveName")));
@end

__attribute__((swift_name("Ktor_utilsStringValuesBuilderImpl")))
@interface KMPWMKtor_utilsStringValuesBuilderImpl : KMPWMBase <KMPWMKtor_utilsStringValuesBuilder>
- (instancetype)initWithCaseInsensitiveName:(BOOL)caseInsensitiveName size:(int32_t)size __attribute__((swift_name("init(caseInsensitiveName:size:)"))) __attribute__((objc_designated_initializer));
- (void)appendName:(NSString *)name value:(NSString *)value __attribute__((swift_name("append(name:value:)")));
- (void)appendAllStringValues:(id<KMPWMKtor_utilsStringValues>)stringValues __attribute__((swift_name("appendAll(stringValues:)")));
- (void)appendAllName:(NSString *)name values:(id)values __attribute__((swift_name("appendAll(name:values:)")));
- (void)appendMissingStringValues:(id<KMPWMKtor_utilsStringValues>)stringValues __attribute__((swift_name("appendMissing(stringValues:)")));
- (void)appendMissingName:(NSString *)name values:(id)values __attribute__((swift_name("appendMissing(name:values:)")));
- (id<KMPWMKtor_utilsStringValues>)build __attribute__((swift_name("build()")));
- (void)clear __attribute__((swift_name("clear()")));
- (BOOL)containsName:(NSString *)name __attribute__((swift_name("contains(name:)")));
- (BOOL)containsName:(NSString *)name value:(NSString *)value __attribute__((swift_name("contains(name:value:)")));
- (NSSet<id<KMPWMKotlinMapEntry>> *)entries __attribute__((swift_name("entries()")));
- (NSString * _Nullable)getName:(NSString *)name __attribute__((swift_name("get(name:)")));
- (NSArray<NSString *> * _Nullable)getAllName:(NSString *)name __attribute__((swift_name("getAll(name:)")));
- (BOOL)isEmpty_ __attribute__((swift_name("isEmpty()")));
- (NSSet<NSString *> *)names __attribute__((swift_name("names()")));
- (void)removeName:(NSString *)name __attribute__((swift_name("remove(name:)")));
- (BOOL)removeName:(NSString *)name value:(NSString *)value __attribute__((swift_name("remove(name:value:)")));
- (void)removeKeysWithNoEntries __attribute__((swift_name("removeKeysWithNoEntries()")));
- (void)setName:(NSString *)name value:(NSString *)value __attribute__((swift_name("set(name:value:)")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (void)validateNameName:(NSString *)name __attribute__((swift_name("validateName(name:)")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (void)validateValueValue:(NSString *)value __attribute__((swift_name("validateValue(value:)")));
@property (readonly) BOOL caseInsensitiveName __attribute__((swift_name("caseInsensitiveName")));

/**
 * @note This property has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
@property (readonly) KMPWMMutableDictionary<NSString *, NSMutableArray<NSString *> *> *values __attribute__((swift_name("values")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpHeadersBuilder")))
@interface KMPWMKtor_httpHeadersBuilder : KMPWMKtor_utilsStringValuesBuilderImpl
- (instancetype)initWithSize:(int32_t)size __attribute__((swift_name("init(size:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithCaseInsensitiveName:(BOOL)caseInsensitiveName size:(int32_t)size __attribute__((swift_name("init(caseInsensitiveName:size:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
- (id<KMPWMKtor_httpHeaders>)build __attribute__((swift_name("build()")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (void)validateNameName:(NSString *)name __attribute__((swift_name("validateName(name:)")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (void)validateValueValue:(NSString *)value __attribute__((swift_name("validateValue(value:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpRequestBuilder.Companion")))
@interface KMPWMKtor_client_coreHttpRequestBuilderCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_client_coreHttpRequestBuilderCompanion *shared __attribute__((swift_name("shared")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpURLBuilder")))
@interface KMPWMKtor_httpURLBuilder : KMPWMBase
- (instancetype)initWithProtocol:(KMPWMKtor_httpURLProtocol *)protocol host:(NSString *)host port:(int32_t)port user:(NSString * _Nullable)user password:(NSString * _Nullable)password pathSegments:(NSArray<NSString *> *)pathSegments parameters:(id<KMPWMKtor_httpParameters>)parameters fragment:(NSString *)fragment trailingQuery:(BOOL)trailingQuery __attribute__((swift_name("init(protocol:host:port:user:password:pathSegments:parameters:fragment:trailingQuery:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMKtor_httpURLBuilderCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMKtor_httpUrl *)build __attribute__((swift_name("build()")));
- (NSString *)buildString __attribute__((swift_name("buildString()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property NSString *encodedFragment __attribute__((swift_name("encodedFragment")));
@property id<KMPWMKtor_httpParametersBuilder> encodedParameters __attribute__((swift_name("encodedParameters")));
@property NSString * _Nullable encodedPassword __attribute__((swift_name("encodedPassword")));
@property NSArray<NSString *> *encodedPathSegments __attribute__((swift_name("encodedPathSegments")));
@property NSString * _Nullable encodedUser __attribute__((swift_name("encodedUser")));
@property NSString *fragment __attribute__((swift_name("fragment")));
@property NSString *host __attribute__((swift_name("host")));
@property (readonly) id<KMPWMKtor_httpParametersBuilder> parameters __attribute__((swift_name("parameters")));
@property NSString * _Nullable password __attribute__((swift_name("password")));
@property NSArray<NSString *> *pathSegments __attribute__((swift_name("pathSegments")));
@property int32_t port __attribute__((swift_name("port")));
@property KMPWMKtor_httpURLProtocol *protocol __attribute__((swift_name("protocol")));
@property BOOL trailingQuery __attribute__((swift_name("trailingQuery")));
@property NSString * _Nullable user __attribute__((swift_name("user")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_utilsTypeInfo")))
@interface KMPWMKtor_utilsTypeInfo : KMPWMBase
- (instancetype)initWithType:(id<KMPWMKotlinKClass>)type reifiedType:(id<KMPWMKotlinKType>)reifiedType kotlinType:(id<KMPWMKotlinKType> _Nullable)kotlinType __attribute__((swift_name("init(type:reifiedType:kotlinType:)"))) __attribute__((objc_designated_initializer));
- (KMPWMKtor_utilsTypeInfo *)doCopyType:(id<KMPWMKotlinKClass>)type reifiedType:(id<KMPWMKotlinKType>)reifiedType kotlinType:(id<KMPWMKotlinKType> _Nullable)kotlinType __attribute__((swift_name("doCopy(type:reifiedType:kotlinType:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) id<KMPWMKotlinKType> _Nullable kotlinType __attribute__((swift_name("kotlinType")));
@property (readonly) id<KMPWMKotlinKType> reifiedType __attribute__((swift_name("reifiedType")));
@property (readonly) id<KMPWMKotlinKClass> type __attribute__((swift_name("type")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_client_coreHttpClientCall.Companion")))
@interface KMPWMKtor_client_coreHttpClientCallCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_client_coreHttpClientCallCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) KMPWMKtor_utilsAttributeKey<id> *CustomResponse __attribute__((swift_name("CustomResponse"))) __attribute__((unavailable("This is going to be removed. Please file a ticket with clarification why and what for do you need it.")));
@end

__attribute__((swift_name("Ktor_client_coreHttpRequest")))
@protocol KMPWMKtor_client_coreHttpRequest <KMPWMKtor_httpHttpMessage, KMPWMKotlinx_coroutines_coreCoroutineScope>
@required
@property (readonly) id<KMPWMKtor_utilsAttributes> attributes __attribute__((swift_name("attributes")));
@property (readonly) KMPWMKtor_client_coreHttpClientCall *call __attribute__((swift_name("call")));
@property (readonly) KMPWMKtor_httpOutgoingContent *content __attribute__((swift_name("content")));
@property (readonly) KMPWMKtor_httpHttpMethod *method __attribute__((swift_name("method")));
@property (readonly) KMPWMKtor_httpUrl *url __attribute__((swift_name("url")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("OkioTimeout.Companion")))
@interface KMPWMOkioTimeoutCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMOkioTimeoutCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) KMPWMOkioTimeout *NONE __attribute__((swift_name("NONE")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("OkioBuffer.UnsafeCursor")))
@interface KMPWMOkioBufferUnsafeCursor : KMPWMBase <KMPWMOkioCloseable>
- (instancetype)init __attribute__((swift_name("init()"))) __attribute__((objc_designated_initializer));
+ (instancetype)new __attribute__((availability(swift, unavailable, message="use object initializers instead")));

/**
 * @note This method converts instances of IOException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (BOOL)closeAndReturnError:(NSError * _Nullable * _Nullable)error __attribute__((swift_name("close_()")));
- (int64_t)expandBufferMinByteCount:(int32_t)minByteCount __attribute__((swift_name("expandBuffer(minByteCount:)")));
- (int32_t)next __attribute__((swift_name("next()")));
- (int64_t)resizeBufferNewSize:(int64_t)newSize __attribute__((swift_name("resizeBuffer(newSize:)")));
- (int32_t)seekOffset:(int64_t)offset __attribute__((swift_name("seek(offset:)")));
@property KMPWMOkioBuffer * _Nullable buffer __attribute__((swift_name("buffer")));
@property KMPWMKotlinByteArray * _Nullable data __attribute__((swift_name("data")));
@property int32_t end __attribute__((swift_name("end")));
@property int64_t offset __attribute__((swift_name("offset")));
@property BOOL readWrite __attribute__((swift_name("readWrite")));
@property int32_t start __attribute__((swift_name("start")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("OkioByteString.Companion")))
@interface KMPWMOkioByteStringCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMOkioByteStringCompanion *shared __attribute__((swift_name("shared")));
- (KMPWMOkioByteString * _Nullable)decodeBase64:(NSString *)receiver __attribute__((swift_name("decodeBase64(_:)")));
- (KMPWMOkioByteString *)decodeHex:(NSString *)receiver __attribute__((swift_name("decodeHex(_:)")));
- (KMPWMOkioByteString *)encodeUtf8:(NSString *)receiver __attribute__((swift_name("encodeUtf8(_:)")));
- (KMPWMOkioByteString *)ofData:(KMPWMKotlinByteArray *)data __attribute__((swift_name("of(data:)")));
- (KMPWMOkioByteString *)toByteString:(NSData *)receiver __attribute__((swift_name("toByteString(_:)")));
- (KMPWMOkioByteString *)toByteString:(KMPWMKotlinByteArray *)receiver offset:(int32_t)offset byteCount:(int32_t)byteCount __attribute__((swift_name("toByteString(_:offset:byteCount:)")));
@property (readonly) KMPWMOkioByteString *EMPTY __attribute__((swift_name("EMPTY")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("OkioLock.Companion")))
@interface KMPWMOkioLockCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMOkioLockCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) KMPWMOkioLock *instance __attribute__((swift_name("instance")));
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

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpUrl.Companion")))
@interface KMPWMKtor_httpUrlCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_httpUrlCompanion *shared __attribute__((swift_name("shared")));
@end

__attribute__((swift_name("Ktor_httpParameters")))
@protocol KMPWMKtor_httpParameters <KMPWMKtor_utilsStringValues>
@required
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpURLProtocol")))
@interface KMPWMKtor_httpURLProtocol : KMPWMBase
- (instancetype)initWithName:(NSString *)name defaultPort:(int32_t)defaultPort __attribute__((swift_name("init(name:defaultPort:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMKtor_httpURLProtocolCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMKtor_httpURLProtocol *)doCopyName:(NSString *)name defaultPort:(int32_t)defaultPort __attribute__((swift_name("doCopy(name:defaultPort:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) int32_t defaultPort __attribute__((swift_name("defaultPort")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpHttpMethod.Companion")))
@interface KMPWMKtor_httpHttpMethodCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_httpHttpMethodCompanion *shared __attribute__((swift_name("shared")));
- (KMPWMKtor_httpHttpMethod *)parseMethod:(NSString *)method __attribute__((swift_name("parse(method:)")));
@property (readonly) NSArray<KMPWMKtor_httpHttpMethod *> *DefaultMethods __attribute__((swift_name("DefaultMethods")));
@property (readonly) KMPWMKtor_httpHttpMethod *Delete __attribute__((swift_name("Delete")));
@property (readonly) KMPWMKtor_httpHttpMethod *Get __attribute__((swift_name("Get")));
@property (readonly) KMPWMKtor_httpHttpMethod *Head __attribute__((swift_name("Head")));
@property (readonly) KMPWMKtor_httpHttpMethod *Options __attribute__((swift_name("Options")));
@property (readonly) KMPWMKtor_httpHttpMethod *Patch __attribute__((swift_name("Patch")));
@property (readonly) KMPWMKtor_httpHttpMethod *Post __attribute__((swift_name("Post")));
@property (readonly) KMPWMKtor_httpHttpMethod *Put __attribute__((swift_name("Put")));
@end

__attribute__((swift_name("KotlinMapEntry")))
@protocol KMPWMKotlinMapEntry
@required
@property (readonly) id _Nullable key __attribute__((swift_name("key")));
@property (readonly) id _Nullable value __attribute__((swift_name("value")));
@end

__attribute__((swift_name("Ktor_httpHeaderValueWithParameters")))
@interface KMPWMKtor_httpHeaderValueWithParameters : KMPWMBase
- (instancetype)initWithContent:(NSString *)content parameters:(NSArray<KMPWMKtor_httpHeaderValueParam *> *)parameters __attribute__((swift_name("init(content:parameters:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMKtor_httpHeaderValueWithParametersCompanion *companion __attribute__((swift_name("companion")));
- (NSString * _Nullable)parameterName:(NSString *)name __attribute__((swift_name("parameter(name:)")));
- (NSString *)description __attribute__((swift_name("description()")));

/**
 * @note This property has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
@property (readonly) NSString *content __attribute__((swift_name("content")));
@property (readonly) NSArray<KMPWMKtor_httpHeaderValueParam *> *parameters __attribute__((swift_name("parameters")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpContentType")))
@interface KMPWMKtor_httpContentType : KMPWMKtor_httpHeaderValueWithParameters
- (instancetype)initWithContentType:(NSString *)contentType contentSubtype:(NSString *)contentSubtype parameters:(NSArray<KMPWMKtor_httpHeaderValueParam *> *)parameters __attribute__((swift_name("init(contentType:contentSubtype:parameters:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithContent:(NSString *)content parameters:(NSArray<KMPWMKtor_httpHeaderValueParam *> *)parameters __attribute__((swift_name("init(content:parameters:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) KMPWMKtor_httpContentTypeCompanion *companion __attribute__((swift_name("companion")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (BOOL)matchPattern:(KMPWMKtor_httpContentType *)pattern __attribute__((swift_name("match(pattern:)")));
- (BOOL)matchPattern_:(NSString *)pattern __attribute__((swift_name("match(pattern_:)")));
- (KMPWMKtor_httpContentType *)withParameterName:(NSString *)name value:(NSString *)value __attribute__((swift_name("withParameter(name:value:)")));
- (KMPWMKtor_httpContentType *)withoutParameters __attribute__((swift_name("withoutParameters()")));
@property (readonly) NSString *contentSubtype __attribute__((swift_name("contentSubtype")));
@property (readonly) NSString *contentType __attribute__((swift_name("contentType")));
@end


/**
 * @note annotations
 *   kotlinx.coroutines.InternalCoroutinesApi
*/
__attribute__((swift_name("Kotlinx_coroutines_coreChildHandle")))
@protocol KMPWMKotlinx_coroutines_coreChildHandle <KMPWMKotlinx_coroutines_coreDisposableHandle>
@required

/**
 * @note annotations
 *   kotlinx.coroutines.InternalCoroutinesApi
*/
- (BOOL)childCancelledCause:(KMPWMKotlinThrowable *)cause __attribute__((swift_name("childCancelled(cause:)")));

/**
 * @note annotations
 *   kotlinx.coroutines.InternalCoroutinesApi
*/
@property (readonly) id<KMPWMKotlinx_coroutines_coreJob> _Nullable parent __attribute__((swift_name("parent")));
@end


/**
 * @note annotations
 *   kotlinx.coroutines.InternalCoroutinesApi
*/
__attribute__((swift_name("Kotlinx_coroutines_coreChildJob")))
@protocol KMPWMKotlinx_coroutines_coreChildJob <KMPWMKotlinx_coroutines_coreJob>
@required

/**
 * @note annotations
 *   kotlinx.coroutines.InternalCoroutinesApi
*/
- (void)parentCancelledParentJob:(id<KMPWMKotlinx_coroutines_coreParentJob>)parentJob __attribute__((swift_name("parentCancelled(parentJob:)")));
@end


/**
 * @note annotations
 *   kotlinx.coroutines.InternalCoroutinesApi
*/
__attribute__((swift_name("Kotlinx_coroutines_coreSelectClause")))
@protocol KMPWMKotlinx_coroutines_coreSelectClause
@required
@property (readonly) id clauseObject __attribute__((swift_name("clauseObject")));
@property (readonly) KMPWMKotlinUnit *(^(^ _Nullable onCancellationConstructor)(id<KMPWMKotlinx_coroutines_coreSelectInstance> select, id _Nullable param, id _Nullable internalResult))(KMPWMKotlinThrowable *, id _Nullable, id<KMPWMKotlinCoroutineContext>) __attribute__((swift_name("onCancellationConstructor")));
@property (readonly) id _Nullable (^processResFunc)(id clauseObject, id _Nullable param, id _Nullable clauseResult) __attribute__((swift_name("processResFunc")));
@property (readonly) void (^regFunc)(id clauseObject, id<KMPWMKotlinx_coroutines_coreSelectInstance> select, id _Nullable param) __attribute__((swift_name("regFunc")));
@end

__attribute__((swift_name("Kotlinx_coroutines_coreSelectClause0")))
@protocol KMPWMKotlinx_coroutines_coreSelectClause0 <KMPWMKotlinx_coroutines_coreSelectClause>
@required
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpHttpStatusCode.Companion")))
@interface KMPWMKtor_httpHttpStatusCodeCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_httpHttpStatusCodeCompanion *shared __attribute__((swift_name("shared")));
- (KMPWMKtor_httpHttpStatusCode *)fromValueValue:(int32_t)value __attribute__((swift_name("fromValue(value:)")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *Accepted __attribute__((swift_name("Accepted")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *BadGateway __attribute__((swift_name("BadGateway")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *BadRequest __attribute__((swift_name("BadRequest")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *Conflict __attribute__((swift_name("Conflict")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *Continue __attribute__((swift_name("Continue")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *Created __attribute__((swift_name("Created")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *ExpectationFailed __attribute__((swift_name("ExpectationFailed")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *FailedDependency __attribute__((swift_name("FailedDependency")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *Forbidden __attribute__((swift_name("Forbidden")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *Found __attribute__((swift_name("Found")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *GatewayTimeout __attribute__((swift_name("GatewayTimeout")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *Gone __attribute__((swift_name("Gone")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *InsufficientStorage __attribute__((swift_name("InsufficientStorage")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *InternalServerError __attribute__((swift_name("InternalServerError")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *LengthRequired __attribute__((swift_name("LengthRequired")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *Locked __attribute__((swift_name("Locked")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *MethodNotAllowed __attribute__((swift_name("MethodNotAllowed")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *MovedPermanently __attribute__((swift_name("MovedPermanently")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *MultiStatus __attribute__((swift_name("MultiStatus")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *MultipleChoices __attribute__((swift_name("MultipleChoices")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *NoContent __attribute__((swift_name("NoContent")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *NonAuthoritativeInformation __attribute__((swift_name("NonAuthoritativeInformation")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *NotAcceptable __attribute__((swift_name("NotAcceptable")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *NotFound __attribute__((swift_name("NotFound")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *NotImplemented __attribute__((swift_name("NotImplemented")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *NotModified __attribute__((swift_name("NotModified")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *OK __attribute__((swift_name("OK")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *PartialContent __attribute__((swift_name("PartialContent")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *PayloadTooLarge __attribute__((swift_name("PayloadTooLarge")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *PaymentRequired __attribute__((swift_name("PaymentRequired")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *PermanentRedirect __attribute__((swift_name("PermanentRedirect")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *PreconditionFailed __attribute__((swift_name("PreconditionFailed")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *Processing __attribute__((swift_name("Processing")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *ProxyAuthenticationRequired __attribute__((swift_name("ProxyAuthenticationRequired")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *RequestHeaderFieldTooLarge __attribute__((swift_name("RequestHeaderFieldTooLarge")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *RequestTimeout __attribute__((swift_name("RequestTimeout")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *RequestURITooLong __attribute__((swift_name("RequestURITooLong")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *RequestedRangeNotSatisfiable __attribute__((swift_name("RequestedRangeNotSatisfiable")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *ResetContent __attribute__((swift_name("ResetContent")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *SeeOther __attribute__((swift_name("SeeOther")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *ServiceUnavailable __attribute__((swift_name("ServiceUnavailable")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *SwitchProxy __attribute__((swift_name("SwitchProxy")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *SwitchingProtocols __attribute__((swift_name("SwitchingProtocols")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *TemporaryRedirect __attribute__((swift_name("TemporaryRedirect")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *TooEarly __attribute__((swift_name("TooEarly")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *TooManyRequests __attribute__((swift_name("TooManyRequests")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *Unauthorized __attribute__((swift_name("Unauthorized")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *UnprocessableEntity __attribute__((swift_name("UnprocessableEntity")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *UnsupportedMediaType __attribute__((swift_name("UnsupportedMediaType")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *UpgradeRequired __attribute__((swift_name("UpgradeRequired")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *UseProxy __attribute__((swift_name("UseProxy")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *VariantAlsoNegotiates __attribute__((swift_name("VariantAlsoNegotiates")));
@property (readonly) KMPWMKtor_httpHttpStatusCode *VersionNotSupported __attribute__((swift_name("VersionNotSupported")));
@property (readonly) NSArray<KMPWMKtor_httpHttpStatusCode *> *allStatusCodes __attribute__((swift_name("allStatusCodes")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_utilsGMTDate.Companion")))
@interface KMPWMKtor_utilsGMTDateCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_utilsGMTDateCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) KMPWMKtor_utilsGMTDate *START __attribute__((swift_name("START")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_utilsWeekDay")))
@interface KMPWMKtor_utilsWeekDay : KMPWMKotlinEnum<KMPWMKtor_utilsWeekDay *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) KMPWMKtor_utilsWeekDayCompanion *companion __attribute__((swift_name("companion")));
@property (class, readonly) KMPWMKtor_utilsWeekDay *monday __attribute__((swift_name("monday")));
@property (class, readonly) KMPWMKtor_utilsWeekDay *tuesday __attribute__((swift_name("tuesday")));
@property (class, readonly) KMPWMKtor_utilsWeekDay *wednesday __attribute__((swift_name("wednesday")));
@property (class, readonly) KMPWMKtor_utilsWeekDay *thursday __attribute__((swift_name("thursday")));
@property (class, readonly) KMPWMKtor_utilsWeekDay *friday __attribute__((swift_name("friday")));
@property (class, readonly) KMPWMKtor_utilsWeekDay *saturday __attribute__((swift_name("saturday")));
@property (class, readonly) KMPWMKtor_utilsWeekDay *sunday __attribute__((swift_name("sunday")));
+ (KMPWMKotlinArray<KMPWMKtor_utilsWeekDay *> *)values __attribute__((swift_name("values()")));
@property (readonly) NSString *value __attribute__((swift_name("value")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_utilsMonth")))
@interface KMPWMKtor_utilsMonth : KMPWMKotlinEnum<KMPWMKtor_utilsMonth *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) KMPWMKtor_utilsMonthCompanion *companion __attribute__((swift_name("companion")));
@property (class, readonly) KMPWMKtor_utilsMonth *january __attribute__((swift_name("january")));
@property (class, readonly) KMPWMKtor_utilsMonth *february __attribute__((swift_name("february")));
@property (class, readonly) KMPWMKtor_utilsMonth *march __attribute__((swift_name("march")));
@property (class, readonly) KMPWMKtor_utilsMonth *april __attribute__((swift_name("april")));
@property (class, readonly) KMPWMKtor_utilsMonth *may __attribute__((swift_name("may")));
@property (class, readonly) KMPWMKtor_utilsMonth *june __attribute__((swift_name("june")));
@property (class, readonly) KMPWMKtor_utilsMonth *july __attribute__((swift_name("july")));
@property (class, readonly) KMPWMKtor_utilsMonth *august __attribute__((swift_name("august")));
@property (class, readonly) KMPWMKtor_utilsMonth *september __attribute__((swift_name("september")));
@property (class, readonly) KMPWMKtor_utilsMonth *october __attribute__((swift_name("october")));
@property (class, readonly) KMPWMKtor_utilsMonth *november __attribute__((swift_name("november")));
@property (class, readonly) KMPWMKtor_utilsMonth *december __attribute__((swift_name("december")));
+ (KMPWMKotlinArray<KMPWMKtor_utilsMonth *> *)values __attribute__((swift_name("values()")));
@property (readonly) NSString *value __attribute__((swift_name("value")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpHttpProtocolVersion.Companion")))
@interface KMPWMKtor_httpHttpProtocolVersionCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_httpHttpProtocolVersionCompanion *shared __attribute__((swift_name("shared")));
- (KMPWMKtor_httpHttpProtocolVersion *)fromValueName:(NSString *)name major:(int32_t)major minor:(int32_t)minor __attribute__((swift_name("fromValue(name:major:minor:)")));
- (KMPWMKtor_httpHttpProtocolVersion *)parseValue:(id)value __attribute__((swift_name("parse(value:)")));
@property (readonly) KMPWMKtor_httpHttpProtocolVersion *HTTP_1_0 __attribute__((swift_name("HTTP_1_0")));
@property (readonly) KMPWMKtor_httpHttpProtocolVersion *HTTP_1_1 __attribute__((swift_name("HTTP_1_1")));
@property (readonly) KMPWMKtor_httpHttpProtocolVersion *HTTP_2_0 __attribute__((swift_name("HTTP_2_0")));
@property (readonly) KMPWMKtor_httpHttpProtocolVersion *QUIC __attribute__((swift_name("QUIC")));
@property (readonly) KMPWMKtor_httpHttpProtocolVersion *SPDY_3 __attribute__((swift_name("SPDY_3")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_ioMemory")))
@interface KMPWMKtor_ioMemory : KMPWMBase
- (instancetype)initWithPointer:(void *)pointer size:(int64_t)size __attribute__((swift_name("init(pointer:size:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMKtor_ioMemoryCompanion *companion __attribute__((swift_name("companion")));
- (void)doCopyToDestination:(KMPWMKtor_ioMemory *)destination offset:(int32_t)offset length:(int32_t)length destinationOffset:(int32_t)destinationOffset __attribute__((swift_name("doCopyTo(destination:offset:length:destinationOffset:)")));
- (void)doCopyToDestination:(KMPWMKtor_ioMemory *)destination offset:(int64_t)offset length:(int64_t)length destinationOffset_:(int64_t)destinationOffset __attribute__((swift_name("doCopyTo(destination:offset:length:destinationOffset_:)")));
- (int8_t)loadAtIndex:(int32_t)index __attribute__((swift_name("loadAt(index:)")));
- (int8_t)loadAtIndex_:(int64_t)index __attribute__((swift_name("loadAt(index_:)")));
- (KMPWMKtor_ioMemory *)sliceOffset:(int32_t)offset length:(int32_t)length __attribute__((swift_name("slice(offset:length:)")));
- (KMPWMKtor_ioMemory *)sliceOffset:(int64_t)offset length_:(int64_t)length __attribute__((swift_name("slice(offset:length_:)")));
- (void)storeAtIndex:(int32_t)index value:(int8_t)value __attribute__((swift_name("storeAt(index:value:)")));
- (void)storeAtIndex:(int64_t)index value_:(int8_t)value __attribute__((swift_name("storeAt(index:value_:)")));
@property (readonly) void *pointer __attribute__((swift_name("pointer")));
@property (readonly) int64_t size __attribute__((swift_name("size")));
@property (readonly) int32_t size32 __attribute__((swift_name("size32")));
@end

__attribute__((swift_name("Ktor_ioBuffer")))
@interface KMPWMKtor_ioBuffer : KMPWMBase
- (instancetype)initWithMemory:(KMPWMKtor_ioMemory *)memory __attribute__((swift_name("init(memory:)"))) __attribute__((objc_designated_initializer)) __attribute__((deprecated("\n    We're migrating to the new kotlinx-io library.\n    This declaration is deprecated and will be removed in Ktor 4.0.0\n    If you have any problems with migration, please contact us in \n    https://youtrack.jetbrains.com/issue/KTOR-6030/Migrate-to-new-kotlinx.io-library\n    ")));
@property (class, readonly, getter=companion) KMPWMKtor_ioBufferCompanion *companion __attribute__((swift_name("companion")));
- (void)commitWrittenCount:(int32_t)count __attribute__((swift_name("commitWritten(count:)")));
- (void)discardExactCount:(int32_t)count __attribute__((swift_name("discardExact(count:)")));
- (KMPWMKtor_ioBuffer *)duplicate __attribute__((swift_name("duplicate()")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (void)duplicateToCopy:(KMPWMKtor_ioBuffer *)copy __attribute__((swift_name("duplicateTo(copy:)")));
- (int8_t)readByte __attribute__((swift_name("readByte()")));
- (void)reserveEndGapEndGap:(int32_t)endGap __attribute__((swift_name("reserveEndGap(endGap:)")));
- (void)reserveStartGapStartGap:(int32_t)startGap __attribute__((swift_name("reserveStartGap(startGap:)")));
- (void)reset __attribute__((swift_name("reset()")));
- (void)resetForRead __attribute__((swift_name("resetForRead()")));
- (void)resetForWrite __attribute__((swift_name("resetForWrite()")));
- (void)resetForWriteLimit:(int32_t)limit __attribute__((swift_name("resetForWrite(limit:)")));
- (void)rewindCount:(int32_t)count __attribute__((swift_name("rewind(count:)")));
- (NSString *)description __attribute__((swift_name("description()")));
- (int32_t)tryPeekByte __attribute__((swift_name("tryPeekByte()")));
- (int32_t)tryReadByte __attribute__((swift_name("tryReadByte()")));
- (void)writeByteValue:(int8_t)value __attribute__((swift_name("writeByte(value:)")));
@property (readonly) int32_t capacity __attribute__((swift_name("capacity")));
@property (readonly) int32_t endGap __attribute__((swift_name("endGap")));
@property (readonly) int32_t limit __attribute__((swift_name("limit")));
@property (readonly) KMPWMKtor_ioMemory *memory __attribute__((swift_name("memory")));
@property (readonly) int32_t readPosition __attribute__((swift_name("readPosition")));
@property (readonly) int32_t readRemaining __attribute__((swift_name("readRemaining")));
@property (readonly) int32_t startGap __attribute__((swift_name("startGap")));
@property (readonly) int32_t writePosition __attribute__((swift_name("writePosition")));
@property (readonly) int32_t writeRemaining __attribute__((swift_name("writeRemaining")));
@end

__attribute__((swift_name("Ktor_ioChunkBuffer")))
@interface KMPWMKtor_ioChunkBuffer : KMPWMKtor_ioBuffer
- (instancetype)initWithMemory:(KMPWMKtor_ioMemory *)memory origin:(KMPWMKtor_ioChunkBuffer * _Nullable)origin parentPool:(id<KMPWMKtor_ioObjectPool> _Nullable)parentPool __attribute__((swift_name("init(memory:origin:parentPool:)"))) __attribute__((objc_designated_initializer)) __attribute__((deprecated("\n    We're migrating to the new kotlinx-io library.\n    This declaration is deprecated and will be removed in Ktor 4.0.0\n    If you have any problems with migration, please contact us in \n    https://youtrack.jetbrains.com/issue/KTOR-6030/Migrate-to-new-kotlinx.io-library\n    ")));
- (instancetype)initWithMemory:(KMPWMKtor_ioMemory *)memory __attribute__((swift_name("init(memory:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) KMPWMKtor_ioChunkBufferCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMKtor_ioChunkBuffer * _Nullable)cleanNext __attribute__((swift_name("cleanNext()")));
- (KMPWMKtor_ioChunkBuffer *)duplicate __attribute__((swift_name("duplicate()")));
- (void)releasePool:(id<KMPWMKtor_ioObjectPool>)pool __attribute__((swift_name("release(pool:)")));
- (void)reset __attribute__((swift_name("reset()")));
@property (getter=next_) KMPWMKtor_ioChunkBuffer * _Nullable next __attribute__((swift_name("next")));
@property (readonly) KMPWMKtor_ioChunkBuffer * _Nullable origin __attribute__((swift_name("origin")));
@property (readonly) int32_t referenceCount __attribute__((swift_name("referenceCount")));
@end

__attribute__((swift_name("Ktor_ioInput")))
@interface KMPWMKtor_ioInput : KMPWMBase <KMPWMKtor_ioCloseable>
- (instancetype)initWithHead:(KMPWMKtor_ioChunkBuffer *)head remaining:(int64_t)remaining pool:(id<KMPWMKtor_ioObjectPool>)pool __attribute__((swift_name("init(head:remaining:pool:)"))) __attribute__((objc_designated_initializer)) __attribute__((deprecated("\n    We're migrating to the new kotlinx-io library.\n    This declaration is deprecated and will be removed in Ktor 4.0.0\n    If you have any problems with migration, please contact us in \n    https://youtrack.jetbrains.com/issue/KTOR-6030/Migrate-to-new-kotlinx.io-library\n    ")));
@property (class, readonly, getter=companion) KMPWMKtor_ioInputCompanion *companion __attribute__((swift_name("companion")));
- (BOOL)canRead __attribute__((swift_name("canRead()")));
- (void)close __attribute__((swift_name("close()")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (void)closeSource __attribute__((swift_name("closeSource()")));
- (int32_t)discardN:(int32_t)n __attribute__((swift_name("discard(n:)")));
- (int64_t)discardN_:(int64_t)n __attribute__((swift_name("discard(n_:)")));
- (void)discardExactN:(int32_t)n __attribute__((swift_name("discardExact(n:)")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (KMPWMKtor_ioChunkBuffer * _Nullable)fill __attribute__((swift_name("fill()")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (int32_t)fillDestination:(KMPWMKtor_ioMemory *)destination offset:(int32_t)offset length:(int32_t)length __attribute__((swift_name("fill(destination:offset:length:)")));
- (BOOL)hasBytesN:(int32_t)n __attribute__((swift_name("hasBytes(n:)")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (void)markNoMoreChunksAvailable __attribute__((swift_name("markNoMoreChunksAvailable()")));
- (int32_t)peekToBuffer:(KMPWMKtor_ioChunkBuffer *)buffer __attribute__((swift_name("peekTo(buffer:)")));
- (int64_t)peekToDestination:(KMPWMKtor_ioMemory *)destination destinationOffset:(int64_t)destinationOffset offset:(int64_t)offset min:(int64_t)min max:(int64_t)max __attribute__((swift_name("peekTo(destination:destinationOffset:offset:min:max:)")));
- (int8_t)readByte __attribute__((swift_name("readByte()")));
- (NSString *)readTextMin:(int32_t)min max:(int32_t)max __attribute__((swift_name("readText(min:max:)")));
- (int32_t)readTextOut:(id<KMPWMKotlinAppendable>)out min:(int32_t)min max:(int32_t)max __attribute__((swift_name("readText(out:min:max:)")));
- (NSString *)readTextExactExactCharacters:(int32_t)exactCharacters __attribute__((swift_name("readTextExact(exactCharacters:)")));
- (void)readTextExactOut:(id<KMPWMKotlinAppendable>)out exactCharacters:(int32_t)exactCharacters __attribute__((swift_name("readTextExact(out:exactCharacters:)")));
- (void)release_ __attribute__((swift_name("release()")));
- (int32_t)tryPeek __attribute__((swift_name("tryPeek()")));
@property (readonly) BOOL endOfInput __attribute__((swift_name("endOfInput")));
@property (readonly) id<KMPWMKtor_ioObjectPool> pool __attribute__((swift_name("pool")));
@property (readonly) int64_t remaining __attribute__((swift_name("remaining")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_ioByteReadPacket")))
@interface KMPWMKtor_ioByteReadPacket : KMPWMKtor_ioInput
- (instancetype)initWithHead:(KMPWMKtor_ioChunkBuffer *)head pool:(id<KMPWMKtor_ioObjectPool>)pool __attribute__((swift_name("init(head:pool:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithHead:(KMPWMKtor_ioChunkBuffer *)head remaining:(int64_t)remaining pool:(id<KMPWMKtor_ioObjectPool>)pool __attribute__((swift_name("init(head:remaining:pool:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly, getter=companion) KMPWMKtor_ioByteReadPacketCompanion *companion __attribute__((swift_name("companion")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (void)closeSource __attribute__((swift_name("closeSource()")));
- (KMPWMKtor_ioByteReadPacket *)doCopy __attribute__((swift_name("doCopy()")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (KMPWMKtor_ioChunkBuffer * _Nullable)fill __attribute__((swift_name("fill()")));

/**
 * @note This method has protected visibility in Kotlin source and is intended only for use by subclasses.
*/
- (int32_t)fillDestination:(KMPWMKtor_ioMemory *)destination offset:(int32_t)offset length:(int32_t)length __attribute__((swift_name("fill(destination:offset:length:)")));
- (NSString *)description __attribute__((swift_name("description()")));
@end

__attribute__((swift_name("Ktor_ioReadSession")))
@protocol KMPWMKtor_ioReadSession
@required
- (int32_t)discardN:(int32_t)n __attribute__((swift_name("discard(n:)")));
- (KMPWMKtor_ioChunkBuffer * _Nullable)requestAtLeast:(int32_t)atLeast __attribute__((swift_name("request(atLeast:)")));
@property (readonly) int32_t availableForRead __attribute__((swift_name("availableForRead")));
@end

__attribute__((swift_name("KotlinSuspendFunction1")))
@protocol KMPWMKotlinSuspendFunction1 <KMPWMKotlinFunction>
@required

/**
 * @note This method converts instances of CancellationException to errors.
 * Other uncaught Kotlin exceptions are fatal.
*/
- (void)invokeP1:(id _Nullable)p1 completionHandler:(void (^)(id _Nullable_result, NSError * _Nullable))completionHandler __attribute__((swift_name("invoke(p1:completionHandler:)")));
@end

__attribute__((swift_name("KotlinAppendable")))
@protocol KMPWMKotlinAppendable
@required

/**
 * @note annotations
 *   kotlin.IgnorableReturnValue
*/
- (id<KMPWMKotlinAppendable>)appendValue:(unichar)value __attribute__((swift_name("append(value:)")));

/**
 * @note annotations
 *   kotlin.IgnorableReturnValue
*/
- (id<KMPWMKotlinAppendable>)appendValue_:(id _Nullable)value __attribute__((swift_name("append(value_:)")));

/**
 * @note annotations
 *   kotlin.IgnorableReturnValue
*/
- (id<KMPWMKotlinAppendable>)appendValue:(id _Nullable)value startIndex:(int32_t)startIndex endIndex:(int32_t)endIndex __attribute__((swift_name("append(value:startIndex:endIndex:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpURLBuilder.Companion")))
@interface KMPWMKtor_httpURLBuilderCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_httpURLBuilderCompanion *shared __attribute__((swift_name("shared")));
@end

__attribute__((swift_name("Ktor_httpParametersBuilder")))
@protocol KMPWMKtor_httpParametersBuilder <KMPWMKtor_utilsStringValuesBuilder>
@required
@end

__attribute__((swift_name("KotlinKType")))
@protocol KMPWMKotlinKType
@required

/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.1")
*/
@property (readonly) NSArray<KMPWMKotlinKTypeProjection *> *arguments __attribute__((swift_name("arguments")));

/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.1")
*/
@property (readonly) id<KMPWMKotlinKClassifier> _Nullable classifier __attribute__((swift_name("classifier")));
@property (readonly) BOOL isMarkedNullable __attribute__((swift_name("isMarkedNullable")));
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

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpURLProtocol.Companion")))
@interface KMPWMKtor_httpURLProtocolCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_httpURLProtocolCompanion *shared __attribute__((swift_name("shared")));
- (KMPWMKtor_httpURLProtocol *)createOrDefaultName:(NSString *)name __attribute__((swift_name("createOrDefault(name:)")));
@property (readonly) KMPWMKtor_httpURLProtocol *HTTP __attribute__((swift_name("HTTP")));
@property (readonly) KMPWMKtor_httpURLProtocol *HTTPS __attribute__((swift_name("HTTPS")));
@property (readonly) KMPWMKtor_httpURLProtocol *SOCKS __attribute__((swift_name("SOCKS")));
@property (readonly) KMPWMKtor_httpURLProtocol *WS __attribute__((swift_name("WS")));
@property (readonly) KMPWMKtor_httpURLProtocol *WSS __attribute__((swift_name("WSS")));
@property (readonly) NSDictionary<NSString *, KMPWMKtor_httpURLProtocol *> *byName __attribute__((swift_name("byName")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpHeaderValueParam")))
@interface KMPWMKtor_httpHeaderValueParam : KMPWMBase
- (instancetype)initWithName:(NSString *)name value:(NSString *)value __attribute__((swift_name("init(name:value:)"))) __attribute__((objc_designated_initializer));
- (instancetype)initWithName:(NSString *)name value:(NSString *)value escapeValue:(BOOL)escapeValue __attribute__((swift_name("init(name:value:escapeValue:)"))) __attribute__((objc_designated_initializer));
- (KMPWMKtor_httpHeaderValueParam *)doCopyName:(NSString *)name value:(NSString *)value escapeValue:(BOOL)escapeValue __attribute__((swift_name("doCopy(name:value:escapeValue:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) BOOL escapeValue __attribute__((swift_name("escapeValue")));
@property (readonly) NSString *name __attribute__((swift_name("name")));
@property (readonly) NSString *value __attribute__((swift_name("value")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpHeaderValueWithParameters.Companion")))
@interface KMPWMKtor_httpHeaderValueWithParametersCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_httpHeaderValueWithParametersCompanion *shared __attribute__((swift_name("shared")));
- (id _Nullable)parseValue:(NSString *)value init:(id _Nullable (^)(NSString *, NSArray<KMPWMKtor_httpHeaderValueParam *> *))init __attribute__((swift_name("parse(value:init:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_httpContentType.Companion")))
@interface KMPWMKtor_httpContentTypeCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_httpContentTypeCompanion *shared __attribute__((swift_name("shared")));
- (KMPWMKtor_httpContentType *)parseValue:(NSString *)value __attribute__((swift_name("parse(value:)")));
@property (readonly) KMPWMKtor_httpContentType *Any __attribute__((swift_name("Any")));
@end


/**
 * @note annotations
 *   kotlinx.coroutines.InternalCoroutinesApi
*/
__attribute__((swift_name("Kotlinx_coroutines_coreParentJob")))
@protocol KMPWMKotlinx_coroutines_coreParentJob <KMPWMKotlinx_coroutines_coreJob>
@required

/**
 * @note annotations
 *   kotlinx.coroutines.InternalCoroutinesApi
*/
- (KMPWMKotlinCancellationException *)getChildJobCancellationCause __attribute__((swift_name("getChildJobCancellationCause()")));
@end


/**
 * @note annotations
 *   kotlinx.coroutines.InternalCoroutinesApi
*/
__attribute__((swift_name("Kotlinx_coroutines_coreSelectInstance")))
@protocol KMPWMKotlinx_coroutines_coreSelectInstance
@required
- (void)disposeOnCompletionDisposableHandle:(id<KMPWMKotlinx_coroutines_coreDisposableHandle>)disposableHandle __attribute__((swift_name("disposeOnCompletion(disposableHandle:)")));
- (void)selectInRegistrationPhaseInternalResult:(id _Nullable)internalResult __attribute__((swift_name("selectInRegistrationPhase(internalResult:)")));
- (BOOL)trySelectClauseObject:(id)clauseObject result:(id _Nullable)result __attribute__((swift_name("trySelect(clauseObject:result:)")));
@property (readonly) id<KMPWMKotlinCoroutineContext> context __attribute__((swift_name("context")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_utilsWeekDay.Companion")))
@interface KMPWMKtor_utilsWeekDayCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_utilsWeekDayCompanion *shared __attribute__((swift_name("shared")));
- (KMPWMKtor_utilsWeekDay *)fromOrdinal:(int32_t)ordinal __attribute__((swift_name("from(ordinal:)")));
- (KMPWMKtor_utilsWeekDay *)fromValue:(NSString *)value __attribute__((swift_name("from(value:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_utilsMonth.Companion")))
@interface KMPWMKtor_utilsMonthCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_utilsMonthCompanion *shared __attribute__((swift_name("shared")));
- (KMPWMKtor_utilsMonth *)fromOrdinal:(int32_t)ordinal __attribute__((swift_name("from(ordinal:)")));
- (KMPWMKtor_utilsMonth *)fromValue:(NSString *)value __attribute__((swift_name("from(value:)")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_ioMemory.Companion")))
@interface KMPWMKtor_ioMemoryCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_ioMemoryCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) KMPWMKtor_ioMemory *Empty __attribute__((swift_name("Empty")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_ioBuffer.Companion")))
@interface KMPWMKtor_ioBufferCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_ioBufferCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) KMPWMKtor_ioBuffer *Empty __attribute__((swift_name("Empty")));
@property (readonly) int32_t ReservedSize __attribute__((swift_name("ReservedSize")));
@end

__attribute__((swift_name("Ktor_ioObjectPool")))
@protocol KMPWMKtor_ioObjectPool <KMPWMKtor_ioCloseable>
@required
- (id)borrow __attribute__((swift_name("borrow()")));
- (void)dispose __attribute__((swift_name("dispose()")));
- (void)recycleInstance:(id)instance __attribute__((swift_name("recycle(instance:)")));
@property (readonly) int32_t capacity __attribute__((swift_name("capacity")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_ioChunkBuffer.Companion")))
@interface KMPWMKtor_ioChunkBufferCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_ioChunkBufferCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) KMPWMKtor_ioChunkBuffer *Empty __attribute__((swift_name("Empty")));
@property (readonly) id<KMPWMKtor_ioObjectPool> EmptyPool __attribute__((swift_name("EmptyPool")));
@property (readonly) id<KMPWMKtor_ioObjectPool> Pool __attribute__((swift_name("Pool")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_ioInput.Companion")))
@interface KMPWMKtor_ioInputCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_ioInputCompanion *shared __attribute__((swift_name("shared")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("Ktor_ioByteReadPacket.Companion")))
@interface KMPWMKtor_ioByteReadPacketCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKtor_ioByteReadPacketCompanion *shared __attribute__((swift_name("shared")));
@property (readonly) KMPWMKtor_ioByteReadPacket *Empty __attribute__((swift_name("Empty")));
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.1")
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinKTypeProjection")))
@interface KMPWMKotlinKTypeProjection : KMPWMBase
- (instancetype)initWithVariance:(KMPWMKotlinKVariance * _Nullable)variance type:(id<KMPWMKotlinKType> _Nullable)type __attribute__((swift_name("init(variance:type:)"))) __attribute__((objc_designated_initializer));
@property (class, readonly, getter=companion) KMPWMKotlinKTypeProjectionCompanion *companion __attribute__((swift_name("companion")));
- (KMPWMKotlinKTypeProjection *)doCopyVariance:(KMPWMKotlinKVariance * _Nullable)variance type:(id<KMPWMKotlinKType> _Nullable)type __attribute__((swift_name("doCopy(variance:type:)")));
- (BOOL)isEqual:(id _Nullable)other __attribute__((swift_name("isEqual(_:)")));
- (NSUInteger)hash __attribute__((swift_name("hash()")));
- (NSString *)description __attribute__((swift_name("description()")));
@property (readonly) id<KMPWMKotlinKType> _Nullable type __attribute__((swift_name("type")));
@property (readonly) KMPWMKotlinKVariance * _Nullable variance __attribute__((swift_name("variance")));
@end


/**
 * @note annotations
 *   kotlin.SinceKotlin(version="1.1")
*/
__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinKVariance")))
@interface KMPWMKotlinKVariance : KMPWMKotlinEnum<KMPWMKotlinKVariance *>
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
- (instancetype)initWithName:(NSString *)name ordinal:(int32_t)ordinal __attribute__((swift_name("init(name:ordinal:)"))) __attribute__((objc_designated_initializer)) __attribute__((unavailable));
@property (class, readonly) KMPWMKotlinKVariance *invariant __attribute__((swift_name("invariant")));
@property (class, readonly) KMPWMKotlinKVariance *in __attribute__((swift_name("in")));
@property (class, readonly) KMPWMKotlinKVariance *out __attribute__((swift_name("out")));
+ (KMPWMKotlinArray<KMPWMKotlinKVariance *> *)values __attribute__((swift_name("values()")));
@property (class, readonly) NSArray<KMPWMKotlinKVariance *> *entries __attribute__((swift_name("entries")));
@end

__attribute__((objc_subclassing_restricted))
__attribute__((swift_name("KotlinKTypeProjection.Companion")))
@interface KMPWMKotlinKTypeProjectionCompanion : KMPWMBase
+ (instancetype)alloc __attribute__((unavailable));
+ (instancetype)allocWithZone:(struct _NSZone *)zone __attribute__((unavailable));
+ (instancetype)companion __attribute__((swift_name("init()")));
@property (class, readonly, getter=shared) KMPWMKotlinKTypeProjectionCompanion *shared __attribute__((swift_name("shared")));
- (KMPWMKotlinKTypeProjection *)contravariantType:(id<KMPWMKotlinKType>)type __attribute__((swift_name("contravariant(type:)")));
- (KMPWMKotlinKTypeProjection *)covariantType:(id<KMPWMKotlinKType>)type __attribute__((swift_name("covariant(type:)")));
- (KMPWMKotlinKTypeProjection *)invariantType:(id<KMPWMKotlinKType>)type __attribute__((swift_name("invariant(type:)")));
@property (readonly) KMPWMKotlinKTypeProjection *STAR __attribute__((swift_name("STAR")));
@end

#pragma pop_macro("_Nullable_result")
#pragma clang diagnostic pop
NS_ASSUME_NONNULL_END
