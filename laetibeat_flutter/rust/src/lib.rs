pub mod api;
mod frb_generated;

/// Android 上初始化 rustls-platform-verifier。
///
/// reqwest 0.13 的 rustls feature 会走 platform verifier；
/// 没有初始化时 HTTPS 请求会 panic。
#[cfg(target_os = "android")]
#[no_mangle]
pub extern "system" fn Java_com_otimeum_laetibeat_MainActivity_initRustls(
    raw_env: *mut jni::sys::JNIEnv,
    _class: jni::sys::jclass,
    raw_context: jni::sys::jobject,
) {
    let mut env = unsafe { jni::EnvUnowned::from_raw(raw_env) };
    env.with_env(|env| {
        let context = unsafe { jni::objects::JObject::from_raw(env, raw_context) };
        rustls_platform_verifier::android::init_with_env(env, context)
    })
    .resolve::<jni::errors::ThrowRuntimeExAndDefault>();
}
