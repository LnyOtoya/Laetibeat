# rustls-platform-verifier 通过 JNI 反射调用 Kotlin 类，R8 看不到这些引用。
-keep,allowoptimization,includedescriptorclasses class org.rustls.platformverifier.** { *; }
