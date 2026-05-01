# native_workmanager
-keep class dev.brewkits.native_workmanager.** { *; }
-keep class dev.brewkits.kmpworkmanager.** { *; }

# Keep WorkManager worker classes
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-keep class * implements dev.brewkits.kmpworkmanager.background.domain.AndroidWorker { *; }

# WorkManager
-keep class androidx.work.** { *; }

# SLF4J (often referenced by transitive dependencies)
-dontwarn org.slf4j.**

